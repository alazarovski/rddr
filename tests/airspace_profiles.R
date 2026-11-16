library(rddr)

fixture <- function(name) system.file("extdata", name, package = "rddr")
stopifnot(nrow(read_sls(fixture("sectors.sls"))) == 2L,
          nrow(read_are(fixture("sectors.are"))) == 8L)
prepare <- function(type = "AUAG", ids = NULL, spc = fixture("example.spc"),
                    sls = fixture("example.sls"), are = fixture("example.are")) {
  init_airspaces(are, sls, spc, type, ids)
}
expect_error <- function(expression, pattern) {
  error <- tryCatch(force(expression), error = identity)
  stopifnot(inherits(error, "error"), grepl(pattern, conditionMessage(error)))
}
near <- function(actual, expected, tolerance = 1e-8) {
  if (is.numeric(expected) || inherits(expected, "POSIXt")) {
    stopifnot(length(actual) == length(expected), !anyNA(actual),
              all(abs(as.double(actual) - as.double(expected)) <= tolerance))
  } else {
    stopifnot(identical(actual, expected))
  }
}

airspaces <- prepare()
flights <- read_trajectories(fixture("flights.csv"))
profiles <- intersect_trajectories(airspaces, flights)
expected <- read.csv(fixture("expected-profiles.csv"), stringsAsFactors = FALSE)
for (column in c("entry_time", "exit_time")) {
  expected[[column]] <- as.POSIXct(expected[[column]], format = "%Y-%m-%dT%H:%M:%SZ",
                                  tz = "UTC")
}
stopifnot(identical(names(profiles), names(expected)), nrow(profiles) == 2L,
          inherits(flights$time_over, "POSIXct"),
          identical(attr(profiles$entry_time, "tzone"), "UTC"),
          identical(attr(airspaces, "airspace_ids"), "GROUP"),
          attr(airspaces, "block_count") == 4)
for (column in names(expected)) near(profiles[[column]], expected[[column]])

left <- prepare("NAS")
single <- intersect_trajectories(left, flights)
stopifnot(nrow(single) == 1L, single$airspace_id == "LEFT")
near(as.double(single$entry_time) - as.double(flights$time_over[1]), 10)
near(as.double(single$exit_time) - as.double(flights$time_over[1]), 30)
stopifnot(identical(profiles, intersect_trajectories(airspaces, flights)))

quiet <- capture.output(quiet_profiles <- intersect_trajectories(airspaces, flights))
verbose <- capture.output(verbose_profiles <- intersect_trajectories(airspaces, flights,
                                                                      progress = TRUE))
stopifnot(length(quiet) == 0L, identical(quiet_profiles, verbose_profiles),
          any(grepl("Validating and preparing R input", verbose, fixed = TRUE)),
          any(grepl("Validating and sorting trajectory", verbose, fixed = TRUE)),
          any(grepl("Segments: 1/1 (100.0%)", verbose, fixed = TRUE)),
          sum(grepl("Segments:", verbose, fixed = TRUE)) == 1L,
          any(grepl("Segment processing complete; sorting", verbose, fixed = TRUE)),
          any(grepl("Done: 2 profiles", verbose, fixed = TRUE)))
init_output <- capture.output(verbose_airspaces <- init_airspaces(
  fixture("example.are"), fixture("example.sls"), fixture("example.spc"),
  progress = TRUE))
read_output <- capture.output(verbose_flights <- read_trajectories(fixture("flights.csv"),
                                                                   progress = TRUE))
stopifnot(any(grepl("Airspaces ready: 1 airspaces, 4 blocks", init_output, fixed = TRUE)),
          any(grepl("Trajectories ready: 2 points", read_output, fixed = TRUE)),
          identical(flights, verbose_flights),
          identical(profiles, intersect_trajectories(verbose_airspaces, flights)))
for (value in list(NA, 1, "TRUE", logical(), c(TRUE, FALSE))) {
  expect_error(intersect_trajectories(airspaces, flights, progress = value), "progress")
  expect_error(init_airspaces(fixture("example.are"), fixture("example.sls"),
                              fixture("example.spc"), progress = value), "progress")
  expect_error(read_trajectories(fixture("flights.csv"), progress = value), "progress")
}

other <- flights
other$id <- "SECOND"
interleaved <- rbind(other[2, ], flights[1, ], other[1, ], flights[2, ])
multiple <- intersect_trajectories(airspaces, interleaved)
stopifnot(nrow(multiple) == 4L,
          identical(multiple$id, c("EXAMPLE", "EXAMPLE", "SECOND", "SECOND")))
multiple_output <- capture.output(multiple_verbose <- intersect_trajectories(
  airspaces, interleaved, progress = TRUE))
stopifnot(identical(multiple, multiple_verbose),
          any(grepl("Segments: 1/2 (50.0%)", multiple_output, fixed = TRUE)),
          any(grepl("Segments: 2/2 (100.0%); completed flights: 1",
                    multiple_output, fixed = TRUE)))

character_times <- flights
character_times$time_over <- c("2025-01-01T02:00:00+02:00",
                              "2025-01-01T02:01:40+02:00")
stopifnot(identical(profiles, intersect_trajectories(airspaces, character_times)))
numeric_times <- flights
numeric_times$time_over <- as.double(flights$time_over)
stopifnot(identical(profiles, intersect_trajectories(airspaces, numeric_times)))

outside <- flights
outside$lat <- 10
empty <- intersect_trajectories(airspaces, outside)
stopifnot(nrow(empty) == 0L, identical(names(empty), names(profiles)),
          identical(vapply(empty, typeof, ""), vapply(profiles, typeof, "")),
          inherits(empty$entry_time, "POSIXct"))
empty_output <- capture.output(empty_verbose <- intersect_trajectories(airspaces, outside,
                                                                        progress = TRUE))
stopifnot(identical(empty, empty_verbose),
          any(grepl("Segments: 1/1 (100.0%)", empty_output, fixed = TRUE)),
          any(grepl("Done: 0 profiles", empty_output, fixed = TRUE)))
long <- outside[rep(1, 202), ]
long$time_over <- seq_len(nrow(long))
long_output <- capture.output(long_result <- intersect_trajectories(airspaces, long,
                                                                     progress = TRUE))
segment_output <- grep("Segments:", long_output, value = TRUE, fixed = TRUE)
segment_counts <- as.integer(sub(".*Segments: ([0-9]+)/.*", "\\1", segment_output))
stopifnot(nrow(long_result) == 0L, length(segment_output) > 1L,
          length(segment_output) <= 100L,
          all(diff(segment_counts) > 0L), all(segment_counts <= 201L),
          grepl("Segments: 201/201 (100.0%)", tail(segment_output, 1), fixed = TRUE))

climb <- flights
climb$lon <- 1
climb$altitude <- c(0, 30000)
vertical <- intersect_trajectories(left, climb)
stopifnot(nrow(vertical) == 1L)
near(vertical$entry_altitude_ft, 10000)
near(vertical$exit_altitude_ft, 20000)

expect_error(intersect_trajectories(NULL, flights), "invalid airspaces")
foreign <- new("externalptr")
class(foreign) <- "rddr_airspaces"
expect_error(intersect_trajectories(foreign, flights), "invalid airspaces")
restored <- unserialize(serialize(airspaces, NULL))
expect_error(intersect_trajectories(restored, flights), "no longer valid")
expect_error(intersect_trajectories(airspaces, flights[c(1, 1), ]), "duplicate")
expect_error(intersect_trajectories(airspaces, flights[1, ]), "at least two")
invalid <- flights
invalid$lon[1] <- NA_real_
expect_error(intersect_trajectories(airspaces, invalid), "missing")
invalid$lon[1] <- Inf
expect_error(intersect_trajectories(airspaces, invalid), "invalid trajectory")
invalid$lon[1] <- 200
expect_error(intersect_trajectories(airspaces, invalid), "invalid trajectory")
invalid <- flights
invalid$time_over <- c("not-a-time", "2025-01-01T00:01:00Z")
expect_error(intersect_trajectories(airspaces, invalid), "invalid timestamp")
expect_error(prepare("NAS", "MISSING"), "MISSING")
expect_error(prepare("BOGUS"), "unsupported")
expect_error(prepare("NAS", character()), "nonempty")

local({
  directory <- tempfile("airspaceprofile tests-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  csv <- file.path(directory, "flights.csv")
  invalid <- flights
  invalid$lat[1] <- NA_real_
  write.csv(invalid, csv, row.names = FALSE)
  expect_error(read_trajectories(csv), "row 2.*invalid lat")
  writeLines(c("id,lon,lat,altitude,time_over",
               "F,0,1,10000,bad", "F,1,1,10000,1"), csv)
  expect_error(read_trajectories(csv), "invalid timestamp")
  writeLines(c("id,lon,lat,altitude", "F,0,1,10000"), csv)
  expect_error(read_trajectories(csv), "time_over")
  writeLines(c("id,lon,lon,lat,altitude,time_over", "F,0,0,1,10000,0"), csv)
  expect_error(read_trajectories(csv), "exactly one 'lon'")
  second <- file.path(directory, "second.csv")
  other$time_over <- format(other$time_over, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  write.csv(other, second, row.names = FALSE)
  combined <- read_trajectories(c(fixture("flights.csv"), second))
  stopifnot(nrow(combined) == 4L)

  spc <- file.path(directory, "bad.spc")
  text <- readLines(fixture("example.spc"))
  writeLines(sub("S;UNIT;AUA", "S;MISSING;AUA", text, fixed = TRUE), spc)
  expect_error(prepare(spc = spc), "missing AUA.*MISSING")
  writeLines(sub("S;UNIT;AUA", "S;GROUP;AUAG", text, fixed = TRUE), spc)
  expect_error(prepare(spc = spc), "cyclic")
  sls <- file.path(directory, "bad.sls")
  writeLines(sub("B1", "MISSING", readLines(fixture("example.sls")), fixed = TRUE), sls)
  expect_error(prepare("NAS", sls = sls), "missing ARE polygon")
  are <- file.path(directory, "bad.are")
  text <- readLines(fixture("example.are"))
  text[1] <- sub("^4 ", "5 ", text[1])
  writeLines(text, are)
  expect_error(prepare(are = are), "declares 5 vertices")

  writeLines(c("4 -60 10740 0 0 0 0 0 0 0 0 0 0 0 DATE",
               "-60 10740", "-60 -10740", "60 -10740", "60 10740"), are)
  writeLines("SECTOR + DATE 100 200", sls)
  writeLines(c("2", "A;WRAP;Antimeridian;NAS;1", "S;SECTOR;FIR"), spc)
  wrap <- prepare("NAS", are = are, sls = sls, spc = spc)
  crossing <- data.frame(id = "F", lon = c(178, -178), lat = 0,
                         altitude = 15000, time_over = c(0, 40))
  result <- intersect_trajectories(wrap, crossing)
  stopifnot(nrow(result) == 1L, result$airspace_id == "WRAP")
  near(result$entry_lon, 179)
  near(result$exit_lon, -179)
  near(as.double(result$entry_time), 10)
  near(as.double(result$exit_time), 30)
  crossing$lon <- rev(crossing$lon)
  result <- intersect_trajectories(wrap, crossing)
  near(result$entry_lon, -179)
  near(result$exit_lon, 179)
  crossing$lon <- c(0, 180)
  expect_error(intersect_trajectories(wrap, crossing), "ambiguous")
})

cat("R profiles: fixture parity, pointer lifecycle, multi-flight inputs and validation passed.\n")
