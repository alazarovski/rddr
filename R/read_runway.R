#' Read RUNWAY File
#'
#' Reads a .runway file defining runway configurations, availability, and sequencing parameters.
#'
#' @description
#' This function parses SAAM/Gasel `.runway` files. These files define which runways (QFU)
#' are active for specific airports on specific dates, along with their operational parameters.
#'
#' The file structure is defined as follows:
#' \itemize{
#'   \item \strong{Extension}: runway
#'   \item \strong{Origin}: Gasel, SAAM
#'   \item \strong{Separator}: Semicolon (;)
#'   \item \strong{Sort}: By Date, then Airport, then QFU.
#' }
#'
#' The file consists of:
#' \enumerate{
#'   \item \strong{First Line}: Metadata starting with #.
#'   \item \strong{Body Lines}: Records defining runway usage.
#' }
#'
#' \strong{Record Structure}:
#' \itemize{
#'   \item Field 1: \strong{Date} (dd/MM/yyyy)
#'   \item Field 2: \strong{Airport ICAO} (4 chars)
#'   \item Field 3: \strong{QFU} (Runway Designator, e.g., 29C, 06)
#'   \item Field 4: \strong{Start Time} (HHMM)
#'   \item Field 5: \strong{End Time} (HHMM)
#'   \item Field 6: \strong{Default} (Y/N - Is this the default runway configuration?)
#'   \item Field 7: \strong{Taxi Time} (Minutes)
#'   \item Field 8: \strong{TIS} (Time to Insert into Sequence - Minutes)
#'   \item Field 9: \strong{TRS} (Time to Remove from Sequence - Minutes)
#'   \item Field 10: \strong{Origin} (E=Environment/Planned, T=Tactical/Actual)
#' }
#'
#' @param runway_file Path to the .runway file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{date}: Date object.
#'   \item \code{icao}: Character.
#'   \item \code{qfu}: Character (Runway ID).
#'   \item \code{start_time}: Character (HHMM).
#'   \item \code{end_time}: Character (HHMM).
#'   \item \code{is_default}: Logical (TRUE if 'Y', FALSE if 'N').
#'   \item \code{taxi_time}: Integer.
#'   \item \code{tis}: Integer.
#'   \item \code{trs}: Integer.
#'   \item \code{origin}: Character.
#' }
#'
#' @importFrom data.table fread :=
#' @export
read_runway <- function(runway_file) {
  if (!file.exists(runway_file)) stop("Runway file not found: ", runway_file)

  # Check for empty file
  if (file.size(runway_file) == 0) {
    warning("Runway file is empty: ", runway_file)
    return(data.table::data.table(
      date = as.Date(character()),
      icao = character(),
      qfu = character(),
      start_time = character(),
      end_time = character(),
      is_default = logical(),
      taxi_time = integer(),
      tis = integer(),
      trs = integer(),
      origin = character()
    ))
  }

  # Read file
  dt <- data.table::fread(
    runway_file,
    sep = ";",
    skip = 1,
    header = FALSE,
    col.names = c("date", "icao", "qfu", "start_time", "end_time", "is_default", "taxi_time", "tis", "trs", "origin"),
    colClasses = list(
      character = c("date", "icao", "qfu", "start_time", "end_time", "is_default", "origin"),
      integer = c("taxi_time", "tis", "trs")
    ),
    showProgress = FALSE,
    fill = TRUE
  )

  if (nrow(dt) == 0) return(dt)

  # --- Data Cleaning ---

  # Convert Date
  dt[, date := as.Date(date, format = "%d/%m/%Y")]

  # Convert Y/N to Logical
  dt[, is_default := (is_default == "Y")]

  # Trim whitespace from IDs
  char_cols <- c("icao", "qfu", "origin")
  dt[, (char_cols) := lapply(.SD, trimws), .SDcols = char_cols]

  return(dt[])
}
