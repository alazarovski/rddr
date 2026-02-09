library(data.table)

#' Calculate Flight Level Crossing Points
#'
#' @description
#' Finds the exact moment a flight crosses a specific altitude.
#' Uses linear interpolation between the points above and below the target.
#'
#' @param data A dataframe or data.table containing the flight trajectory.
#' @param target_fl Numeric. The target altitude (e.g., 30).
#' @param keep_only_first_last Boolean. If TRUE (default), keeps only the first climb and last descent. If FALSE, keeps all crossings.
#' @param col_id String. Name of ID column (default: "SAM_ID").
#' @param col_time String. Name of time column (default: "TIME_OVER").
#' @param col_lon String. Name of longitude column (default: "LON").
#' @param col_lat String. Name of latitude column (default: "LAT").
#' @param col_fl String. Name of altitude column (default: "FLIGHT_LEVEL").
#'
#' @return A `data.table` with interpolated crossing points.

#'
#' # 1. Create a dummy flight profile (Climb -> Cruise -> Descent)
#' # This flight starts at FL10, climbs to FL40, cruises, then descends back to FL10.
#' my_flight_data <- data.table(
#'   SAM_ID = "FLIGHT_001",
#'   TIME_OVER = 1:6,
#'   LON = c(10, 11, 12, 13, 14, 15),
#'   LAT = c(50, 50, 50, 50, 50, 50),
#'   FLIGHT_LEVEL = c(10, 20, 40, 40, 20, 10) # Crosses FL30 during climb and descent
#' )
#'
#' # 2. Find where the flight crosses FL 30
#' # It should find two points: one between FL20-FL40 (climb) and one between FL40-FL20 (descent)
#' crossings <- get_crossing_segments(
#'   data = my_flight_data,
#'   target_fl = 30,
#'   col_id = "SAM_ID",
#'   col_fl = "FLIGHT_LEVEL"
#' )
#'
#' print(crossings)

get_crossing_segments <- function(data, target_fl,
                                  keep_only_first_last = TRUE,
                                  col_id = "SAM_ID",
                                  col_time = "TIME_OVER",
                                  col_lon = "LON",
                                  col_lat = "LAT",
                                  col_fl = "FLIGHT_LEVEL") {

  # 1. Setup: Convert to data.table and copy to avoid modifying original
  dt <- as.data.table(data)

  # Map user columns to standard internal names for calculation
  # We use 'setnames' on a copy so we don't break the original object
  dt_calc <- copy(dt)
  setnames(dt_calc, old = c(col_id, col_time, col_lon, col_lat, col_fl),
           new = c("id", "time", "lon", "lat", "fl"), skip_absent = TRUE)

  dt_calc[, fl := as.numeric(fl)]

  # 2. Shift columns to create segments
  dt_calc[, `:=`(
    time_next = shift(time, type = "lead"),
    lon_next  = shift(lon, type = "lead"),
    lat_next  = shift(lat, type = "lead"),
    fl_next   = shift(fl, type = "lead"),
    id_next   = shift(id, type = "lead")
  )]

  # 3. Filter: Keep only crossing segments
  # (One point is below/equal, the other is above/equal)
  crossing_dt <- dt_calc[id == id_next &
                           ((fl <= target_fl & fl_next >= target_fl) |
                              (fl >= target_fl & fl_next <= target_fl))]

  # 4. Interpolate
  lin_interp <- function(x_target, x1, x2, y1, y2) {
    y1 + (y2 - y1) * (x_target - x1) / (x2 - x1)
  }

  crossing_dt[, `:=`(
    interp_time = lin_interp(target_fl, fl, fl_next, time, time_next),
    interp_lon  = lin_interp(target_fl, fl, fl_next, lon, lon_next),
    interp_lat  = lin_interp(target_fl, fl, fl_next, lat, lat_next),
    interp_fl   = target_fl,
    flight_mode = fifelse(fl < fl_next, "climb",
                          fifelse(fl > fl_next, "descent", "levelled"))
  )]

  # 5. Select only the necessary columns + Mode
  # We select the INTERPOLATED values, not the original ones
  final_cols <- c("id", "interp_time", "interp_lon", "interp_lat", "interp_fl", "flight_mode")

  setorder(crossing_dt, id, interp_time)

  # Filter first/last if requested
  if (keep_only_first_last) {
    result <- crossing_dt[, if (.N > 1) .SD[c(1, .N)] else .SD[1],
                          by = id,
                          .SDcols = final_cols]
  } else {
    result <- crossing_dt[, .SD, .SDcols = final_cols]
  }

  # 6. Final Step: Rename columns back to User Inputs
  # This makes the output table look exactly like the input table structure
  setnames(result,
           old = c("id", "interp_time", "interp_lon", "interp_lat", "interp_fl"),
           new = c(col_id, col_time, col_lon, col_lat, col_fl))

  return(result)
}
