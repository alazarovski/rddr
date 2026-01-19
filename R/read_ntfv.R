#' Read NTFV (Traffic Volume) File
#'
#' Reads a .ntfv file defining traffic volumes and their flow elements.
#'
#' @description
#' This function parses SAAM/Gasel `.ntfv` files. These files define "Traffic Volumes" (TVs),
#' which are groupings of flights (flows) passing through specific points or airspaces.
#'
#' The file structure is hierarchical:
#' \itemize{
#'   \item \strong{Extension}: ntfv
#'   \item \strong{Separator}: Semicolon (;)
#' }
#'
#' The file consists of:
#' \enumerate{
#'   \item \strong{First Line}: Metadata starting with #.
#'   \item \strong{Traffic Volume Headers (T)}: Define the volume properties. The number of fields varies by location type.
#'   \item \strong{Flow Element Lines (F)}: Define the specific flows included/excluded in that volume.
#' }
#'
#' \strong{Header Types}:
#' \itemize{
#'   \item \strong{Type 1 (AD/AZ)}: 8 Fields. (No FL or Skip info).
#'   \item \strong{Type 2 (AS/SP/DBP)}: 10 Fields. Includes Min/Max FL or Skip In/Out times.
#' }
#'
#' \strong{Common Fields (T)}:
#' \itemize{
#'   \item ID, Name, Category (MO/_), Ref Location Name, Ref Location Type (AD, AZ, AS, SP, DBP), Role (D, A, G), Nb Elements.
#' }
#'
#' \strong{Variable Fields (T)}:
#' \itemize{
#'   \item For AS/SP/DBP: Field 8 (Min FL / Skip In), Field 9 (Max FL / Skip Out).
#' }
#'
#' \strong{Flow Lines (F)}:
#' \itemize{
#'   \item Field 2: Flow Element ID
#'   \item Field 3: Flow Type (IN, IE, EX, EM)
#' }
#'
#' @param ntfv_file Path to the .ntfv file.
#'
#' @return A \code{data.table} with the following columns:
#' \itemize{
#'   \item \code{tv_id}: Traffic Volume ID.
#'   \item \code{tv_name}: Traffic Volume Name/Description.
#'   \item \code{tv_category}: Category (e.g., MO).
#'   \item \code{ref_loc_name}: Reference Location Name.
#'   \item \code{ref_loc_type}: Reference Location Type (AD, AZ, AS, SP, DBP).
#'   \item \code{ref_loc_role}: Reference Role (D, A, G).
#'   \item \code{min_fl_or_skip_in}: Min Flight Level or Skip In time (Numeric).
#'   \item \code{max_fl_or_skip_out}: Max Flight Level or Skip Out time (Numeric).
#'   \item \code{flow_id}: The ID of the flow element (Child).
#'   \item \code{flow_type}: The type of the flow element (IN, EX, etc.).
#' }
#'
#' @importFrom data.table fread := fifelse
#' @importFrom dplyr na_if
#' @importFrom zoo na.locf
#' @export
read_ntfv <- function(ntfv_file) {
  if (!file.exists(ntfv_file)) stop("NTFV file not found: ", ntfv_file)

  if (file.size(ntfv_file) == 0) {
    warning("NTFV file is empty: ", ntfv_file)
    return(data.table::data.table(
      tv_id = character(), flow_id = character(), flow_type = character()
    ))
  }

  # Read file with fill=TRUE to handle variable line lengths (Header vs Body)
  dt <- data.table::fread(
    ntfv_file,
    sep = ";",
    skip = 1, # Skip metadata
    header = FALSE,
    colClasses = "character", # Read all as char to safely parse mixed formats
    fill = TRUE,
    showProgress = FALSE
  )

  if (nrow(dt) == 0) return(dt)

  # Trim whitespace on key columns
  # V1 is line type (T/F), V6 is Ref Loc Type (important for parsing logic)
  dt[, `:=`(V1 = trimws(V1), V6 = trimws(V6))]

  # --- 1. Parse Traffic Volume Headers (T Lines) ---

  # Logic:
  # AD/AZ (8 cols): V8 is Nb Elements (ignore for now). No FL info.
  # AS/SP/DBP (10 cols): V8=Min, V9=Max.

  # We create standardized parent columns
  dt[V1 == "T", `:=`(
    p_tv_id       = V2,
    p_tv_name     = V3,
    p_tv_cat      = V4,
    p_ref_name    = V5,
    p_ref_type    = V6,
    p_ref_role    = V7,

    # Conditional Parsing based on Ref Type (V6)
    # If V6 is AS/SP/DBP, take V8/V9. Else NA.
    p_val_min     = data.table::fifelse(V6 %in% c("AS", "SP", "DBP"), V8, NA_character_),
    p_val_max     = data.table::fifelse(V6 %in% c("AS", "SP", "DBP"), V9, NA_character_)
  )]

  # Handle missing data "_" in parent columns
  cols_to_clean <- c("p_tv_name", "p_tv_cat", "p_val_min", "p_val_max")
  for (col in cols_to_clean) {
    dt[get(col) == "_", (col) := NA]
  }

  # --- 2. Fill Down Parent Info ---
  parent_cols <- c("p_tv_id", "p_tv_name", "p_tv_cat", "p_ref_name", "p_ref_type", "p_ref_role", "p_val_min", "p_val_max")
  dt[, (parent_cols) := lapply(.SD, function(x) zoo::na.locf(x, na.rm = FALSE)), .SDcols = parent_cols]

  # --- 3. Extract Flow Elements (F Lines) ---
  # Keep only F lines that have valid parent info
  result <- dt[V1 == "F" & !is.na(p_tv_id), .(
    tv_id              = p_tv_id,
    tv_name            = p_tv_name,
    tv_category        = p_tv_cat,
    ref_loc_name       = p_ref_name,
    ref_loc_type       = p_ref_type,
    ref_loc_role       = p_ref_role,
    min_fl_or_skip_in  = as.numeric(p_val_min),
    max_fl_or_skip_out = as.numeric(p_val_max),
    flow_id            = V2,
    flow_type          = V3
  )]

  return(result[])
}
