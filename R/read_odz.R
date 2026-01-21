#' Read and Parse STATFOR Forecast Zone Definition File (.odz)
#'
#' Reads a STATFOR ODZ file (typically "FFF_yyyyMM.odz") mapping Forecast Zone IDs
#' to their definitions. Optionally expands combined definitions (e.g., "A+B") into separate rows.
#'
#' @param odz_filename Character. The path to the .odz file.
#' @param expand Logical. If \code{TRUE}, splits definitions separated by "+" into
#' separate rows (e.g., "LEBL+LEVC" becomes two rows). Defaults to \code{FALSE}.
#' @param clean_names Logical. If \code{TRUE} (default), ensures the columns are named
#' "zone_id" and "zone_def".
#'
#' @import data.table
#'
#' @return A \code{data.table}.
#' \itemize{
#'   \item If \code{expand = FALSE}: 1 row per Zone ID.
#'   \item If \code{expand = TRUE}: Multiple rows per Zone ID if the definition contained "+".
#' }
#' Columns: \code{zone_id}, \code{zone_def}.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(data.table)
#'
#' # 1. Create a dummy .odz file with combined definitions
#' sample_odz <- "BarcelonaACC,LEVC
#' BerlinFIR:Berlin,EDDB+EDDI+EDDT
#' Azores,LPFL+LPGR+LPHR
#' SingleAirport,LEBL"
#'
#' tmp_odz <- tempfile(fileext = ".odz")
#' writeLines(sample_odz, tmp_odz)
#'
#' # 2. Read without expansion (Default)
#' # Returns 4 rows
#' dt_raw <- read_odz(tmp_odz, expand = FALSE)
#' print(dt_raw)
#'
#' # 3. Read WITH expansion
#' # 'BerlinFIR:Berlin' will split into 3 rows, 'Azores' into 3 rows
#' dt_expanded <- read_odz(tmp_odz, expand = TRUE)
#' print(dt_expanded)
#'
#' # 4. Clean up
#' unlink(tmp_odz)
#' }
read_odz <- function(odz_filename, expand = FALSE, clean_names = TRUE) {

  # Check if file exists
  if (!file.exists(odz_filename)) {
    stop("File not found: ", odz_filename)
  }

  # Read the data
  odz_dt <- fread(
    file = odz_filename,
    sep = ",",
    header = FALSE,
    fill = TRUE,
    strip.white = TRUE
  )

  # Select only the first two columns and rename
  if (ncol(odz_dt) >= 2) {
    odz_dt <- odz_dt[, 1:2]
  }

  if (clean_names) {
    setnames(odz_dt, c("zone_id", "zone_def"))
  }

  # Ensure the definition is always a character
  odz_dt[, zone_def := as.character(zone_def)]

  # --- Branch: Expand rows if requested ---
  if (expand) {
    # Split the string by "+" (escaped as \\+) and unlist the result.
    # by = zone_id duplicates the zone_id for every new split element.
    odz_dt <- odz_dt[, .(zone_def = unlist(strsplit(zone_def, "\\+"))), by = zone_id]

    # Optional: Trim whitespace again in case the file had "A + B"
    odz_dt[, zone_def := trimws(zone_def)]
  }

  return(odz_dt[])
}
