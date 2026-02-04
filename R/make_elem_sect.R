#' Create Elementary Sectors from Airblocks and Sector Lists
#'
#' This function joins sector definitions (SLS) with airblock coordinates (ARE)
#' to generate elementary sector geometries. It produces a grouped table of
#' polygons, supporting both raw data.table and spatial sf formats.
#'
#' @param sls A \code{data.table} created by \code{read_sls()}. Must contain
#' \code{sector_id}, \code{volume_id}, \code{fl_bottom}, and \code{fl_top}.
#' @param are A \code{data.table} created by \code{read_are()}. Must contain
#' \code{volume_id}, \code{lon}, \code{lat}, and \code{sequence}.
#' @param make_sf Logical. If \code{TRUE} (default), returns an \code{sf} object. If \code{FALSE},
#' returns a \code{data.table} with an \code{sfc} geometry column.
#' @param sf_crs Coordinate Reference System to use if \code{make_sf = TRUE}. Defaults to 4326.
#'
#' @details
#' The function performs an inner join on \code{volume_id}. It ensures that the
#' resulting polygons are closed by appending the first coordinate of each
#' airblock to the end if necessary.
#'
#'
#'
#' @return A \code{data.table} or an \code{sf} object grouped by
#' \code{sector_id}, \code{volume_id}, and flight levels.
#'
#' @import data.table
#' @importFrom sf st_polygon st_sfc st_as_sf
#' @export
#'
#' @examples
#' \dontrun{
#' # Assuming sls and are objects were created via read_sls() and read_are()
#' # sls <- read_sls("FF_2024.sls")
#' # are <- read_are("FF_2024.are")
#'
#' # Create dummy data for demonstration
#' library(data.table)
#' dummy_sls <- data.table(sector_id = "EDYY", volume_id = "V1", fl_bottom = 0, fl_top = 350)
#' dummy_are <- data.table(
#'   volume_id = "V1",
#'   lon = c(0, 5, 5, 0),
#'   lat = c(0, 0, 5, 5),
#'   sequence = 1:4
#' )
#'
#' sect_sf <- make_elem_sect(dummy_sls, dummy_are, make_sf = TRUE)
#' plot(sect_sf["sector_id"])
#' }
make_elem_sect <- function(sls, are, make_sf = TRUE, sf_crs = 4326) {

  # 1. Validation and Copying
  if (!all(c("volume_id", "sector_id", "fl_bottom", "fl_top") %in% names(sls))) {
    stop("sls object is missing required columns. Ensure it was created by read_sls().")
  }
  if (!all(c("volume_id", "lon", "lat", "sequence") %in% names(are))) {
    stop("are object is missing required columns. Ensure it was created by read_are().")
  }

  # Ensure inputs are data.tables and create internal copies to avoid side effects
  sls_dt <- as.data.table(sls)
  are_dt <- as.data.table(are)

  # 2. Join the sectors and airblocks
  # Using inner join (nomatch=NULL) to ensure only valid mappings remain
  sls_are <- are_dt[sls_dt, on = .(volume_id), nomatch = NULL, allow.cartesian = TRUE]

  if (nrow(sls_are) == 0) {
    warning("Join resulted in 0 rows. Check if volume_id values match between sls and are.")
    return(sls_are)
  }

  # 3. Ensure strict ordering for polygon creation
  setorder(sls_are, sector_id, volume_id, fl_bottom, fl_top, sequence)

  # 4. Group and create polygons
  dt_sf <- sls_are[, .(
    geometry = {
      # Extract coordinates
      mat <- as.matrix(.SD[, .(lon, lat)])

      # Industry Check: Ensure the polygon is closed (First point == Last point)
      if (nrow(mat) > 0 && !all(mat[1, ] == mat[nrow(mat), ])) {
        mat <- rbind(mat, mat[1, ])
      }

      # Convert matrix to polygon geometry list
      # Wrapped in st_sfc to ensure it's a list-column of geometries
      sf::st_sfc(sf::st_polygon(list(mat)), crs = sf_crs)
    }
  ),
  by = .(sector_id, volume_id, fl_bottom, fl_top),
  .SDcols = c("lon", "lat")
  ]

  # 5. Optional Conversion to SF Object
  if (make_sf) {
    dt_sf <- sf::st_as_sf(dt_sf)
  }

  return(dt_sf)
}
