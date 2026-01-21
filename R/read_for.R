#' Read and Process STATFOR Demand Forecast File (.for)
#'
#' Reads a STATFOR forecast file (typically "FFF_yyyyMM.for") and optionally parses it
#' from wide format into a long format with interpolated growth factors.
#'
#' @param for_filename Character. The path to the .for file.
#' @param year_base Integer. The reference year used for growth calculation (e.g., 2019).
#' @param dep_code Character vector (Optional). List of departure codes (case-insensitive) to filter by.
#' @param des_code Character vector (Optional). List of destination codes (case-insensitive) to filter by.
#' @param year_fcst Integer vector. The specific years to return in the final output. Defaults to 2025:2050.
#' @param process Logical. If \code{TRUE} (default), the function performs reshaping, interpolation,
#' and growth factor calculations. If \code{FALSE}, it returns the raw data as read by \code{fread}.
#'
#' @import data.table
#' @importFrom zoo na.approx
#' @importFrom magrittr %>%
#'
#' @return A \code{data.table}.
#' If \code{process = TRUE}, returns a long-format table with columns:
#' \code{ftype}, \code{area_dep}, \code{area_des}, \code{fyear}, \code{value}, \code{chg}, \code{gf}.
#' If \code{process = FALSE}, returns the raw wide-format table.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' library(data.table)
#'
#' # 1. Create a dummy .for file for testing
#' sample_content <- "RANK;Dep;Des;2020;2025;2030
#' Base;Albania;Austria;0.000;10.500;20.100
#' Base;Albania;Belgium;0.000;5.000;15.000
#' High;Albania;Austria;0.000;12.000;25.000
#' Low;Albania;Austria;0.000;8.000;15.000"
#'
#' tmp_file <- tempfile(fileext = ".for")
#' writeLines(sample_content, tmp_file)
#'
#' # 2. Read the raw data (no processing)
#' raw_data <- read_for(tmp_file, year_base = 2020, process = FALSE)
#' print(raw_data)
#'
#' # 3. Read and process the data (interpolating between 2020, 2025, 2030)
#' # We ask for years 2020 to 2028 to see the interpolation working
#' processed_data <- read_for(
#'   for_filename = tmp_file,
#'   year_base = 2020,
#'   year_fcst = 2020:2028,
#'   process = TRUE
#' )
#' print(processed_data)
#'
#' # 4. Clean up
#' unlink(tmp_file)
#' }
read_for <- function(for_filename,
                     year_base,
                     dep_code = NULL,
                     des_code = NULL,
                     year_fcst = 2025:2050,
                     process = TRUE) {

  # Check if file exists
  if (!file.exists(for_filename)) {
    stop("File not found: ", for_filename)
  }

  # read STATFOR forecast data
  ltf_raw <- fread(
    file = for_filename,
    sep = ";",
    header = TRUE
  )

  # --- Branch: Return Raw Data if processing is not requested ---
  if (!process) {
    # Optional filtering can still be applied to raw data if desired,
    # otherwise simply return the raw file content.
    if (!is.null(dep_code)) ltf_raw <- ltf_raw[toupper(Dep) %in% toupper(dep_code)]
    if (!is.null(des_code)) ltf_raw <- ltf_raw[toupper(Des) %in% toupper(des_code)]
    return(ltf_raw)
  }

  # --- Branch: Advanced Processing ---

  # optional filter on departure
  if (!is.null(dep_code)) {
    ltf_raw <- ltf_raw[toupper(Dep) %in% dep_code]
  }

  # optional filter on arrival
  if (!is.null(des_code)) {
    ltf_raw <- ltf_raw[toupper(Des) %in% des_code]
  }

  # change names for clarity
  setnames(ltf_raw, old = c("Dep", "Des"), new = c("area_dep", "area_des"))

  # find missing years and locate years needed for interpolation
  # (Extract column names that look like integers)
  all_fyears <- names(ltf_raw) %>%
    as.numeric() %>% # Use numeric to catch NAs on non-numeric cols
    `[`(!is.na(.)) %>%
    as.integer()

  miss_fyears <- year_fcst[!year_fcst %in% all_fyears]
  avl_fyears <- year_fcst[year_fcst %in% all_fyears]

  # Logic to determine interpolation bounds (5-year steps assumed based on typical STATFOR)
  lower <- miss_fyears - (miss_fyears %% 5)
  upper <- miss_fyears + (5 - miss_fyears %% 5)
  interp_fyears <- unique(c(lower, upper))
  select_fyears <- unique(c(year_base, avl_fyears, interp_fyears, miss_fyears))

  # add new columns for years that are needed in input but missing
  # Note: we only add them if they don't already exist to avoid errors
  cols_to_add <- as.character(miss_fyears)
  cols_to_add <- cols_to_add[!(cols_to_add %in% names(ltf_raw))]

  if(length(cols_to_add) > 0) {
    ltf_raw[, (cols_to_add) := as.numeric(NA)]
  }

  # convert GF to long format
  ltf <- melt(ltf_raw,
              id.vars = c("RANK", "area_dep", "area_des"),
              measure.vars = patterns("^[0-9]{4}$"), # Safely select only year columns
              variable.name = "fyear",
              value.name = "value")

  ltf[, fyear := as.integer(as.character(fyear)) ]
  ltf <- ltf[fyear >= year_base]

  # select only needed years to optimize for speed
  ltf <- ltf[fyear %in% select_fyears]

  # interpolate GF values
  setorder(ltf, RANK, area_dep, area_des, fyear)
  ltf[, value := zoo::na.approx(value, x = fyear, na.rm = FALSE),
      by = .(area_dep, area_des, RANK)]

  # calculate Growth factor
  # Sort again just to be safe before using 'first'
  setorder(ltf, RANK, area_dep, area_des, fyear)

  ltf[, chg := (value - first(value)) / first(value),
      by = .(RANK, area_dep, area_des)]

  ltf[, gf := fifelse(is.nan(chg) | is.infinite(chg), 1, 1 + chg)]

  # convert dep des region to capital
  ltf[, `:=`(area_dep = toupper(area_dep),
             area_des = toupper(area_des))]

  # keep necessary years
  ltf <- ltf[fyear %in% year_fcst]

  # change ops_year and RANK into new names
  setnames(ltf, old = c("RANK"), new = c("ftype"))

  return(ltf)
}
