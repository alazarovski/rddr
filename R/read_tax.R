#' Read TAX (Penalisation/Turn) File
#'
#' Reads a .tax file defining turning penalties or forbidden turns between navigation points.
#'
#' @description
#' This function parses SAAM/Gasel `.tax` files (often referred to as "penalisation" files).
#' These files define specific turn sequences (Point 1 -> Point 2 -> Point 3) that carry
#' a penalty or restriction.
#'
#' The structure defines a specific geometric turn:
#' \itemize{
#'   \item \strong{Incoming Leg}: Point 1 to Point 2.
#'   \item \strong{Turn Point}: Point 2.
#'   \item \strong{Outgoing Leg}: Point 2 to Point 3.
#' }
#'
#' The file structure is defined as follows:
#' \itemize{
#'   \item \strong{Extension}: tax
#'   \item \strong{Origin}: Produced manually
#'   \item \strong{Separator}: Whitespace (Space or Tab)
#'   \item \strong{Sort}: No specific sort order
#' }
#'
#' \strong{Record Structure}:
#' \itemize{
#'   \item Field 1: \strong{Point 1} (Previous point)
#'   \item Field 2: \strong{Point 2} (The vertex/turn point)
#'   \item Field 3: \strong{Point 3} (Next point)
#' }
#'
#' @param tax_file Path to the .tax file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{point_1}: The start of the incoming segment.
#'   \item \code{point_2}: The turning point.
#'   \item \code{point_3}: The end of the outgoing segment.
#' }
#'
#' @importFrom data.table fread
#' @export
read_tax <- function(tax_file) {
  if (!file.exists(tax_file)) stop("TAX file not found: ", tax_file)

  # Check for empty file
  if (file.size(tax_file) == 0) {
    warning("TAX file is empty: ", tax_file)
    return(data.table::data.table(
      point_1 = character(),
      point_2 = character(),
      point_3 = character()
    ))
  }

  # Read file
  # sep = " " (or auto-detection of whitespace) handles both spaces and tabs
  dt <- data.table::fread(
    tax_file,
    header = FALSE,
    sep = "auto", # Safer for mixed whitespace (tabs/spaces)
    col.names = c("point_1", "point_2", "point_3"),
    colClasses = "character", # Points are IDs, keep as char
    showProgress = FALSE,
    fill = TRUE
  )

  # Basic validation
  if (nrow(dt) == 0) return(dt)

  # Remove any empty rows that might result from trailing newlines
  dt <- dt[point_1 != "" & point_2 != "" & point_3 != ""]

  return(dt[])
}
