.paths <- function(paths, multiple = FALSE) {
  if (!is.character(paths) || !length(paths) || anyNA(paths) ||
      any(!nzchar(paths)) || (!multiple && length(paths) != 1L)) {
    stop("Provide ", if (multiple) "one or more file paths." else "one file path.",
         call. = FALSE)
  }
  enc2utf8(normalizePath(path.expand(paths), winslash = "/", mustWork = TRUE))
}

.native <- function(symbol, ...) {
  result <- .Call(symbol, ...)
  if (inherits(result, "extendr_error")) stop(result$value, call. = FALSE)
  result
}

.progress <- function(progress) {
  if (!is.logical(progress) || length(progress) != 1L || is.na(progress)) {
    stop("progress must be TRUE or FALSE.", call. = FALSE)
  }
}

.progress_message <- function(...) {
  cat("[rddr] ", ..., "\n", sep = "")
  utils::flush.console()
}

#' Prepare Airspaces for Repeated Intersections
#'
#' @param are_file,sls_file,spc_file Paths to matching ARE, SLS and SPC files.
#' @param airspace_type One of AREA, NAS, AUA, AUAG, REG, CRAS, CLUS, CS, CRSA,
#'   or ES. Defaults to AUAG.
#' @param airspace_ids Character vector of IDs to select, or NULL for all IDs
#'   of the selected type. No geographical ID filter is applied implicitly.
#' @param progress If TRUE, print start and completion messages. Default FALSE.
#' @return An external-pointer object with airspace_ids, airspace_type, and
#'   block_count attributes. Recreate it in each R session; do not save it to RDS
#'   or send it to another R process.
#' @useDynLib rddr, .registration = TRUE
#' @export
init_airspaces <- function(are_file, sls_file, spc_file,
                          airspace_type = "AUAG", airspace_ids = NULL,
                          progress = FALSE) {
  .progress(progress)
  if (!is.character(airspace_type) || length(airspace_type) != 1L ||
      is.na(airspace_type)) {
    stop("airspace_type must be one character string.", call. = FALSE)
  }
  if (!is.null(airspace_ids) &&
      (!is.character(airspace_ids) || !length(airspace_ids) ||
       anyNA(airspace_ids) || any(!nzchar(airspace_ids)))) {
    stop("airspace_ids must be NULL or a nonempty character vector of IDs.",
         call. = FALSE)
  }
  if (progress) .progress_message("Reading airspace files and preparing the spatial index.")
  result <- .native(wrap__airspaces_init, .paths(are_file), .paths(sls_file),
                    .paths(spc_file), airspace_type, airspace_ids)
  if (progress) .progress_message("Airspaces ready: ", length(attr(result, "airspace_ids")),
                                  " airspaces, ", attr(result, "block_count"), " blocks.")
  result
}

#' Read and Validate Flight Trajectories
#'
#' @param paths One or more CSV file paths. Required columns are id, lon, lat,
#'   altitude (feet), and time_over (ISO 8601 or Unix seconds).
#' @param progress If TRUE, print start and completion messages. Default FALSE.
#' @return A data frame sorted by id and time_over, containing the five required
#'   columns. time_over is POSIXct in UTC. Additional CSV columns are ignored.
#' @export
read_trajectories <- function(paths, progress = FALSE) {
  .progress(progress)
  if (progress) .progress_message("Reading and validating trajectory CSV files.")
  result <- as.data.frame(.native(wrap__trajectories_read, .paths(paths, TRUE)),
                          stringsAsFactors = FALSE)
  result$time_over <- .POSIXct(result$time_over, tz = "UTC")
  if (progress) .progress_message("Trajectories ready: ", nrow(result), " points.")
  result
}

#' Compute Continuous Airspace Visits
#'
#' @param airspaces An object returned by init_airspaces in this R session.
#' @param flights A data frame with character id, numeric lon, lat and altitude
#'   in feet, and time_over as POSIXct, Unix seconds, or ISO 8601 strings.
#' @param progress If TRUE, print processing stages and segment progress.
#'   Default FALSE. Percentages cover segment processing only, not validation,
#'   sorting or conversion of the results.
#' @return A data frame with one row per flight, airspace and continuous visit.
#'   Includes id, airspace_id, visit_id, entry/exit longitude and latitude,
#'   entry_altitude_ft, exit_altitude_ft, UTC POSIXct entry_time and exit_time,
#'   starts_inside and ends_inside. These flags indicate that recording starts
#'   or ends in the airspace, including its boundary; such endpoints are not
#'   necessarily observed boundary crossings. No intersections returns a
#'   zero-row frame with the same columns and types.
#' @details Boundaries are included for positive-duration travel; isolated
#'   touches are excluded. Coordinates, altitude and time are linearly
#'   interpolated between observations. Separate visits remain separate;
#'   overlapping blocks of the same airspace are merged. Distinct overlapping
#'   airspaces have separate profiles. Longitude is interpolated along the
#'   shorter route across the antimeridian. Segments with exactly 180 degrees
#'   of longitude difference are ambiguous and rejected. Polar or globe-winding
#'   polygons are not supported.
#' @examples
#' directory <- system.file("extdata", package = "rddr")
#' airspaces <- init_airspaces(file.path(directory, "example.are"),
#'                            file.path(directory, "example.sls"),
#'                            file.path(directory, "example.spc"))
#' flights <- read_trajectories(file.path(directory, "flights.csv"))
#' intersect_trajectories(airspaces, flights)
#' @export
intersect_trajectories <- function(airspaces, flights, progress = FALSE) {
  .progress(progress)
  if (progress) .progress_message("Validating and preparing R input.")
  required <- c("id", "lon", "lat", "altitude", "time_over")
  if (!is.data.frame(flights) || anyDuplicated(names(flights)) ||
      !all(required %in% names(flights))) {
    stop("flights must be a data frame with id, lon, lat, altitude and time_over.",
         call. = FALSE)
  }
  flights <- as.data.frame(flights)[required]
  if (anyNA(flights) || !is.character(flights$id)) {
    stop("flights must have character IDs and no missing required values.",
         call. = FALSE)
  }
  for (name in c("lon", "lat", "altitude")) {
    if (!is.numeric(flights[[name]])) {
      stop(name, " must be numeric.", call. = FALSE)
    }
    flights[[name]] <- as.double(flights[[name]])
  }
  if (inherits(flights$time_over, "POSIXt") ||
      (is.numeric(flights$time_over) && !inherits(flights$time_over, "Date"))) {
    flights$time_over <- as.double(flights$time_over)
  } else if (!is.character(flights$time_over)) {
    stop("time_over must contain timestamps, not dates or factors.", call. = FALSE)
  }
  result <- as.data.frame(.native(wrap__trajectories_intersect, airspaces, flights, progress),
                          stringsAsFactors = FALSE)
  result$entry_time <- .POSIXct(result$entry_time, tz = "UTC")
  result$exit_time <- .POSIXct(result$exit_time, tz = "UTC")
  if (progress) .progress_message("Done: ", nrow(result), " profiles.")
  result
}
