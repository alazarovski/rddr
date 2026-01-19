#' Read AWK/FLC2 (Rule) File
#'
#' Reads a .awk or .flc2 file defining RAD (Route Availability Document) rules or Flight Level Constraints.
#'
#' @description
#' This function parses SAAM Rule files. These files are hierarchical:
#' \itemize{
#'   \item \strong{Sections} (\code{#SECTION_X}): Group rules visually.
#'   \item \strong{Rules} (\code{#RAD}): Define the metadata for a specific rule.
#'   \item \strong{Body}: The actual logic (AWK syntax) following a Rule header.
#' }
#'
#' \strong{Parsing Logic}:
#' \itemize{
#'   \item Lines starting with \code{#SECTION} update the current section context.
#'   \item Lines starting with \code{#RAD} start a new rule and parse its ID, properties, and comments.
#'   \item Lines starting with \code{#END} stop the parsing.
#'   \item Other lines (that don't start with \code{#}) are treated as the "Code" or "Definition" of the current rule.
#' }
#'
#' @param awk_file Path to the .awk or .flc2 file.
#'
#' @return A \code{data.table} where each row represents a line of code within a rule, with columns:
#' \itemize{
#'   \item \code{section_depth}: Integer (1, 2, 3...).
#'   \item \code{section_name}: Character (Name of the section).
#'   \item \code{rule_id}: Character (The RAD Rule ID).
#'   \item \code{properties}: Character (Raw property string, e.g., key=value).
#'   \item \code{airac}: Character (AIRAC cycle if present).
#'   \item \code{description}: Character (Free text comment).
#'   \item \code{rule_code}: Character (The actual AWK/Logic line).
#' }
#'
#' @importFrom data.table data.table rbindlist
#' @importFrom stringi stri_trim_both stri_match_first_regex
#' @export
read_awk <- function(awk_file) {
  if (!file.exists(awk_file)) stop("Rule file not found: ", awk_file)

  raw_lines <- readLines(awk_file, warn = FALSE)
  if (length(raw_lines) == 0) return(data.table::data.table())

  # Pre-allocate lists to store results
  # We collect data in lists for speed, then combine at the end
  results <- list()

  # State variables
  current_section_depth <- NA_integer_
  current_section_name <- NA_character_

  current_rule_id <- NA_character_
  current_props <- NA_character_
  current_airac <- NA_character_
  current_desc <- NA_character_

  # Regex Patterns
  # SECTION: #SECTION_(\d) - (.*)
  pat_section <- "^\\s*#SECTION_(\\d+)\\s*-\\s*(.*)$"

  # RAD: #RAD (ID) (- properties -)? (AIRAC \d+)? (.*)
  # This is complex because parts are optional. We split manually for robustness.
  pat_rad_start <- "^\\s*#RAD\\s+"

  # END
  pat_end <- "^\\s*#END"

  # Iterate lines
  for (line in raw_lines) {
    line_trim <- stringi::stri_trim_both(line)

    # 1. Skip Empty Lines
    if (line_trim == "") next

    # 2. Check for End of File
    if (grepl(pat_end, line_trim)) break

    # 3. Check for Section Header
    if (grepl("^\\s*#SECTION", line_trim)) {
      match <- stringi::stri_match_first_regex(line_trim, pat_section)
      if (!is.na(match[1, 1])) {
        current_section_depth <- as.integer(match[1, 2])
        current_section_name <- match[1, 3]

        # Reset current Rule context when entering a new section
        current_rule_id <- NA_character_
        current_props <- NA_character_
        current_airac <- NA_character_
        current_desc <- NA_character_
      }
      next
    }

    # 4. Check for Rule Header (#RAD)
    if (grepl(pat_rad_start, line_trim)) {
      # Remove "#RAD " prefix
      content <- sub(pat_rad_start, "", line_trim)

      # Extract ID (first token)
      parts <- strsplit(content, "\\s+")[[1]]
      current_rule_id <- parts[1]

      # Remaining content after ID
      rest <- substring(content, nchar(current_rule_id) + 2)

      # Extract Properties: Surrounded by " - "
      # Regex: Look for " - " ... " - "
      prop_match <- stringi::stri_match_first_regex(rest, "^\\s*-(.*)-\\s*(.*)")

      if (!is.na(prop_match[1,1])) {
        current_props <- stringi::stri_trim_both(prop_match[1, 2])
        rest <- prop_match[1, 3] # The remainder
      } else {
        current_props <- NA_character_
      }

      # Extract AIRAC: "AIRAC XXXX"
      airac_match <- stringi::stri_match_first_regex(rest, "AIRAC\\s+(\\d+)")
      if (!is.na(airac_match[1,1])) {
        current_airac <- airac_match[1, 2]
        # Remove AIRAC token from rest to leave only the description
        rest <- sub("AIRAC\\s+\\d+", "", rest)
      } else {
        current_airac <- NA_character_
      }

      # Description is whatever is left
      current_desc <- stringi::stri_trim_both(rest)

      next
    }

    # 5. Comment lines not part of a rule
    # If a line starts with # but isn't SECTION/RAD/END, it's a comment.
    # SAAM spec says "Everything before first section won't be part of rules".
    # For now, we skip generic comments to focus on the Rule Code.
    if (startsWith(line_trim, "#")) next

    # 6. Rule Body (The Code)
    # If we are inside a rule context, this is a code line.
    if (!is.na(current_rule_id)) {
      # Add to results
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

  # Combine
  dt <- data.table::rbindlist(results)
  return(dt)
}
