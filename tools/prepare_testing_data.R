# Create the directory if it doesn't exist
dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)

# Script to generate sample data for rddr vignette
# Run this once to create the files

# 1. Setup Directory
output_dir <- "inst/extdata" # Suggested: "inst/extdata" for package structure
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# Helper function to write files
write_sample <- function(filename, content) {
  path <- file.path(output_dir, filename)
  writeLines(content, path)
  message("Created: ", path)
}

# --- 1. NETWORK FILES ---

# .arp (Airports)
# Format: ICAO Lat(min) Lon(min) FIR
write_sample("network.arp", c(
  "LFPG 2940 152 LFFF_FIR",   # Paris CDG
  "EBBR 3054 269 EBBU_FIR",   # Brussels
  "EGLL 3086 -27 EGTT_FIR"    # London Heathrow
))

# .narp (Advanced Airport Metadata)
# Format: Metadata line, then ICAO;Name;Lat;Lon;TIS;TRS;Taxi;Alt
write_sample("network.narp", c(
  "#Version;Date",
  "LFPG;PARIS CDG;49.00;2.54;10;5;15;390",
  "EBBR;BRUSSELS;50.90;4.48;8;8;10;200",
  "EGLL;LONDON HEATHROW;51.47;-0.45;_;_;20;_" # _ indicates missing
))

# .nnpt (Navigation Points)
# Format: Count, then ID;Type;Lat;Lon;Name
write_sample("points.nnpt", c(
  "3",
  "DIBER;WZ;50.0;1.5;DIBER_POINT",
  "KOK;VOR;51.0;2.5;KOKSY",
  "BUB;VOR;50.8;4.3;BRUSSELS_VOR"
))

# .sid (SIDs)
# Format: ICAO Point1 Point2 ...
write_sample("airports.sid", c(
  "LFPG DIBER KOK",
  "EBBR BUB KOK"
))

# .runway (Runway Configurations)
# Format: Metadata, Date;ICAO;QFU;Start;End;Default;Taxi;TIS;TRS;Origin
write_sample("airport.runway", c(
  "#Version 1.0",
  "01/06/2024;LFPG;26R;0000;2359;Y;15;10;5;E",
  "01/06/2024;EBBR;25R;0600;2200;Y;10;8;8;E"
))

# --- 2. AIRSPACE & GEOMETRY ---

# .soa (Areas/Groups)
# Format: AreaName Member1 Member2...
write_sample("groups.soa", c(
  "PARIS_METRO LFPG LFPB",
  "BELGIUM_GROUP EBBR EBCI",
  "WEST_EUROPE PARIS_METRO BELGIUM_GROUP EGLL" # Recursive group
))

# .are (Geometry/Volumes)
# Format: Header (15 cols) with VolName at end, followed by Body (Lat Lon)
write_sample("sectors.are", c(
  "4 4900 200 0 0 0 0 0 0 0 0 0 0 0 VOL_PARIS", # Header
  "4800 100",  # Vertex 1 (min)
  "5000 100",  # Vertex 2
  "5000 300",  # Vertex 3
  "4800 300",  # Vertex 4
  "4 5100 400 0 0 0 0 0 0 0 0 0 0 0 VOL_BRUSSELS", # Header
  "5050 350",
  "5150 350",
  "5150 450",
  "5050 450"
))

# .sls (Sector Composition)
# Format: Sector + Volume BottomFL TopFL
write_sample("sectors.sls", c(
  "SECTOR_PARIS + VOL_PARIS 0 195",
  "SECTOR_BRUSSELS + VOL_BRUSSELS 0 245"
))

# .aco (Colors)
# Format: Version Sector Min Max NbCol ... R G B
write_sample("airspace.aco", c(
  "1 SECTOR_PARIS 000 195 1 0 ? 0 1 C 128 255 0 0",    # Red
  "1 SECTOR_BRUSSELS 000 245 1 0 ? 0 1 C 128 0 255 0"  # Green
))

# .spc (Hierarchy)
# Format: A;ID;Name;Type (Parent), S;ID;Type (Child)
write_sample("airspace.spc", c(
  "#Version",
  "A;LFFF;Paris ACC;ACC",
  "S;SECTOR_PARIS;SECTOR",
  "A;EBBU;Brussels ACC;ACC",
  "S;SECTOR_BRUSSELS;SECTOR"
))

# --- 3. CONFIGURATIONS & OPERATIONS ---

# .cfg (Configuration Definitions)
# Format: Metadata, then ACC;ConfigID;SectorID
write_sample("sectors.cfg", c(
  "#Version",
  "LFFF;CONF_A;SECTOR_PARIS",
  "EBBU;CONF_1;SECTOR_BRUSSELS"
))

# .cos (Opening Scheme)
# Format: Metadata, Date;ACC;Start;End;ConfigID;Origin
write_sample("opening_scheme.cos", c(
  "#Version",
  "01/06/2024;LFFF;0000;2359;CONF_A;E",
  "01/06/2024;EBBU;0600;1400;CONF_1;E"
))

# .mot (Military Opening Times)
# Format: Version Zone Start End (MinFL MaxFL for V2)
write_sample("military.mot", c(
  "2 TSA_TRAINING 0800 1200 100 250",
  "1 DANGER_AREA 1400 1600"
))

# --- 4. TRAFFIC & ROUTING ---

# .rts (Routes)
# Format: Metadata, L;Name;Type;Out;In;Point;Type;Seq
write_sample("network.rts", c(
  "#Version",
  "L;UL607;AR;9999999999;0000000000;KOK;VOR;1",
  "L;UL607;AR;9999999999;0000000000;BUB;VOR;2"
))

# .ntfv (Traffic Volumes)
# Format: Metadata, T(Header), F(Flow)
write_sample("traffic.ntfv", c(
  "#Version",
  "T;TV_PARIS_DEP;Departure Flow;MO;LFFF;ACC;D;_;_",
  "F;AD DEP LFPG;IN"
))

# --- 5. LOGIC & RULES ---

# .flc2 (Flight Level Constraints)
write_sample("constraints.flc2", c(
  "#SECTION_1 - LEVEL_CAPS",
  "#RAD R001 - MAX FL245 for Short Haul",
  "if (DEP == \"LFPG\" && ARR == \"EBBR\") {",
  "  FL_CONT = < 245",
  "}"
))

# .awk (Routing Rules)
write_sample("routing.awk", c(
  "#SECTION_1 - ROUTING",
  "#RAD R002 - Force Route via KOK",
  "if (DEP == \"EGLL\" && ARR == \"EBBR\") {",
  "  REGLE = REGLE \" - KOK \"",
  "}"
))

# .rlex (Route Extensions)
# Format: Dep Arr NM
write_sample("extensions.rlex", c(
  "LFPG EBBR 50",
  "EGLL LFPG 20"
))

# --- 6. PENALTIES ---

# .tax (Turn Penalties)
# Format: Point1 Point2 Point3
write_sample("penalties.tax", c(
  "DIBER KOK BUB"
))

# .pnl (Segment Costs)
# Format: Point1 Point2 Cost
write_sample("costs.pnl", c(
  "KOK BUB 5.0"
))

message("All sample files generated in: ", output_dir)
