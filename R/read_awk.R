#' Read AWK (RAD Rule) File
#'
#' Reads a .awk file defining RAD Routing Rules.
#'
#' @description
#' This function parses SAAM `.awk` files. It handles the hierarchical structure,
#' nested logic blocks, and extracts Routing constraints.
#'
#' \strong{Structure}:
#' \itemize{
#'   \item Sections (\code{#SECTION})
#'   \item Rule Headers (\code{#RAD})
#'   \item Logic Lines (\code{if ... REGLE=REGLE ...})
#' }
#'
#' @param awk_file Path to the .awk file.
#' @param parse_rules Logical. If \code{TRUE}, extracts structured columns:
#'   \code{condition_dep}, \code{condition_arr}, \code{condition_rfl_min}, \code{condition_rfl_max},
#'   \code{routing_constraint}.
#'
#' @return A \code{data.table}.
#' If \code{parse_rules = TRUE}, columns include:
#' \itemize{
#'   \item \code{condition_dep/arr/...}: Regex patterns.
#'   \item \code{exclude_dep/arr/...}: Logical flags for negation.
#'   \item \code{condition_rfl_min/max}: Integer limits for Requested Flight Level.
#'   \item \code{routing_constraint}: The routing string (e.g., " - BUGOR DERAD").
#' }
#'
#' @importFrom data.table data.table rbindlist copy := fcase
#' @importFrom stringi stri_trim_both stri_match_first_regex
#' @export
read_awk <- function(awk_file, parse_rules = FALSE) {
  if (!file.exists(awk_file)) stop("AWK file not found: ", awk_file)

  raw_lines <- readLines(awk_file, warn = FALSE)
  if (length(raw_lines) == 0) return(data.table::data.table())

  # --- Phase 1: Structure Parsing ---
  results <- list()

  current_section_depth <- NA_integer_
  current_section_name <- NA_character_
  current_rule_id <- NA_character_
  current_props <- NA_character_
  current_airac <- NA_character_
  current_desc <- NA_character_

  # Stack for nested 'if' blocks
  block_conditions <- character()

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
        block_conditions <- character()
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
      block_conditions <- character()
      next
    }

    # 3. Block Context Logic
    block_start_match <- stringi::stri_match_first_regex(line_trim, pat_block_start)
    if (!is.na(block_start_match[1,1])) {
      cond <- paste0("(", block_start_match[1, 2], ")")
      block_conditions <- c(block_conditions, cond)
      next
    }

    if (grepl(pat_block_end, line_trim)) {
      if (length(block_conditions) > 0) block_conditions <- block_conditions[-length(block_conditions)]
      next
    }

    # 4. Code Lines
    is_active_code <- TRUE
    code_content <- line_trim

    if (startsWith(line_trim, "#")) {
      if (grepl(pat_commented_code, line_trim)) {
        is_active_code <- FALSE
        code_content <- sub("^\\s*#\\s*", "", line_trim)
      } else { next }
    }

    if (!is.na(current_rule_id)) {
      # Flatten nested logic
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

  # --- Phase 2: Structured Parsing ---
  if (parse_rules && nrow(dt) > 0) {
    dt <- .parse_awk_logic(dt)
  }

  return(dt)
}

#' Internal helper to parse AWK routing logic
#' @keywords internal
.parse_awk_logic <- function(dt) {

  # 1. Condition Extraction Helper (Regex + String Equality)
  extract_condition <- function(code_col, keyword) {
    # Matches KEY ~ /pattern/ OR KEY == "string"
    regex <- paste0("(!?)\\s*\\(?\\s*", keyword, "\\s*(?:~\\s*/([^/]+)/|==\\s*\"([^\"]+)\")")
    matches <- stringi::stri_match_first_regex(code_col, regex)

    # Coalesce Regex group (2) and String group (3)
    pat <- ifelse(is.na(matches[, 3]), matches[, 4], matches[, 3])

    list(pattern = pat, is_excluded = (matches[, 2] == "!"))
  }

  # Parse Standard Entities
  dep_res   <- extract_condition(dt$rule_code, "DEP")
  arr_res   <- extract_condition(dt$rule_code, "ARR")
  point_res <- extract_condition(dt$rule_code, "POINT")
  via_res   <- extract_condition(dt$rule_code, "VIA")

  dt[, `:=`(
    condition_dep   = dep_res$pattern,
    exclude_dep     = dep_res$is_excluded,
    condition_arr   = arr_res$pattern,
    exclude_arr     = arr_res$is_excluded,
    condition_point = point_res$pattern,
    exclude_point   = point_res$is_excluded,
    condition_via   = via_res$pattern,
    exclude_via     = via_res$is_excluded
  )]

  # Clean Booleans
  bool_cols <- c("exclude_dep", "exclude_arr", "exclude_point", "exclude_via")
  dt[, (bool_cols) := lapply(.SD, function(x) ifelse(is.na(x), FALSE, x)), .SDcols = bool_cols]

  # 2. Parse RFL (Requested Flight Level) Conditions
  # Commonly: RFL > 305, RFL < 285
  # We extract MIN and MAX RFL from the rule string

  # Match: RFL > (\d+)
  rfl_min_match <- stringi::stri_match_first_regex(dt$rule_code, "RFL\\s*>\\s*(\\d+)")
  # Match: RFL < (\d+)
  rfl_max_match <- stringi::stri_match_first_regex(dt$rule_code, "RFL\\s*<\\s*(\\d+)")

  dt[, `:=`(
    condition_rfl_min = as.integer(rfl_min_match[, 2]),
    condition_rfl_max = as.integer(rfl_max_match[, 2])
  )]

  # 3. Parse REGLE (Routing Constraint)
  # Looks for: REGLE = REGLE " ... "
  regle_matches <- stringi::stri_match_first_regex(dt$rule_code, 'REGLE\\s*=\\s*REGLE\\s*"([^"]+)"')

  dt[, routing_constraint := regle_matches[, 2]]

  dt[, constraint_type := data.table::fcase(
    !is.na(routing_constraint), "ROUTING",
    (!is.na(condition_rfl_min) | !is.na(condition_rfl_max)), "LEVEL",
    default = NA_character_
  )]

  return(dt)
}
