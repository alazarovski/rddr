#' Read SPC (Airspace) File
#'
#' Reads the .spc file defining airspace hierarchy and types.
#'
#' @description
#' This function parses SAAM/Gasel `.spc` files which describe airspace organization.
#'
#' @param spc_file Path to the .spc file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{airspace_type}: The type of the parent airspace (e.g., "AUAG", "NAS").
#'   \item \code{airspace_id}: The identifier of the parent airspace.
#'   \item \code{sub_airspace_id}: The identifier of the child element (sub-airspace or sector).
#'   \item \code{sub_airspace_type}: The type of the child element (e.g., "AUA", "FIR").
#' }
#'
#' @importFrom data.table fread := fifelse
#' @importFrom zoo na.locf
#' @export
read_spc <- function(spc_file) {
  if (!file.exists(spc_file)) stop("SPC file not found: ", spc_file)

  # Read file
  # V1=LineType, V2=ID, V3=Name(A)/Type(S), V4=Type(A)
  asp <- data.table::fread(
    spc_file,
    sep = ";",
    skip = 1,
    header = FALSE,
    colClasses = "character",
    fill = TRUE,
    showProgress = FALSE
  )

  if (ncol(asp) < 2) stop("SPC file format appears invalid (too few columns).")

  # Trim whitespace for robust matching
  cols_to_trim <- paste0("V", 1:min(4, ncol(asp)))
  asp[, (cols_to_trim) := lapply(.SD, trimws), .SDcols = cols_to_trim]

  # --- Logic Explanation ---
  # 'A' Lines (Parent):
  #   V2 = Airspace ID
  #   V4 = Airspace Type
  # 'S' Lines (Child):
  #   V2 = Sub-airspace ID
  #   V3 = Sub-airspace Type (The description says Field 3 is Sub-airspace type)

  asp[, `:=`(
    # Capture Parent Info
    airspace_id   = data.table::fifelse(V1 == "A", V2, NA_character_),
    airspace_type = data.table::fifelse(V1 == "A", V4, NA_character_),

    # Capture Child Info
    sub_airspace_id   = data.table::fifelse(V1 == "S", V2, NA_character_),
    sub_airspace_type = data.table::fifelse(V1 == "S", V3, NA_character_)
  )]

  # Fill parent data downwards to the children
  asp[, `:=`(
    airspace_id   = zoo::na.locf(airspace_id, na.rm = FALSE),
    airspace_type = zoo::na.locf(airspace_type, na.rm = FALSE)
  )]

  # Return only the child rows (Body)
  result <- asp[V1 == "S" & !is.na(sub_airspace_id), .(
    airspace_type,
    airspace_id,
    sub_airspace_id,
    sub_airspace_type
  )]

  return(result[])
}
