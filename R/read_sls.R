#' Read SLS (Sector Level) File
#'
#' Reads the .sls file defining sector vertical limits and airblock mapping.
#'
#' @description
#' This function parses SAAM/Airspace Editor `.sls` files which define the composition of sectors
#' by mapping them to specific volumes (airblocks) and defining vertical limits.
#'
#' The file structure is defined as follows:
#' \itemize{
#'   \item \strong{Extension}: sls
#'   \item \strong{Origin}: Airspace Editor
#'   \item \strong{Separator}: Blank (whitespace)
#'   \item \strong{Sort}: Grouped by sector name
#' }
#'
#' \strong{Functionality}:
#' The file links sectors to volumes defined in the ARE (ASCII Region) file.
#'
#' The file consists of rows with the following fields:
#' \enumerate{
#'   \item \strong{sector_id}: Sector name (Max 19 chars).
#'   \item \strong{volume_sign}: Always "+" (indicates the volume is added to the sector).
#'   \item \strong{volume_id}: Refers to the name of the volume in the ARE file (max 24 chars).
#'   \item \strong{fl_bottom}: Flight Level (FL), overwrites the level in the ARE file.
#'   \item \strong{fl_top}: Flight Level (FL), overwrites the level in the ARE file.
#' }
#'
#' \emph{Note: Meta lines supported in previous SLS formats are not supported in this parser. Use SPC format for metadata.}
#'
#' @param sls_file Path to the .sls file.
#'
#' @return A \code{data.table} containing sector definitions with columns:
#' \itemize{
#'   \item \code{sector_id}: The identifier for the sector.
#'   \item \code{volume_sign}: The inclusion flag (should be "+").
#'   \item \code{volume_id}: The identifier for the airblock/volume.
#'   \item \code{fl_bottom}: The lower vertical limit (Flight Level).
#'   \item \code{fl_top}: The upper vertical limit (Flight Level).
#' }
#'
#' @importFrom data.table fread
#' @export
read_sls <- function(sls_file) {
  if (!file.exists(sls_file)) stop("SLS file not found: ", sls_file)

  # Check if file is empty to avoid fread error on empty input
  if (file.size(sls_file) == 0) {
    warning("SLS file is empty: ", sls_file)
    return(data.table::data.table(
      sector_id = character(),
      volume_sign = character(),
      volume_id = character(),
      fl_bottom = integer(),
      fl_top = integer()
    ))
  }

  data.table::fread(
    sls_file,
    header = FALSE,
    sep = " ",
    col.names = c("sector_id", "volume_sign", "volume_id", "fl_bottom", "fl_top"),
    showProgress = FALSE
  )
}
