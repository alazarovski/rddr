#' Read CFG (Configuration) File
#'
#' Reads a .cfg file defining Air Traffic Control (ATC) configurations and their sector compositions.
#'
#' @description
#' This function parses SAAM/Gasel `.cfg` files. These files define how elementary sectors
#' or airspaces are grouped into operational configurations (e.g., "CONF1", "Night_Config")
#' under a specific ACC (Area Control Center) or airspace family.
#'
#' The file structure is defined as follows:
#' \itemize{
#'   \item \strong{Extension}: cfg
#'   \item \strong{Origin}: Gasel, SAAM
#'   \item \strong{Separator}: Semicolon (;)
#'   \item \strong{Sort}: By family/ACC name, then by configuration name.
#' }
#'
#' The file consists of:
#' \enumerate{
#'   \item \strong{First Line}: Metadata starting with # (e.g., version, dates, record count).
#'   \item \strong{Body Lines}: Records linking an ACC/Family and Configuration to a specific Sector.
#' }
#'
#' \strong{Record Structure}:
#' \itemize{
#'   \item Field 1: \strong{ACC Name} (Family or Grouping ID)
#'   \item Field 2: \strong{Configuration Name} (The ID of the specific configuration)
#'   \item Field 3: \strong{Sector Name} (The component included in this configuration)
#' }
#'
#' @param cfg_file Path to the .cfg file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{acc_id}: The identifier of the ACC or Airspace Family.
#'   \item \code{config_id}: The name of the configuration.
#'   \item \code{sector_id}: The identifier of the sector belonging to this configuration.
#' }
#'
#' @importFrom data.table fread
#' @export
read_cfg <- function(cfg_file) {
  if (!file.exists(cfg_file)) stop("CFG file not found: ", cfg_file)

  # Check for empty file
  if (file.size(cfg_file) == 0) {
    warning("CFG file is empty: ", cfg_file)
    return(data.table::data.table(
      acc_id = character(),
      config_id = character(),
      sector_id = character()
    ))
  }

  # Read the file
  # skip = 1 ignores the metadata line starting with #
  dt <- data.table::fread(
    cfg_file,
    sep = ";",
    skip = 1,
    header = FALSE,
    col.names = c("acc_id", "config_id", "sector_id"),
    colClasses = "character", # All IDs should be character to prevent scientific notation or numeric conversion
    showProgress = FALSE,
    fill = TRUE
  )

  # Basic Validation: Ensure we actually have data
  if (nrow(dt) == 0) {
    return(dt)
  }

  # Clean whitespace from IDs (crucial for accurate merging later)
  cols_to_clean <- c("acc_id", "config_id", "sector_id")
  dt[, (cols_to_clean) := lapply(.SD, trimws), .SDcols = cols_to_clean]

  return(dt[])
}
