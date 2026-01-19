#' Read RTS (Routes) File
#'
#' Reads a .rts file defining the sequence of navigation points that make up airways/routes.
#'
#' @description
#' This function parses SAAM/Gasel `.rts` files. These files define the structure of airways
#' (routes) by listing the sequence of points (waypoints, VORs, etc.) that comprise them.
#'
#' The file structure is defined as follows:
#' \itemize{
#'   \item \strong{Extension}: rts
#'   \item \strong{Separator}: Semicolon (;)
#'   \item \strong{Sort}: By route name, then by sequence number.
#' }
#'
#' The file consists of:
#' \enumerate{
#'   \item \strong{First Line}: Metadata starting with #.
#'   \item \strong{Body Lines (L)}: Records defining a point on a route.
#' }
#'
#' \strong{Record Structure (L lines)}:
#' \itemize{
#'   \item Field 1: \strong{L} (Link/Line indicator)
#'   \item Field 2: \strong{Route Name} (e.g., A1, A100)
#'   \item Field 3: \strong{Type} (Usually "AR" for Airway Route)
#'   \item Field 4: \strong{Time In} (Validity Start - often 0000...)
#'   \item Field 5: \strong{Time Out} (Validity End - often 9999...)
#'   \item Field 6: \strong{Point ID} (The navigation point name)
#'   \item Field 7: \strong{Point Type} (e.g., SP, DBP, VTR)
#'   \item Field 8: \strong{Sequence Number} (Order of the point in the route)
#' }
#'
#' @param routes_file Path to the .rts file.
#'
#' @return A \code{data.table} ordered by Route and Sequence, with columns:
#' \itemize{
#'   \item \code{route_id}: The name of the airway/route.
#'   \item \code{type}: Route type (e.g., AR).
#'   \item \code{time_in}: Validity start time (as character).
#'   \item \code{time_out}: Validity end time (as character).
#'   \item \code{point_id}: The identifier of the navigation point.
#'   \item \code{point_type}: The type of the navigation point.
#'   \item \code{sequence}: Integer representing the order of points.
#' }
#'
#' @importFrom data.table fread :=
#' @export
read_routes <- function(routes_file) {
  if (!file.exists(routes_file)) stop("RTS file not found: ", routes_file)

  # Check for empty file
  if (file.size(routes_file) == 0) {
    warning("RTS file is empty: ", routes_file)
    return(data.table::data.table(
      route_id = character(),
      type = character(),
      time_in = character(),
      time_out = character(),
      point_id = character(),
      point_type = character(),
      sequence = integer()
    ))
  }

  # Read file
  dt <- data.table::fread(
    routes_file,
    sep = ";",
    skip = 1, # Skip metadata
    header = FALSE,
    col.names = c("line_type", "route_id", "type", "time_out", "time_in", "point_id", "point_type", "sequence"),
    colClasses = list(
      character = c("line_type", "route_id", "type", "time_in", "time_out", "point_id", "point_type"),
      integer = c("sequence")
    ),
    showProgress = FALSE,
    fill = TRUE
  )

  if (nrow(dt) == 0) return(dt)

  # Filter for 'L' lines only (though usually all are L)
  dt <- dt[line_type == "L"]

  # Remove the 'line_type' column as it's redundant now
  dt[, line_type := NULL]

  # --- Data Cleaning ---

  # Trim whitespace from character columns
  char_cols <- c("route_id", "type", "point_id", "point_type")
  dt[, (char_cols) := lapply(.SD, trimws), .SDcols = char_cols]

  # Ensure Sequence is strictly ordered
  # (fread handles sorting usually, but good to ensure for routing logic)
  data.table::setorder(dt, route_id, sequence)

  # Column Reordering for clarity
  # Moving time_in before time_out is more intuitive
  data.table::setcolorder(dt, c("route_id", "type", "time_in", "time_out", "point_id", "point_type", "sequence"))

  return(dt[])
}
