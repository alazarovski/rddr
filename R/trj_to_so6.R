#' Convert trajectory points to SO6 segment format and write to file
#'
#' Takes a trajectory table (one row per point) and builds segment-wise SO6 data.
#' Columns in \code{trj_data} can be mapped via \code{cols} so the function
#' doesn’t depend on fixed names.
#'
#' @param trj_data A \code{data.frame} or \code{data.table} of trajectory points.
#'   Must contain the columns referenced in \code{cols}.
#' @param flight_ids \code{NULL} or a vector of IDs to filter on (matches \code{SAM_ID} after mapping).
#' @param output_filename Path to the SO6 file to write. File is written space-delimited, no header.
#' @param cols Named list mapping canonical names used internally to the column
#'   names present in \code{trj_data}. Defaults assume canonical names already exist.
#'   Required keys:
#'   \itemize{
#'     \item \code{SAM_ID}, \code{SEQ_ID}
#'     \item \code{LON}, \code{LAT}, \code{FLIGHT_LEVEL}, \code{TIME_OVER}
#'     \item \code{ADEP}, \code{ADES}, \code{ICAO_TYPE}, \code{CALLSIGN}, \code{AIRCRAFT_OPERATOR}
#'   }
#'
#' @details
#' Steps:
#' \enumerate{
#'   \item Validates and renames \code{trj_data} columns to canonical names via \code{data.table::setnames()} on a copy.
#'   \item Optionally filters by \code{flight_ids}.
#'   \item Builds lead/lag segment endpoints per \code{SAM_ID}.
#'   \item Computes distances and SO6 fields; first/last segments are tagged with \code{ADEP}/\code{ADES}.
#'   \item Writes space-delimited SO6 to \code{output_filename}.
#' }
#'
#' @return Invisibly returns the SO6 \code{data.table}. The primary side effect is writing \code{output_filename}.
#'
#' @examples
#' \dontrun{
#' # Using custom columns
#' so6 <- trj_to_so6(
#'   trj_data = my_trj_df,
#'   flight_ids = c("ID001","ID007"),
#'   output_filename = "out.so6",
#'   cols = list(
#'     SAM_ID = "sam_id_col",
#'     SEQ_ID = "seq",
#'     LON = "lon", LAT = "lat",
#'     FLIGHT_LEVEL = "fl",
#'     TIME_OVER = "time_over_utc",
#'     ADEP = "dep", ADES = "arr",
#'     ICAO_TYPE = "icao",
#'     CALLSIGN = "cs",
#'     AIRCRAFT_OPERATOR = "op"
#'   )
#' )
#' }
#'
#' @seealso \code{\link[data.table]{setnames}}, \code{\link[geosphere]{distHaversine}}
#'
#' @importFrom data.table as.data.table copy setnames shift fwrite ':=' .N
#' @importFrom geosphere distHaversine
#' @importFrom stringi stri_rand_strings
#' @importFrom lubridate days
#' @export


trj_to_so6 <- function(trj_data, flight_ids = NULL, output_filename,
                       cols = list(
                         SAM_ID            = "SAM_ID",
                         SEQ_ID            = "SEQ_ID",
                         LON               = "LON",
                         LAT               = "LAT",
                         FLIGHT_LEVEL      = "FLIGHT_LEVEL",
                         TIME_OVER         = "TIME_OVER",
                         ADEP              = "ADEP",
                         ADES              = "ADES",
                         ICAO_TYPE         = "ICAO_TYPE",
                         CALLSIGN          = "CALLSIGN",
                         AIRCRAFT_OPERATOR = "AIRCRAFT_OPERATOR"
                       )) {

  # work on a copy
  dt <- data.table::as.data.table(data.table::copy(trj_data))

  # validate & rename to canonical names (only if different)
  need <- unlist(cols, use.names = TRUE)      # user-provided names
  miss <- setdiff(need, names(dt))
  if (length(miss)) {
    stop("trj_to_so6(): missing required columns in trj_data: ",
         paste(miss, collapse = ", "))
  }
  old <- unlist(cols, use.names = FALSE)
  new <- names(cols)
  idx <- old != new
  if (any(idx)) data.table::setnames(dt, old[idx], new[idx])

  # filter by flight_ids if provided
  if (!is.null(flight_ids)) {
    dt <- dt[SAM_ID %in% flight_ids]
  }

  # create segment identifier
  n <- nrow(dt)
  seg_id_vector <- paste0(
    "!",
    do.call(paste0,
            as.data.table(
              replicate(4, sample(LETTERS, n, TRUE), simplify = FALSE)
            ))
  )

  trj_seg <- data.table::copy(dt)
  trj_seg[
    , seg_uid := seg_id_vector
  ]

  # create segment columns
  cols_to_shift <- c("seg_uid", "LON", "LAT", "FLIGHT_LEVEL", "TIME_OVER")
  trj_seg[, c("seg_uid_lead", "lon2", "lat2", "fl2", "time2") :=
            data.table::shift(.SD, type = "lead"),
          by = SAM_ID,
          .SDcols = cols_to_shift]
  trj_seg[, `:=`(
    id   = SAM_ID,
    seq_id = SEQ_ID,
    lon1 = LON,
    lat1 = LAT,
    fl1  = FLIGHT_LEVEL,
    time1 = TIME_OVER
  )]

  # drop last point per flight (no lead)
  trj_seg <- trj_seg[!is.na(lon2)]

  deg2rad <- pi/180
  R <- 6371.0088  # Earth radius in km
  offset_secs <- 924L * 86400L

  # precompute latitude in radians to save processing time -> segment distance
  trj_seg[, `:=`(
    lat1r = lat1 * deg2rad,
    lat2r = lat2 * deg2rad
  )][, `:=`(
    segment_2d_distance = acos(
      pmin(pmax(sin(lat1r) * sin(lat2r) +
                  cos(lat1r) * cos(lat2r) *
                  cos((lon2 - lon1) * deg2rad), -1), 1)
    ) * R / 1.852
  ), by = SAM_ID][
    , `:=`(
      # time_begin  = format(time1, "%H%M%S"),
      # time_end    = format(time2, "%H%M%S"),
      # date_begin  = format(time1 + lubridate::days(924), "%y%m%d"),
      # date_end    = format(time2 + lubridate::days(924), "%y%m%d"),

      time_begin = strftime(time1, "%H%M%S"),
      time_end   = strftime(time2, "%H%M%S"),
      date_begin = strftime(time1, "%y%m%d"),
      date_end   = strftime(time2, "%y%m%d"),

      lon_b_mm    = lon1 * 60,
      lat_b_mm    = lat1 * 60,
      lon_e_mm    = lon2 * 60,
      lat_e_mm    = lat2 * 60,
      segment_parity = 0,
      flight_phase = 2L
    ) ][
      fl1 > fl2,
      flight_phase := 1L ][
        fl2 > fl1,
        flight_phase := 0L
      ]

  # segment id: first ADEP->seg,
  # last seg->ADES, middle seg->seg
  trj_seg[, seg_id := paste0(seg_uid, "_", seg_uid_lead)]
  fl_idx <- trj_seg[, .(first = .I[1L], last = .I[.N]), by = SAM_ID]
  trj_seg[fl_idx$first, seg_id := paste0(ADEP, "_", seg_uid_lead)]
  trj_seg[fl_idx$last,  seg_id := paste0(seg_uid, "_", ADES)]

  # final selection
  so6 <- trj_seg[, .(
    seg_id,
    ADEP,
    ADES,
    ICAO_TYPE,
    time_begin,
    time_end,
    fl1,
    fl2,
    flight_phase,
    CALLSIGN,
    date_begin,
    date_end,
    lat_b_mm,
    lon_b_mm,
    lat_e_mm,
    lon_e_mm,
    SAM_ID,
    SEQ_ID,
    segment_2d_distance,
    segment_parity
  )]

  data.table::fwrite(
    so6,
    file = output_filename,
    sep = " ",
    col.names = FALSE
  )
  invisible(so6)
}
