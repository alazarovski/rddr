#' Read NNPT (Navigation Point) File
#'
#' Reads a .nnpt file containing a list of navigation points with coordinates.
#'
#' @description
#' This function parses `.nnpt` files used to define navigation points (waypoints, VORs, NDBs, etc.).
#'
#' The file structure is defined as follows:
#' \itemize{
#'   \item \strong{Extension}: nnpt
#'   \item \strong{Separator}: Semicolon (;)
#'   \item \strong{Coordinate System}: Decimal degrees
#' }
#'
#' The file consists of:
#' \enumerate{
#'   \item \strong{First Line}: An integer representing the total number of records.
#'   \item \strong{Subsequent Lines}: Records containing the point definition.
#' }
#'
#' \strong{Record Structure}:
#' \itemize{
#'   \item Field 1: \strong{ID} (e.g., *01BP)
#'   \item Field 2: \strong{Type} (e.g., DB)
#'   \item Field 3: \strong{Latitude} (Decimal Degrees)
#'   \item Field 4: \strong{Longitude} (Decimal Degrees)
#'   \item Field 5: \strong{Name} (Underscore "_" indicates no data)
#' }
#'
#' @param nnpt_file Path to the .nnpt file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{point_id}: The unique identifier of the navigation point.
#'   \item \code{type}: The type classification of the point.
#'   \item \code{lat}: Latitude in decimal degrees.
#'   \item \code{lon}: Longitude in decimal degrees.
#'   \item \code{name}: The descriptive name (NA if original was "_").
#' }
#'
#' @importFrom data.table fread :=
#' @export
read_nnpt <- function(nnpt_file) {
  if (!file.exists(nnpt_file)) stop("NNPT file not found: ", nnpt_file)

  # Check for empty file
  if (file.size(nnpt_file) == 0) {
    warning("NNPT file is empty: ", nnpt_file)
    return(data.table::data.table(
      point_id = character(),
      type = character(),
      lat = numeric(),
      lon = numeric(),
      name = character()
    ))
  }

  # The first line is just a count (integer). We skip it (skip = 1).
  # If the file only has the count line and no data, fread might return empty, handled gracefully.
  dt <- data.table::fread(
    nnpt_file,
    sep = ";",
    skip = 1,
    header = FALSE,
    col.names = c("point_id", "type", "lat", "lon", "name"),
    colClasses = list(
      character = c("point_id", "type", "name"),
      numeric = c("lat", "lon")
    ),
    showProgress = FALSE
  )

  # --- Data Cleaning ---

  # Convert "_" in the name column to NA
  # This is the idiomatic data.table way (in-place modification)
  dt[name == "_", name := NA]

  # Ensure coordinates are numeric (fread usually handles this via colClasses,
  # but good to be explicit if file formatting is loose)
  dt[, `:=`(
    lat = as.numeric(lat),
    lon = as.numeric(lon)
  )]

  return(dt[])
}
