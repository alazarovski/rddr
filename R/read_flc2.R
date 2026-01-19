#' Read FLC2 (Rule/Constraint) File
#'
#' Reads a .flc2 (or .awk) file defining RAD Rules.
#'
#' @description
#' This function parses SAAM `.flc2` files. It handles:
#' \itemize{
#'   \item Hierarchical Sections and Rule headers.
#'   \item \strong{Nested Logic Blocks}: Handles \code{if(...) { ... }} structures by flattening the logic.
#'   \item \strong{Syntax Variations}: Supports both Regex (\code{~ /.../}) and String Equality (\code{== "..."}).
#' }
#'
#' @param flc2_file Path to the .flc2 file.
#' @param parse_rules Logical. If \code{TRUE}, extracts structured columns.
#'
#' @return A \code{data.table}.
#' If \code{parse_rules = TRUE}, the following columns are added:
#' \itemize{
#'   \item \code{condition_dep}, \code{condition_arr}, \code{condition_point}, \code{condition_via}, \code{condition_climb_rate}: Regex patterns or exact strings.
#'   \item \code{exclude_dep}, \code{exclude_arr}, etc.: Logical flags (TRUE if the condition is negated with '!').
#'   \item \code{constraint_type}: "ROUTING" (for REGLE), "MAX", "MIN", or "EQUAL" (for FL_CONT).
#'   \item \code{constraint_value}: The routing string (if type is ROUTING) or the Flight Level (as integer).
#' }
#'
#' @importFrom data.table data.table rbindlist copy := fcase
#' @importFrom stringi stri_trim_both stri_match_first_regex
#' @export
read_flc2 <- function(flc2_file, parse_rules = FALSE) {
  if (!file.exists(flc2_file)) stop("FLC2 file not found: ", flc2_file)

  raw_lines <- readLines(flc2_file, warn = FALSE)
  if (length(raw_lines) == 0) return(data.table::data.table())

  # --- Phase 1: Structure Parsing ---
  results <- list()

  # Context Variables
  current_section_depth <- NA_integer_
  current_section_name <- NA_character_
  current_rule_id <- NA_character_
  current_props <- NA_character_
  current_airac <- NA_character_
  current_desc <- NA_character_

  # Block Context Stack (List of conditions from parent 'if' statements)
  # When we enter 'if (A) {', we push 'A' here.
  block_conditions <- character()

  # Regex Patterns
  pat_section <- "^\\s*#SECTION_(\\d+)\\s*-\\s*(.*)$"
  pat_rad_start <- "^\\s*#RAD\\s+"
  pat_end <- "^\\s*#END"
  pat_commented_code <- "^\\s*#\\s*if\\s*\\("
  pat_block_start <- "^\\s*if\\s*\\((.*)\\)\\s*\\{\\s*$"
  pat_block_end <- "^\\s*\\}\\s*$"

  for (line in raw_lines) {
    line_trim <- stringi::stri_trim_both(line)

    if (line_trim == "") next
    if (grepl(pat_end, line_trim)) break

    # 1. Section Headers
    if (grepl("^\\s*#SECTION", line_trim)) {
      match <- stringi::stri_match_first_regex(line_trim, pat_section)
      if (!is.na(match[1, 1])) {
        current_section_depth <- as.integer(match[1, 2])
        current_section_name <- match[1, 3]
        current_rule_id <- NA_character_
        current_props <- NA_character_
        current_airac <- NA_character_
        current_desc <- NA_character_
        block_conditions <- character() # Reset blocks on new section
      }
      next
    }

    # 2. Rule Headers
    if (grepl(pat_rad_start, line_trim)) {
      content <- sub(pat_rad_start, "", line_trim)
      parts <- strsplit(content, "\\s+")[[1]]
      current_rule_id <- parts[1]
      rest <- substring(content, nchar(current_rule_id) + 2)

      prop_match <- stringi::stri_match_first_regex(rest, "^\\s*-(.*)-\\s*(.*)")
      if (!is.na(prop_match[1,1])) {
        current_props <- stringi::stri_trim_both(prop_match[1, 2])
        rest <- prop_match[1, 3]
      } else { current_props <- NA_character_ }

      airac_match <- stringi::stri_match_first_regex(rest, "AIRAC\\s+(\\d+)")
      if (!is.na(airac_match[1,1])) {
        current_airac <- airac_match[1, 2]
        rest <- sub("AIRAC\\s+\\d+", "", rest)
      } else { current_airac <- NA_character_ }

      current_desc <- stringi::stri_trim_both(rest)
      block_conditions <- character() # Reset blocks on new rule
      next
    }

    # 3. Handle Code Blocks
    block_start_match <- stringi::stri_match_first_regex(line_trim, pat_block_start)
    if (!is.na(block_start_match[1,1])) {
      cond <- paste0("(", block_start_match[1, 2], ")")
      block_conditions <- c(block_conditions, cond)
      next
    }

    if (grepl(pat_block_end, line_trim)) {
      if (length(block_conditions) > 0) {
        block_conditions <- block_conditions[-length(block_conditions)]
      }
      next
    }

    # 4. Process Logic Lines
    is_active_code <- TRUE
    code_content <- line_trim

    if (startsWith(line_trim, "#")) {
      if (grepl(pat_commented_code, line_trim)) {
        is_active_code <- FALSE
        code_content <- sub("^\\s*#\\s*", "", line_trim)
      } else { next }
    }

    if (!is.na(current_rule_id)) {
      final_code <- code_content
      if (length(block_conditions) > 0) {
        parent_logic <- paste(block_conditions, collapse = " && ")
        final_code <- paste(parent_logic, "&&", code_content)
      }

      results[[length(results) + 1]] <- list(
        section_depth = current_section_depth,
        section_name = current_section_name,
        rule_id = current_rule_id,
        properties = current_props,
        airac = current_airac,
        description = current_desc,
        rule_code = final_code,
        is_active = is_active_code
      )
    }
  }

  dt <- data.table::rbindlist(results)

  if (parse_rules && nrow(dt) > 0) {
    dt <- .parse_flc_constraints(dt)
  }

  return(dt)
}

#' Internal helper to parse constraints (Regex OR Equality)
#' @keywords internal
.parse_flc_constraints <- function(dt) {

  extract_condition <- function(code_col, keyword) {
    regex <- paste0("(!?)\\s*\\(?\\s*", keyword, "\\s*(?:~\\s*/([^/]+)/|==\\s*\"([^\"]+)\")")
    matches <- stringi::stri_match_first_regex(code_col, regex)
    pat <- ifelse(is.na(matches[, 3]), matches[, 4], matches[, 3])
    list(pattern = pat, is_excluded = (matches[, 2] == "!"))
  }

  dep_res   <- extract_condition(dt$rule_code, "DEP")
  arr_res   <- extract_condition(dt$rule_code, "ARR")
  point_res <- extract_condition(dt$rule_code, "POINT")
  via_res   <- extract_condition(dt$rule_code, "VIA")
  climb_res <- extract_condition(dt$rule_code, "CLIMB_RATE")

  dt[, `:=`(
    condition_dep        = dep_res$pattern,
    exclude_dep          = dep_res$is_excluded,
    condition_arr        = arr_res$pattern,
    exclude_arr          = arr_res$is_excluded,
    condition_point      = point_res$pattern,
    exclude_point        = point_res$is_excluded,
    condition_via        = via_res$pattern,
    exclude_via          = via_res$is_excluded,
    condition_climb_rate = climb_res$pattern,
    exclude_climb_rate   = climb_res$is_excluded
  )]

  bool_cols <- c("exclude_dep", "exclude_arr", "exclude_point", "exclude_via", "exclude_climb_rate")
  dt[, (bool_cols) := lapply(.SD, function(x) ifelse(is.na(x), FALSE, x)), .SDcols = bool_cols]

  fl_matches <- stringi::stri_match_first_regex(dt$rule_code, "FL_CONT\\s*=\\s*([-+>]?)(\\d+)")
  regle_matches <- stringi::stri_match_first_regex(dt$rule_code, 'REGLE\\s*=\\s*REGLE\\s*"([^"]+)"')

  dt[, `:=`(
    raw_fl_sign   = fl_matches[, 2],
    raw_fl_val    = fl_matches[, 3],
    raw_regle_val = regle_matches[, 2]
  )]

  dt[, constraint_type := data.table::fcase(
    !is.na(raw_regle_val), "ROUTING",
    raw_fl_sign %in% c("-", "<"), "MAX",
    raw_fl_sign %in% c("+", ">"), "MIN",
    raw_fl_sign == "",            "EQUAL",
    default = NA_character_
  )]

  dt[, constraint_value := data.table::fcase(
    constraint_type == "ROUTING", raw_regle_val,
    !is.na(raw_fl_val), raw_fl_val,
    default = NA_character_
  )]

  dt[, c("raw_fl_sign", "raw_fl_val", "raw_regle_val") := NULL]

  return(dt)
}
