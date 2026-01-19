#' Read ARE (Newmaxo ASCII Region) File
#'
#' Reads the .are file defining the coordinates (vertices) of airblocks/volumes.
#'
#' @description
#' This function parses SAAM/Newmaxo `.are` files. These files define the 2D geometry
#' of airblocks. The file is structured as a repeating sequence of a Header line followed
#' by multiple Body lines (vertices).
#'
#' \itemize{
#'   \item \strong{Extension}: are
#'   \item \strong{Origin}: Newmaxo, SAAM, CAPAN
#'   \item \strong{Separator}: Blank (whitespace)
#' }
#'
#' \strong{Header Line (Metadata)}:
#' \itemize{
#'   \item Field 1: Number of points (vertices)
#'   \item Field 2-3: Label latitude/longitude (Center of label, not a vertex)
#'   \item Field 4-14: Attributes (Levels, flags, colors)
#'   \item Field 15: \strong{Volume Name} (Airblock ID)
#' }
#'
#' \strong{Body Line (Geometry)}:
#' \itemize{
#'   \item Field 1: Latitude (minutes)
#'   \item Field 2: Longitude (minutes)
#' }
#'
#' @param are_file Path to the .are file.
#'
#' @return A \code{data.table} ordered by sequence, containing:
#' \itemize{
#'   \item \code{volume_id}: The identifier of the airblock/volume.
#'   \item \code{lat}: Latitude in decimal degrees.
#'   \item \code{lon}: Longitude in decimal degrees.
#'   \item \code{sequence}: The original ordering of the points (crucial for polygon closure).
#' }
#'
#' @importFrom data.table fread := fifelse setorder
#' @importFrom zoo na.locf
#' @export
read_are <- function(are_file) {
  if (!file.exists(are_file)) stop("ARE file not found: ", are_file)

  # Check for empty file
  if (file.size(are_file) == 0) {
    warning("ARE file is empty: ", are_file)
    return(data.table::data.table(volume_id=character(), lat=numeric(), lon=numeric(), sequence=integer()))
  }

  # Read file with fill=TRUE because Headers have 15 cols and Body has 2
  ab <- data.table::fread(
    are_file,
    sep = " ",
    header = FALSE,
    fill = TRUE,
    showProgress = FALSE
  )

  # --- 1. Identify Headers vs Body ---
  # Header lines have a Volume Name in V15.
  # Body lines have only V1/V2 (V4 is usually NA or empty).

  # Clean up potential whitespace in key columns
  # If V15 exists (file has headers), trim it. If file is malformed/short, create dummy.
  if (ncol(ab) >= 15) {
    ab[, V15 := trimws(V15)]
  } else {
    # If file has fewer than 15 columns, it's likely malformed or only body lines without headers
    stop("ARE file structure invalid: fewer than 15 columns found (Headers missing).")
  }

  # --- 2. Extract Data ---
  # We identify a row as a header if V4 (Flights) is NOT NA/Empty.
  # (Body lines only have V1/V2, so V4 would be NA).

  ab[, `:=`(
    # If V4 has data, this is a header row.
    is_header = !is.na(V4) & V4 != "",

    # Extract Volume ID (from Header V15)
    raw_id = data.table::na_if(V15, "")
  )]

  # --- 3. Fill Metadata ---
  # Fill the Volume ID down from the Header to the following Body lines
  ab[, volume_id := zoo::na.locf(raw_id, na.rm = FALSE)]

  # --- 4. Extract Coordinates & Convert ---
  # Body lines: V1=Lat, V2=Lon.
  # Header lines: V2=Lat, V3=Lon (Label position).
  # We extract both for now, but we will filter headers out later.
  ab[, `:=`(
    lat_min = data.table::fifelse(is_header, V2, V1),
    lon_min = data.table::fifelse(is_header, V3, V2)
  )]

  # Convert Minutes to Decimal Degrees
  # Using as.numeric to ensure safety against accidental char reads
  ab[, `:=`(
    lat = round(as.numeric(lat_min) / 60, 4),
    lon = round(as.numeric(lon_min) / 60, 4)
  )]

  # --- 5. Clean & Order ---
  # Remove the Header lines from the geometry.
  # The Header coords are "Label Locations", not polygon vertices.
  # Including them creates spikes in the polygon.
  ab_clean <- ab[(is_header == FALSE) & !is.na(lat) & !is.na(lon)]

  # Keep original sequence order (Critical for Polygon creation)
  ab_clean[, sequence := .I]

  # Select final columns
  result <- ab_clean[, .(volume_id, lat, lon, sequence)]

  return(result[])
}
