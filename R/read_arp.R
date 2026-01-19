#' Read ARP (Airport Definition) File
#'
#' Reads an .arp file defining the geographical location and FIR association of airports.
#'
#' @description
#' This function parses `.arp` files, which provide a simple definition of airport locations
#' used in SAAM assignment processes.
#'
#' The file structure is defined as follows:
#' \itemize{
#'   \item \strong{Extension}: arp
#'   \item \strong{Origin}: Manual input
#'   \item \strong{Separator}: Whitespace
#'   \item \strong{Coordinate Unit}: Minutes (Decimal)
#' }
#'
#' \strong{Record Structure}:
#' \itemize{
#'   \item Field 1: \strong{Airport ICAO} (4 characters)
#'   \item Field 2: \strong{Latitude} (Minutes)
#'   \item Field 3: \strong{Longitude} (Minutes)
#'   \item Field 4: \strong{FIR Name} (Optional, e.g., "EGTT_FIR" or "NOFIR")
#' }
#'
#' @param arp_file Path to the .arp file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{icao}: Character (4-letter ICAO code).
#'   \item \code{lat}: Numeric (Latitude in Decimal Degrees).
#'   \item \code{lon}: Numeric (Longitude in Decimal Degrees).
#'   \item \code{fir_id}: Character (The associated Flight Information Region).
#' }
#'
#' @importFrom data.table fread :=
#' @export
read_arp <- function(arp_file) {
  if (!file.exists(arp_file)) stop("ARP file not found: ", arp_file)

  # Check for empty file
  if (file.size(arp_file) == 0) {
    warning("ARP file is empty: ", arp_file)
    return(data.table::data.table(
      icao = character(),
      lat = numeric(),
      lon = numeric(),
      fir_id = character()
    ))
  }

  # Read file
  # fill = TRUE handles the optional 4th column (FIR)
  dt <- data.table::fread(
    arp_file,
    sep = "auto",
    header = FALSE,
    col.names = c("icao", "lat_min", "lon_min", "fir_id"),
    colClasses = list(
      character = c("icao", "fir_id"),
      numeric = c("lat_min", "lon_min")
    ),
    showProgress = FALSE,
    fill = TRUE
  )

  if (nrow(dt) == 0) return(dt)

  # --- Data Cleaning ---

  # Convert Coordinates from Minutes to Decimal Degrees
  dt[, `:=`(
    lat = round(lat_min / 60, 4),
    lon = round(lon_min / 60, 4)
  )]

  # Handle missing FIRs (empty strings to NA)
  dt[fir_id == "", fir_id := NA]

  # Return clean selection
  return(dt[, .(icao, lat, lon, fir_id)])
}
