#' Read ACO (Airspace Colour) File
#'
#' Reads a .aco file defining display attributes (colors, transparency, flags) for 3D airblocks.
#'
#' @description
#' This function parses SAAM `.aco` files. These files link specific airblocks (often defined by
#' Sector:Airblock composite names) to visual properties like RGB color, transparency, and display flags.
#'
#' The file structure is defined as follows:
#' \itemize{
#'   \item \strong{Extension}: aco
#'   \item \strong{Origin}: SAAM
#'   \item \strong{Separator}: Whitespace
#' }
#'
#' \strong{Record Structure}:
#' \itemize{
#'   \item Field 1: \strong{Version} (Format version, usually 1).
#'   \item Field 2: \strong{Airblock Name} (Format: \code{Sector:Airblock} or just \code{Airblock}).
#'   \item Field 3: \strong{Flight Level Bottom} (Padded with 0, e.g., 085).
#'   \item Field 4: \strong{Flight Level Top} (Padded with 0).
#'   \item Field 5: \strong{Nb Colours} (Number of color definitions following).
#'   \item Field 6: \strong{Colour Version}.
#'   \item Field 7: \strong{Colour Name} ("?" is default).
#'   \item Field 8: \strong{Feature Code} (Bitmask for display flags, see details).
#'   \item Field 9: \strong{Colour Flag} (1=Defined here, 0=Inherited).
#'   \item Field 10: \strong{Type} (Usually "C").
#'   \item Field 11: \strong{Transparency} (0-255).
#'   \item Field 12: \strong{Red} (0-255).
#'   \item Field 13: \strong{Green} (0-255).
#'   \item Field 14: \strong{Blue} (0-255).
#' }
#'
#' @param aco_file Path to the .aco file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{airblock_name}: Character (The raw ID from the file).
#'   \item \code{fl_bottom}: Integer.
#'   \item \code{fl_top}: Integer.
#'   \item \code{feature_code}: Integer (Bitmask).
#'   \item \code{transparency}: Integer.
#'   \item \code{red}: Integer.
#'   \item \code{green}: Integer.
#'   \item \code{blue}: Integer.
#'   \item \code{hex}: Character (Derived hex color string for convenience, e.g., "#RRGGBB").
#' }
#'
#' @importFrom data.table fread :=
#' @importFrom grDevices rgb
#' @export
read_aco <- function(aco_file) {
  if (!file.exists(aco_file)) stop("ACO file not found: ", aco_file)

  # Check for empty file
  if (file.size(aco_file) == 0) {
    warning("ACO file is empty: ", aco_file)
    return(data.table::data.table(
      airblock_name = character(),
      fl_bottom = integer(),
      fl_top = integer(),
      feature_code = integer(),
      transparency = integer(),
      red = integer(),
      green = integer(),
      blue = integer()
    ))
  }

  # Read file
  # Using fill=TRUE to handle potential oddities, but expecting 14 cols based on spec
  dt <- data.table::fread(
    aco_file,
    sep = "auto",
    header = FALSE,
    showProgress = FALSE,
    fill = TRUE
  )

  if (nrow(dt) == 0) return(dt)

  # Select and Rename standard columns
  # We assume the standard 14 column layout for valid lines
  # If there are extra columns (multi-color lines), this reader takes the first color set.

  # Map columns based on description index
  # 2: Name, 3: Min, 4: Max, 8: Feature, 11: Trans, 12: R, 13: G, 14: B

  # Ensure we have enough columns before subsetting
  if (ncol(dt) < 14) {
    warning("ACO file format issue: fewer than 14 columns found. Returning raw data.")
    return(dt)
  }

  result <- dt[, .(
    airblock_name = as.character(V2),
    fl_bottom     = as.integer(V3),
    fl_top        = as.integer(V4),
    feature_code  = as.integer(V8),
    transparency  = as.integer(V11),
    red           = as.integer(V12),
    green         = as.integer(V13),
    blue          = as.integer(V14)
  )]

  # --- Helpers ---

  # Add a Hex color string for easier plotting in R
  # We strictly clamp RGB values to 0-255 to prevent errors if file is malformed
  result[, hex := grDevices::rgb(
    pmin(pmax(red, 0), 255),
    pmin(pmax(green, 0), 255),
    pmin(pmax(blue, 0), 255),
    maxColorValue = 255
  )]

  return(result[])
}
