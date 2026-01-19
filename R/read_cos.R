#' Read COS (Opening Scheme) File
#'
#' Reads a .cos file defining the operational opening scheme (schedule) of configurations.
#'
#' @description
#' This function parses SAAM/Gasel `.cos` files. These files determine which configuration
#' (defined in `.cfg` files) is active for a specific ACC/Airspace during a specific time window.
#'
#' The file structure is defined as follows:
#' \itemize{
#'   \item \strong{Extension}: cos
#'   \item \strong{Origin}: Gasel, SAAM
#'   \item \strong{Separator}: Semicolon (;)
#'   \item \strong{Sort}: By period, then family, then start time.
#' }
#'
#' The file consists of:
#' \enumerate{
#'   \item \strong{First Line}: Metadata starting with # (e.g., version, dates).
#'   \item \strong{Body Lines}: Records defining the schedule.
#' }
#'
#' \strong{Record Structure}:
#' \itemize{
#'   \item Field 1: \strong{Date} (dd/MM/yyyy)
#'   \item Field 2: \strong{ACC Name} (Family/Group ID)
#'   \item Field 3: \strong{Start Time} (hh:mm)
#'   \item Field 4: \strong{End Time} (hh:mm)
#'   \item Field 5: \strong{Configuration Name} (ID of the active configuration)
#'   \item Field 6: \strong{Origin} ('E' = Environment/Planned, 'T' = Tactical/Actual)
#' }
#'
#' @param cos_file Path to the .cos file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{date}: Date object (Date class).
#'   \item \code{acc_id}: The identifier of the ACC/Family.
#'   \item \code{start_time}: Character (hh:mm).
#'   \item \code{end_time}: Character (hh:mm).
#'   \item \code{config_id}: The identifier of the configuration.
#'   \item \code{origin_type}: Character ('E' or 'T').
#' }
#'
#' @importFrom data.table fread :=
#' @export
read_cos <- function(cos_file) {
  if (!file.exists(cos_file)) stop("COS file not found: ", cos_file)

  # Check for empty file
  if (file.size(cos_file) == 0) {
    warning("COS file is empty: ", cos_file)
    return(data.table::data.table(
      date = as.Date(character()),
      acc_id = character(),
      start_time = character(),
      end_time = character(),
      config_id = character(),
      origin_type = character()
    ))
  }

  # Read the file
  # skip = 1 to ignore metadata
  # colClasses = "character" ensures 00:00 isn't coerced to numeric or logical
  dt <- data.table::fread(
    cos_file,
    sep = ";",
    skip = 1,
    header = FALSE,
    col.names = c("date", "acc_id", "start_time", "end_time", "config_id", "origin_type"),
    colClasses = "character",
    showProgress = FALSE,
    fill = TRUE
  )

  # Basic validation
  if (nrow(dt) == 0) return(dt)

  # --- Data Cleaning ---

  # Trim whitespace from IDs to ensure clean joins with other files
  cols_to_trim <- c("acc_id", "config_id", "origin_type")
  dt[, (cols_to_trim) := lapply(.SD, trimws), .SDcols = cols_to_trim]

  # Convert Date from dd/MM/yyyy to R Date object
  # We use standard as.Date. If performance is critical for massive files,
  # data.table::as.IDate is an option, but as.Date is safer for general use.
  dt[, date := as.Date(date, format = "%d/%m/%Y")]

  return(dt[])
}
