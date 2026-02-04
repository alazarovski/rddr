#' Read EXP2 Traffic Demand Files
#'
#' @description
#' Reads a SAAM/NEST EXP2 traffic demand file into a formatted data.table.
#' The function handles the 94-field semicolon-separated structure, including
#' the specialized blocks for EXP, FLF, and ALLFT data.
#'
#' @param exp2_file Character. The path to the .exp2 file.
#' @return A data.table containing the flight data with standardized column names.
#' @export
#' @importFrom data.table fread setnames
#'
#' @examples
#' \dontrun{
#' # Reading a file
#' flight_data <- read_exp2("inst/extdata/traffic.exp2")
#' }
read_exp2 <- function(exp2_file) {

  # Define the 94 column names based on the EXP2 specification
  # This ensures the "bulletproof" mapping of indices
  exp2_colnames <- c(
    # EXP Block (1-13)
    "adep", "ades", "not_used_1", "actype", "rfl", "zone_origin",
    "zone_destin", "flight_id", "date_dep", "time_dep", "time_arr",
    "callsign", "company",
    "sep_1", # 14
    # UUID Block (15-16)
    "uuid", "fips_cloned",
    "sep_2", # 17
    # FLF Block (18-38)
    "fl_saam_id", "fl_samad_id", "tact_id", "ssr_code", "registration",
    "p_date_dep", "p_time_dep", "atfm_delay", "rerouting_state",
    "most_pen_reg", "fl_type", "nav_com_equip", "pbn_cap", "com_equip",
    "surv_equip", "ssr_equip", "survival_equip", "pob", "top_fl",
    "max_rfl", "flt_pln_source",
    "sep_3", # 39
    # ALLFT Block (40-94)
    "aobt", "ifpsId", "iobt", "originalFlightDataQuality", "flightDataQuality",
    "source", "exemptionReasonType", "exemptionReasonDistance", "lateFiler",
    "lateUpdater", "northAtlanticFlight", "cobt", "eobt", "flightState",
    "previousToActivationFlightState", "suspensionStatus", "tactId_allft",
    "samCtot", "samSent", "sipCtot", "sipSent", "slotForced",
    "mostPenalizingRegulationId", "regulationsAffectedByNrOfInstances",
    "excludedFromNrOfInstances", "lastReceivedAtfmMessageTitle",
    "lastReceivedMessageTitle", "lastSentAtfmMessageTitle",
    "manualExemptionReason", "sensitiveFlight", "readyForImprovement",
    "readyToDepart", "revisedTaxiTime", "tis", "trs",
    "toBeSentSlotMessageTitle", "toBeSentProposalMessageTitle",
    "lastSentSlotMessageTitle", "lastSentProposalMessageTitle",
    "lastSentSlotMessage", "lastSentProposalMessage", "flightCountOption",
    "normalFlightTactId", "proposalFlightTactId", "operatingAircraftOperatorIcaoId",
    "reroutingWhy", "reroutedFlightState", "runwayVisualRange",
    "ftfmAiracCycleReleaseNumber", "ftfmEnvBaselineNumber",
    "rtfmAiracCycleReleaseNumber", "rtfmEnvBaselineNumber",
    "ctfmAiracCycleReleaseNumber", "ctfmEnvBaselineNumber",
    "lastReceivedProgressMessage",
    "sep_4" # 95 (Technical separator often used for trailing semi-colon)
  )

  # Read the file
  # Use colClasses = "character" for specific fields like 'ssr_code' or 'time'
  # to preserve leading zeros.
  dt <- data.table::fread(
    file = exp2_file,
    sep = ";",
    header = FALSE,
    col.names = exp2_colnames,
    fill = TRUE,            # Handles lines that might miss trailing separators
    strip.white = TRUE,     # Removes whitespace from character fields
    na.strings = c("", "!!!!", "NA"),
    colClasses = c(
      date_dep = "character",
      time_dep = "character",
      aobt = "character",
      eobt = "character",
      ssr_code = "character"
    )
  )

  # Remove the internal SAAM separators (Fields 14, 17, 39, 95)
  cols_to_remove <- grep("^sep_", names(dt), value = TRUE)
  if (length(cols_to_remove) > 0) {
    dt[, (cols_to_remove) := NULL]
  }

  return(dt[])
}

