#' Read PNL (Penalisation/Segment) File
#'
#' Reads a .pnl file defining penalizations (costs) for specific network segments.
#'
#' @description
#' This function parses SAAM/Gasel `.pnl` files. Unlike `.tax` files (which define turn penalties),
#' `.pnl` files define a penalty (in Nautical Miles) for traversing a specific straight-line
#' segment between two points.
#'
#' The file structure is defined as follows:
#' \itemize{
#'   \item \strong{Extension}: pnl
#'   \item \strong{Separator}: One or more spaces (Whitespace)
#'   \item \strong{Comments}: Lines starting with `//` are ignored.
#' }
#'
#' \strong{Record Structure}:
#' \itemize{
#'   \item Field 1: \strong{Point 1} (Start of segment)
#'   \item Field 2: \strong{Point 2} (End of segment)
#'   \item Field 3: \strong{Penalisation} (Cost in NM)
#' }
#'
#' @param pnl_file Path to the .pnl file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{start_point}: The identifier of the starting point.
#'   \item \code{end_point}: The identifier of the ending point.
#'   \item \code{penalty}: Numeric. The added cost (in NM) for using this segment.
#' }
#'
#' @importFrom data.table fread :=
#' @export
read_pnl <- function(pnl_file) {
  if (!file.exists(pnl_file)) stop("PNL file not found: ", pnl_file)

  # Check for empty file
  if (file.size(pnl_file) == 0) {
    warning("PNL file is empty: ", pnl_file)
    return(data.table::data.table(
      start_point = character(),
      end_point = character(),
      penalty = numeric()
    ))
  }

  # Read file
  # sep = "auto" handles "one or more spaces" correctly
  dt <- data.table::fread(
    pnl_file,
    header = FALSE,
    sep = "auto",
    fill = TRUE, # Handling potential trailing comments or irregularities
    col.names = c("start_point", "end_point", "penalty"),
    showProgress = FALSE
  )

  # Basic validation
  if (nrow(dt) == 0) return(dt)

  # --- Data Cleaning ---

  # 1. Filter out comments
  # The description says comments start with "//".
  # Since we read headers as generic columns, these will appear in the first column.
  dt <- dt[!grepl("^//", start_point)]

  # 2. Filter empty rows (whitespace only lines)
  dt <- dt[start_point != "" & end_point != ""]

  # 3. Ensure Types
  # fread might read penalty as character if comments interfered, enforce numeric
  dt[, penalty := as.numeric(penalty)]

  return(dt[])
}
