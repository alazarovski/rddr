#' Read NARP (Airport) File
#'
#' Reads a .narp file defining airport metadata, location, and operational parameters.
#'
#' @description
#' This function parses SAAM/Gasel `.narp` files. These files contain a comprehensive
#' list of airports, including their ICAO codes, names, coordinates, and traffic sequencing parameters.
#'
#' The file structure is defined as follows:
#' \itemize{
#'   \item \strong{Extension}: narp
#'   \item \strong{Separator}: Semicolon (;)
#'   \item \strong{Coordinate System}: Decimal degrees
#' }
#'
#' The file consists of:
#' \enumerate{
#'   \item \strong{First Line}: Metadata starting with # (e.g., version, dates, record count).
#'   \item \strong{Body Lines}: Records defining individual airports.
#' }
#'
#' \strong{Record Structure}:
#' \itemize{
#'   \item Field 1: \strong{ICAO Code} (4 characters)
#'   \item Field 2: \strong{Airport Name}
#'   \item Field 3: \strong{Latitude} (Decimal Degrees)
#'   \item Field 4: \strong{Longitude} (Decimal Degrees)
#'   \item Field 5: \strong{TIS} (Time to Insert into Sequence - minutes)
#'   \item Field 6: \strong{TRS} (Time to Remove from Sequence - minutes)
#'   \item Field 7: \strong{Taxi Time} (minutes)
#'   \item Field 8: \strong{Altitude} (Flight Levels)
#' }
#'
#' \strong{Note on TIS/TRS}:
#' Underscores ("_") in numeric fields (TIS, TRS, TaxiTime) indicate missing data and are converted to NA.
#'
#' @param narp_file Path to the .narp file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{icao}: Character (4-letter ICAO code).
#'   \item \code{name}: Character (Airport name).
#'   \item \code{lat}: Numeric (Latitude).
#'   \item \code{lon}: Numeric (Longitude).
#'   \item \code{tis}: Numeric (Time to Insert).
#'   \item \code{trs}: Numeric (Time to Remove).
#'   \item \code{taxitime}: Numeric.
#'   \item \code{altitude}: Numeric (Flight Level).
#' }
#'
#' @importFrom data.table fread :=
#' @export
read_narp <- function(narp_file) {
  if (!file.exists(narp_file)) stop("NARP file not found: ", narp_file)

  # Check for empty file
  if (file.size(narp_file) == 0) {
    warning("NARP file is empty: ", narp_file)
    return(data.table::data.table(
      icao = character(),
      name = character(),
      lat = numeric(),
      lon = numeric(),
      tis = numeric(),
      trs = numeric(),
      taxitime = numeric(),
      altitude = numeric()
    ))
  }

  # Read file
  # skip = 1 for metadata header
  # colClasses = "character" for initial read to safely handle "_" in numeric columns
  dt <- data.table::fread(
    narp_file,
    sep = ";",
    skip = 1,
    header = FALSE,
    col.names = c("icao", "name", "lat", "lon", "tis", "trs", "taxitime", "altitude"),
    colClasses = "character",
    showProgress = FALSE,
    fill = TRUE
  )

  # Basic validation
  if (nrow(dt) == 0) return(dt)

  # --- Data Cleaning ---

  # 1. Handle missing values marked as "_"
  # We iterate over the columns that are supposed to be numeric
  numeric_cols <- c("lat", "lon", "tis", "trs", "taxitime", "altitude")

  # Efficiently replace "_" with NA in all target columns
  for (col in numeric_cols) {
    dt[get(col) == "_", (col) := NA]
  }

  # 2. Convert to Numeric
  # Now that "_" are NAs, coercion to numeric is safe
  dt[, (numeric_cols) := lapply(.SD, as.numeric), .SDcols = numeric_cols]

  # 3. Clean string columns (optional but good practice)
  dt[, `:=`(
    icao = trimws(icao),
    name = trimws(name)
  )]

  return(dt[])
}
