#' Read RLEX (Route Length Extension Exception) File
#'
#' Reads a .rlex file defining allowed route length extensions between airport pairs.
#'
#' @description
#' This function parses SAAM/Gasel `.rlex` files. These files specify exceptions to standard
#' route length validation rules, allowing specific departure-arrival pairs to have
#' a defined route length extension (in Nautical Miles).
#'
#' The file structure is defined as follows:
#' \itemize{
#'   \item \strong{Extension}: rlex
#'   \item \strong{Origin}: Produced manually
#'   \item \strong{Separator}: Whitespace (Space or Tab)
#' }
#'
#' \strong{Record Structure}:
#' \itemize{
#'   \item Field 1: \strong{ADEP} (Departure Airport ICAO)
#'   \item Field 2: \strong{ADES} (Arrival Airport ICAO)
#'   \item Field 3: \strong{Allowed Extension} (Numeric, in NM)
#' }
#'
#' @param rlex_file Path to the .rlex file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{adep}: Departure airport ICAO code.
#'   \item \code{ades}: Arrival airport ICAO code.
#'   \item \code{allowed_extension}: The allowed extension in Nautical Miles.
#' }
#'
#' @importFrom data.table fread
#' @export
read_rlex <- function(rlex_file) {
  if (!file.exists(rlex_file)) stop("RLEX file not found: ", rlex_file)

  # Check for empty file
  if (file.size(rlex_file) == 0) {
    warning("RLEX file is empty: ", rlex_file)
    return(data.table::data.table(
      adep = character(),
      ades = character(),
      allowed_extension = numeric()
    ))
  }

  # Read file
  dt <- data.table::fread(
    rlex_file,
    header = FALSE,
    sep = "auto",
    col.names = c("adep", "ades", "allowed_extension"),
    colClasses = list(
      character = c("adep", "ades"),
      numeric = c("allowed_extension")
    ),
    showProgress = FALSE,
    fill = TRUE
  )

  if (nrow(dt) == 0) return(dt)

  # Clean any potential empty lines
  dt <- dt[adep != "" & ades != ""]

  return(dt[])
}
