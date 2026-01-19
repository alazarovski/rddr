#' Read SAAM Airport SID Points File
#'
#' Reads and parses a `.sid` file containing a list of airport Standard Instrument Departure (SID) points.
#' The file format is expected to be whitespace-separated, where the first column is the 4-character
#' ICAO airport code and subsequent columns are navigation point names.
#'
#' @param sid_file_name A single character string specifying the path to the `.sid` file.
#'
#' @return A \code{\link[data.table]{data.table}} with two columns:
#' \describe{
#'   \item{icao_apt}{Character. The ICAO airport code (e.g., "SAAM").}
#'   \item{sid}{Character. The SID navigation point name.}
#' }
#' If the file is empty or contains no valid data, an empty data.table is returned.
#'
#' @details
#' The function relies on \code{data.table::fread} for high-performance reading and 
#' \code{stringi} for efficient text processing. It handles:
#' \itemize{
#'   \item Blank lines and whitespace trimming automatically.
#'   \item Files with no SIDs (returns empty table).
#'   \item Lines containing only an ICAO code (ignored, as there are no SIDs to list).
#' }
#'
#' @importFrom data.table fread data.table
#' @importFrom stringi stri_split_regex stri_trim_both
#'
#' @examples
#' \dontrun{
#' # Assuming 'airports.sid' exists in your working directory
#' dt <- read_sid("airports.sid")
#' print(dt)
#' }
#'
#' @export
read_sid <- function(sid_file_name) {
  # --- 1. Input Validation ---
  if (missing(sid_file_name) || !is.character(sid_file_name) || length(sid_file_name) != 1) {
    stop("Argument 'sid_file_name' must be a single file path character string.")
  }
  
  if (!file.exists(sid_file_name)) {
    stop(sprintf("File not found: '%s'", sid_file_name))
  }
  
  # Check for required packages (useful if not installed via package dependencies)
  if (!requireNamespace("data.table", quietly = TRUE)) stop("Package 'data.table' is required.")
  if (!requireNamespace("stringi", quietly = TRUE)) stop("Package 'stringi' is required.")
  
  # --- 2. Safe File Reading ---
  # fread is used for speed. We catch errors to provide a clean message.
  lines_dt <- tryCatch({
    data.table::fread(
      sid_file_name, 
      sep = "\n", 
      header = FALSE, 
      col.names = "line",
      encoding = "UTF-8", 
      showProgress = FALSE,
      blank.lines.skip = TRUE # Automatically skip empty lines
    )
  }, error = function(e) {
    stop("Failed to read file: ", e$message)
  })
  
  # Handle completely empty files
  if (nrow(lines_dt) == 0) {
    return(data.table::data.table(icao_apt = character(0), sid = character(0)))
  }
  
  # --- 3. Tokenization & Cleaning ---
  # Trim whitespace and split tokens
  # omit_empty = TRUE prevents empty strings from appearing in the list
  tokens <- stringi::stri_split_regex(
    stringi::stri_trim_both(lines_dt[["line"]]), 
    "\\s+", 
    omit_empty = TRUE
  )
  
  # Filter out any lines that resulted in 0 tokens (e.g., lines that were only whitespace)
  has_data <- vapply(tokens, length, integer(1)) > 0
  tokens <- tokens[has_data]
  
  # If no valid data remains after filtering
  if (length(tokens) == 0) {
    return(data.table::data.table(icao_apt = character(0), sid = character(0)))
  }
  
  # --- 4. Data Extraction ---
  # Extract first token as ICAO
  icao <- vapply(tokens, `[`, character(1), 1L)
  
  # Extract remaining tokens as SIDs. 
  # If a line has only 1 token (only ICAO), it returns character(0)
  sid_ls <- lapply(tokens, function(x) {
    if (length(x) > 1) x[-1L] else character(0)
  })
  
  # --- 5. Flatten to Long Format ---
  # 'rep' repeats the ICAO code for the number of SIDs found on that line
  DT <- data.table::data.table(
    icao_apt = rep(icao, lengths(sid_ls)),
    sid      = unlist(sid_ls, use.names = FALSE)
  )
  
  return(DT[])
}