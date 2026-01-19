
<!-- README.md is generated from README.Rmd. Please edit that file -->

# Introduction

The **rddr** package provides a robust, high-performance interface for
parsing the proprietary text-based file formats used in **SAAM** and
**Gasel** aviation tools.

Aviation data often comes in complex, non-standard text formats that mix
hierarchical structures, geometric definitions, and pseudo-code logic.
Instead of writing custom regex parsers for every analysis, **rddr**
transforms these formats into tidy `data.table`s ready for filtering and
analysis.

## Supported Formats

| File Ext  | Function      | Description                              |
|-----------|---------------|------------------------------------------|
| `.arp`    | `read_arp`    | Airport coordinates and FIRs             |
| `.narp`   | `read_narp`   | Advanced airport metadata (TIS/TRS/Taxi) |
| `.nnpt`   | `read_nnpt`   | Navigation points (Waypoints, VORs)      |
| `.sid`    | `read_sid`    | Standard Instrument Departures           |
| `.runway` | `read_runway` | Runway configurations & taxonomy         |
| `.soa`    | `read_soa`    | Area definitions (recursive groups)      |
| `.rts`    | `read_routes` | Route/Airway sequences                   |
| `.are`    | `read_are`    | Airblock/Volume 2D geometry              |
| `.sls`    | `read_sls`    | Sector vertical limits & composition     |
| `.aco`    | `read_aco`    | Airspace sector colors & levels          |
| `.spc`    | `read_spc`    | Airspace hierarchy (Parent/Child)        |
| `.cfg`    | `read_cfg`    | Sector configurations                    |
| `.cos`    | `read_cos`    | Configuration opening schemes            |
| `.ntfv`   | `read_ntfv`   | Traffic Volumes (Flow definitions)       |
| `.flc2`   | `read_flc2`   | Flight Level Constraints (FL_CONT)       |
| `.awk`    | `read_awk`    | RAD Routing Rules (REGLE)                |
| `.tax`    | `read_tax`    | Turning penalties                        |
| `.pnl`    | `read_pnl`    | Segment cost penalties                   |
| `.rlex`   | `read_rlex`   | Route length extension exceptions        |
| `.mot`    | `read_mot`    | Military/Airspace opening times          |

> **Note:** Example chunks that read external files use `eval = FALSE`
> so that the vignette builds even if those files are not available in
> your environment. Remove that option when running locally with the
> corresponding inputs.

# 1. Building the Network Environment

Before analyzing specific trajectories or rules, we must first load the
static network definitions.

## Setup

``` r
library(rddr)
library(data.table)
```

## Airports and Points

The `.arp` format provides basic airport locations, while `.narp` offers
detailed operational sequencing data. Navigation points are found in
`.nnpt` files.

``` r
# Basic Airport Definitions
airports <- read_arp("data/network.arp")

# Advanced Airport Metadata (Taxi times, TIS, TRS)
# Useful for sequencing analysis
airport_meta <- read_narp("data/network.narp")
head(airport_meta[, .(icao, taxitime, tis, trs)])

# Navigation Points (Waypoints)
waypoints <- read_nnpt("data/points.nnpt")
#    point_id type     lat     lon
# 1:     DENUT   DB 51.2500 -2.5000
```

## SIDs and Runways

For terminal maneuvering area (TMA) analysis, we load SIDs and Runway
configurations.

``` r
# Read SID definitions (ICAO -> Point list)
sids <- read_sid("data/airports.sid")

# Read Runway configurations
runways <- read_runway("data/airport.runway")
```

## Routes and Areas

Routes (`.rts`) define airways, while `.soa` files define groups of
airports (e.g., `LONDON_GROUP`).

``` r
# Read Airway Definitions
airways <- read_routes("data/network.rts")
# Ordered sequence of points for route 'UL607'
ul607 <- airways[route_id == "UL607"]

# Read Area Groups (with recursion resolution)
areas <- read_soa("data/groups.soa", resolve_recursion = TRUE)
```

# 2. Airspace Geometry & Hierarchy

Understanding the 3D structure of airspace requires parsing geometry
(`.are`), vertical limits (`.sls`), and hierarchy (`.spc`).

## Geometry and Composition

``` r
# Read 2D Geometry (Vertices)
# Returns an ordered list of lat/lon points per volume
geometry <- read_are("data/sectors.are")

# Read Sector Composition (Vertical limits & Volume mapping)
# Links the 2D volumes from .are to vertical FL bands
sector_defs <- read_sls("data/sectors.sls")

# Read Visual Attributes (Colors)
# Useful for plotting
sector_colors <- read_aco("data/airspace.aco")
```

## Hierarchy and Traffic Volumes

Traffic volumes (`.ntfv`) define flows, while `.spc` defines the
parent-child relationships between airspaces.

``` r
# Read Airspace Hierarchy (ACC -> Sector -> Elementary Sector)
hierarchy <- read_spc("data/airspace.spc")

# Read Traffic Volumes (Flow definitions)
# Contains logic for IN/OUT/EX flows
tvs <- read_ntfv("data/traffic_volumes.ntfv")
```

# 3. Configurations & Schedules

Operational data relies on knowing which sector configuration is active
at what time.

``` r
# Read Configuration Definitions
# Maps configuration IDs (e.g., "CONF_A") to active sectors
configs <- read_cfg("data/sectors.cfg")

# Read Opening Scheme (Schedule)
# Determines when specific configurations are active
schedule <- read_cos("data/opening_scheme.cos")

# Find active configuration for a specific ACC on a specific date
daily_plan <- schedule[date == as.Date("2024-06-01") & acc_id == "LFMM"]
```

# 4. Analyzing Logic: RAD Rules & Constraints

A powerful feature of **rddr** is parsing the pseudo-code logic found in
`.flc2` (Level Constraints) and `.awk` (Routing) files. These files can
contain complex `if`/`then` logic, nested blocks, and regex matching.

## Parsing Flight Level Constraints (`.flc2`)

Set `parse_rules = TRUE` to extract actionable columns like `DEP`,
`ARR`, and `FL_CONT`.

``` r
# Parse Flight Level Constraints
flc <- read_flc2("data/constraints.flc2", parse_rules = TRUE)

# Inspect structured output
head(flc[, .(rule_id, condition_dep, condition_arr, constraint_type, constraint_value)])
```

## Parsing Routing Rules (`.awk`)

Routing rules involve `REGLE` (routing strings) and `RFL` (Requested
Flight Level) conditions.

``` r
rad_rules <- read_awk("data/routing.awk", parse_rules = TRUE)

# Find rules that force a specific routing for heavy jets (RFL >= 300)
forced_routes <- rad_rules[
  constraint_type == "ROUTING" &
  condition_rfl_min >= 300
]
```

# 5. Handling Penalties and Exceptions

For optimization or simulation workflows, you often need to load costs
and exceptions.

## Penalties

``` r
# Turn Penalties (Geometric turns)
turns <- read_tax("data/penalties.tax")
# Check for forbidden turns
forbidden <- turns[point_2 == "KOK"]

# Segment Penalties (Cost in NM for specific links)
segment_costs <- read_pnl("data/costs.pnl")
```

## Exceptions and Activations

``` r
# Route Length Extension Exceptions
rlex <- read_rlex("data/extensions.rlex")

# Military/Zone Opening Times
# Handles versions 1, 2, and 3 automatically
mil_areas <- read_mot("data/military.mot")

# Filter for areas active during the morning peak
morning_active <- mil_areas[start_time <= "0800" & end_time >= "0900"]
```

# Summary

The **rddr** package abstracts away the complexity of parsing legacy
text formats. By converting everything into `data.table` structures, it
allows analysts to focus on traffic flow, rule compliance, and network
optimization rather than regular expressions and low-level file parsing.
