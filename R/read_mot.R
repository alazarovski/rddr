#' Read MOT (Airspace Activation) File
#'
#' Reads a .mot file defining airspace activation times, flight levels, and opening types.
#'
#' @description
#' This function parses SAAM `.mot` files (Military Opening Time). These files define when specific
#' airspaces (usually military zones or Free Route Airspace) are active or available for civil traffic.
#'
#' The file structure supports three format versions, indicated by the first field:
#' \itemize{
#'   \item \strong{Version 1}: Basic activation (Zone, Start, End).
#'   \item \strong{Version 2}: Level restricted (Zone, Start, End, Min FL, Max FL).
#'   \item \strong{Version 3}: Type restricted (Zone, Start, End, Opening Type).
#' }
#'
#' \strong{Record Structure}:
#' \itemize{
#'   \item Field 1: \strong{Version} (1, 2, or 3).
#'   \item Field 2: \strong{Zone Name} (Must match SLS/Map definitions).
#'   \item Field 3: \strong{Start Time} (HHMM).
#'   \item Field 4: \strong{End Time} (HHMM).
#'   \item Field 5: \strong{Lower FL} (Ver 2) OR \strong{Opening Type} (Ver 3).
#'   \item Field 6: \strong{Upper FL} (Ver 2 only).
#' }
#'
#' @param mot_file Path to the .mot file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{version}: Integer (1, 2, or 3).
#'   \item \code{zone_id}: Character.
#'   \item \code{start_time}: Character (HHMM).
#'   \item \code{end_time}: Character (HHMM).
#'   \item \code{min_fl}: Integer (NA for Ver 1 & 3).
#'   \item \code{max_fl}: Integer (NA for Ver 1 & 3).
#'   \item \code{opening_type}: Character (NA for Ver 1 & 2. e.g., "EX", "E").
#' }
#'
#' @importFrom data.table fread :=
#' @export
read_mot <- function(mot_file) {
  if (!file.exists(mot_file)) stop("MOT file not found: ", mot_file)

  # Check for empty file
  if (file.size(mot_file) == 0) {
    warning("MOT file is empty: ", mot_file)
    return(data.table::data.table(
      version = integer(),
      zone_id = character(),
      start_time = character(),
      end_time = character(),
      min_fl = integer(),
      max_fl = integer(),
      opening_type = character()
    ))
  }

  # Read file
  # fill=TRUE is crucial because Ver 1/3 have fewer columns than Ver 2
  # colClasses="character" ensures we preserve "0900" as "0900" and don't lose leading zeros
  dt <- data.table::fread(
    mot_file,
    header = FALSE,
    fill = TRUE,
    sep = "auto",
    colClasses = "character",
    showProgress = FALSE
  )

  if (nrow(dt) == 0) return(dt)

  # --- Data Cleaning & Mapping ---

  # Ensure Version is integer for logical checks
  dt[, V1 := as.integer(V1)]

  # Base Columns (Present in all versions)
  result <- dt[, .(
    version    = V1,
    zone_id    = V2,
    start_time = V3,
    end_time   = V4
  )]

  # Initialize Conditional Columns
  result[, `:=`(
    min_fl = NA_integer_,
    max_fl = NA_integer_,
    opening_type = NA_character_
  )]

  # --- Apply Version Logic ---

  # Version 2: Fields 5 & 6 are FLs
  # We use the index from 'dt' to map to 'result'
  v2_idx <- which(dt$V1 == 2)
  if (length(v2_idx) > 0) {
    # Check if columns exist (file might be pure V1/V3 and lack col 5/6)
    if (ncol(dt) >= 5) result[v2_idx, min_fl := as.integer(dt$V5[v2_idx])]
    if (ncol(dt) >= 6) result[v2_idx, max_fl := as.integer(dt$V6[v2_idx])]
  }

  # Version 3: Field 5 is Opening Type
  v3_idx <- which(dt$V1 == 3)
  if (length(v3_idx) > 0) {
    if (ncol(dt) >= 5) result[v3_idx, opening_type := dt$V5[v3_idx]]
  }

  # Cleanup IDs
  result[, zone_id := trimws(zone_id)]

  return(result[])
}
