#' Read FLC2 (Flight Level Constraints) File
#'
#' Reads a .flc2 (or .awk) file defining Flight Level Constraints or RAD rules.
#'
#' @description
#' This function parses SAAM `.flc2` files. These files share the exact same structure as `.awk` files:
#' \itemize{
#'   \item \strong{Sections} (\code{#SECTION_X}): Group rules visually.
#'   \item \strong{Rules} (\code{#RAD}): Define the metadata for a specific rule.
#'   \item \strong{Body}: The actual logic (Constraint syntax) following a Rule header.
#' }
#'
#' @param flc2_file Path to the .flc2 file.
#' @param parse_rules Logical. If \code{TRUE}, the function attempts to parse the \code{rule_code}
#'   column to extract structured constraints (DEP, ARR, POINT, FL limit).
#'   Defaults to \code{FALSE} (returns raw logic strings).
#'
#' @return A \code{data.table}.
#' If \code{parse_rules = FALSE} (default):
#' \itemize{
#'   \item \code{rule_id}, \code{section_name}, \code{rule_code} (raw string), etc.
#' }
#' If \code{parse_rules = TRUE}, columns are added:
#' \itemize{
#'   \item \code{condition_dep}: Regex for departure airport(s).
#'   \item \code{condition_arr}: Regex for arrival airport(s).
#'   \item \code{condition_point}: Regex for route point(s).
#'   \item \code{constraint_type}: "MAX" (for ceiling), "MIN" (for floor), or "EQUAL".
#'   \item \code{constraint_fl}: Integer flight level.
#' }
#'
#' @importFrom data.table data.table rbindlist copy := fcase
#' @importFrom stringi stri_trim_both stri_match_first_regex
#' @export
read_flc2 <- function(flc2_file, parse_rules = FALSE) {
  if (!file.exists(flc2_file)) stop("FLC2 file not found: ", flc2_file)

  raw_lines <- readLines(flc2_file, warn = FALSE)
  if (length(raw_lines) == 0) return(data.table::data.table())

  # --- Phase 1: File Parsing (Section/Rule Structure) ---
  results <- list()

  # State variables
  current_section_depth <- NA_integer_
  current_section_name <- NA_character_

  current_rule_id <- NA_character_
  current_props <- NA_character_
  current_airac <- NA_character_
  current_desc <- NA_character_

  # Compiled Regex Patterns
  pat_section <- "^\\s*#SECTION_(\\d+)\\s*-\\s*(.*)$"
  pat_rad_start <- "^\\s*#RAD\\s+"
  pat_end <- "^\\s*#END"

  for (line in raw_lines) {
    line_trim <- stringi::stri_trim_both(line)

    if (line_trim == "") next
    if (grepl(pat_end, line_trim)) break

    # Check Section
    if (grepl("^\\s*#SECTION", line_trim)) {
      match <- stringi::stri_match_first_regex(line_trim, pat_section)
      if (!is.na(match[1, 1])) {
        current_section_depth <- as.integer(match[1, 2])
        current_section_name <- match[1, 3]
        current_rule_id <- NA_character_
        current_props <- NA_character_
        current_airac <- NA_character_
        current_desc <- NA_character_
      }
      next
    }

    # Check Rule Header
    if (grepl(pat_rad_start, line_trim)) {
      content <- sub(pat_rad_start, "", line_trim)
      parts <- strsplit(content, "\\s+")[[1]]
      current_rule_id <- parts[1]
      rest <- substring(content, nchar(current_rule_id) + 2)

      prop_match <- stringi::stri_match_first_regex(rest, "^\\s*-(.*)-\\s*(.*)")
      if (!is.na(prop_match[1,1])) {
        current_props <- stringi::stri_trim_both(prop_match[1, 2])
        rest <- prop_match[1, 3]
      } else {
        current_props <- NA_character_
      }

      airac_match <- stringi::stri_match_first_regex(rest, "AIRAC\\s+(\\d+)")
      if (!is.na(airac_match[1,1])) {
        current_airac <- airac_match[1, 2]
        rest <- sub("AIRAC\\s+\\d+", "", rest)
      } else {
        current_airac <- NA_character_
      }

      current_desc <- stringi::stri_trim_both(rest)
      next
    }

    # Check Comments
    if (startsWith(line_trim, "#")) next

    # Record Code Line
    if (!is.na(current_rule_id)) {
      results[[length(results) + 1]] <- list(
        section_depth = current_section_depth,
        section_name = current_section_name,
        rule_id = current_rule_id,
        properties = current_props,
        airac = current_airac,
        description = current_desc,
        rule_code = line_trim
      )
    }
  }

  dt <- data.table::rbindlist(results)

  # --- Phase 2: Optional Structured Parsing ---
  if (parse_rules && nrow(dt) > 0) {
    dt <- .parse_flc_constraints(dt)
  }

  return(dt[])
}

#' Internal helper to parse regex constraints from rule code
#' @keywords internal
.parse_flc_constraints <- function(dt) {
  # We work by reference on the input dt (which is already a copy from read_flc2 logic)

  # 1. Extract Conditionals (DEP, ARR, POINT)
  dt[, `:=`(
    condition_dep   = stringi::stri_match_first_regex(rule_code, "DEP\\s*~\\s*/([^/]+)/")[,2],
    condition_arr   = stringi::stri_match_first_regex(rule_code, "ARR\\s*~\\s*/([^/]+)/")[,2],
    condition_point = stringi::stri_match_first_regex(rule_code, "POINT\\s*~\\s*/([^/]+)/")[,2]
  )]

  # 2. Extract Constraint (FL_CONT)
  # Matches: FL_CONT=-245, FL_CONT = -245, FL_CONT > 245
  matches <- stringi::stri_match_first_regex(dt$rule_code, "FL_CONT\\s*=\\s*([-+>]?)(\\d+)")

  dt[, `:=`(
    raw_sign      = matches[, 2],
    constraint_fl = as.integer(matches[, 3])
  )]

  # 3. Determine Constraint Type
  dt[, constraint_type := data.table::fcase(
    raw_sign %in% c("-", "<"), "MAX",    # Ceiling
    raw_sign %in% c("+", ">"), "MIN",    # Floor
    raw_sign == "",            "EQUAL",  # Exact
    default = NA_character_
  )]

  # Cleanup temp column
  dt[, raw_sign := NULL]

  return(dt[])
}
