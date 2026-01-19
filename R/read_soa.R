#' Read SOA (Area Definition) File
#'
#' Reads a .soa file defining sets of airports (Areas) for segment management rules.
#'
#' @description
#' This function parses SAAM `.soa` files. These files define "Areas," which are named collections
#' of airports.
#'
#' \strong{Structure}:
#' Each line defines one Area:
#' \itemize{
#'   \item Field 1: **Area Name** (Must be >= 5 chars).
#'   \item Field 2..N: **Members** (Airports or other previously defined Area names).
#' }
#'
#' \strong{Features}:
#' \itemize{
#'   \item **Recursion**: An Area can contain other sub-Areas (e.g., "Paris" contains "Roissy").
#'   \item **Wildcards**: Airport names may contain `.` as a wildcard (e.g., `ED..`).
#' }
#'
#' @param soa_file Path to the .soa file.
#' @param resolve_recursion Logical. If \code{TRUE}, the function attempts to fully expand
#'   sub-areas into their constituent airports. Defaults to \code{FALSE} (returns raw hierarchy).
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{area_id}: The name of the defined Area.
#'   \item \code{member_id}: The identifier of the member (Airport or Sub-Area).
#'   \item \code{is_wildcard}: Logical. TRUE if the member ID contains wildcards (`.`).
#' }
#'
#' @importFrom data.table data.table rbindlist setkey
#' @importFrom stringi stri_split_regex stri_trim_both
#' @export
read_soa <- function(soa_file, resolve_recursion = FALSE) {
  if (!file.exists(soa_file)) stop("SOA file not found: ", soa_file)

  # Check for empty file
  if (file.size(soa_file) == 0) {
    warning("SOA file is empty: ", soa_file)
    return(data.table::data.table(area_id = character(), member_id = character(), is_wildcard = logical()))
  }

  # 1. Read Raw Lines
  # We cannot use fread easily because the number of columns (airports) varies per line.
  raw_lines <- readLines(soa_file, warn = FALSE)

  # Filter empty lines
  raw_lines <- raw_lines[trimws(raw_lines) != ""]

  if (length(raw_lines) == 0) {
    return(data.table::data.table(area_id = character(), member_id = character(), is_wildcard = logical()))
  }

  # 2. Tokenize
  # Split by whitespace (space or tab)
  tokens_list <- stringi::stri_split_regex(stringi::stri_trim_both(raw_lines), "\\s+")

  # 3. Structure into Data Table (Long Format)
  # Map: Line 1 -> Area=Token[1], Members=Token[2..N]
  dt_list <- lapply(tokens_list, function(tokens) {
    if (length(tokens) < 2) return(NULL) # Skip invalid lines
    data.table::data.table(
      area_id = tokens[1],
      member_id = tokens[-1] # All subsequent tokens
    )
  })

  dt <- data.table::rbindlist(dt_list)

  # 4. Add Wildcard Flag
  dt[, is_wildcard := grepl("\\.", member_id)]

  # 5. Recursive Resolution (Optional)
  if (resolve_recursion) {
    dt <- .resolve_soa_recursion(dt)
  }

  return(dt[])
}

#' Helper to resolve recursive area definitions
#' @keywords internal
.resolve_soa_recursion <- function(dt) {
  # Logic:
  # 1. Start with the raw list.
  # 2. Identify members that are actually Area IDs defined elsewhere in the file.
  # 3. Replace the Area-Member with the Sub-Area's members.
  # 4. Repeat until stable.

  # Note: This simple approach assumes no circular dependencies (A contains B, B contains A).

  # Unique list of defined areas
  known_areas <- unique(dt$area_id)

  max_depth <- 10 # Safety break
  iter <- 0

  while(iter < max_depth) {
    iter <- iter + 1

    # Check if any members are themselves Area IDs
    # (Exclude wildcards from this check)
    has_subareas <- dt[!is_wildcard & member_id %in% known_areas]

    if (nrow(has_subareas) == 0) break # Done!

    # Separate the table into "Resolved" (Airports) and "Unresolved" (Sub-Areas)
    resolved_rows <- dt[is_wildcard | !member_id %in% known_areas]
    unresolved_rows <- dt[!is_wildcard & member_id %in% known_areas]

    # Expand the unresolved rows
    # Join the 'unresolved' table (Parent -> ChildArea) with the full table (ChildArea -> GrandChild)
    expanded <- dt[unresolved_rows, on = .(area_id = member_id), allow.cartesian = TRUE]

    # The result of the join:
    # i.area_id = Parent Area (e.g., Paris)
    # x.member_id = Grandchild (e.g., LFPB, LFPC)
    # i.member_id = Child Area (e.g., Roissy) - we drop this

    new_rows <- expanded[, .(area_id = i.area_id, member_id = member_id, is_wildcard = is_wildcard)]

    # Recombine
    dt <- unique(data.table::rbindlist(list(resolved_rows, new_rows)))
  }

  return(dt)
}
