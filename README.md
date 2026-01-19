
# rddr <img src="man/figures/logo.png" align="right" height="139" />

<!-- badges: start -->

<!-- badges: end -->

## ⚠️ Disclaimer & Project Status

rddr is an independent, open-source initiative born from the necessity
to streamline aviation data analysis. It is not an official product, nor
is it affiliated with, endorsed by, or maintained by EUROCONTROL.

While this package is designed for robust performance and has been
tested extensively, it is provided “as is” without warranty of any kind.
Users are advised to validate results within their own operational
contexts. The maintainers assume no liability for the use,
interpretation, or consequences of data processed by this tool.

The **rddr** package provides parsers for the proprietary text formats
used in aviation tools like **SAAM** and **Gasel**.

Aviation data often comes in complex, non-standard text formats that mix
hierarchical structures, geometric definitions, and pseudo-code logic.
**rddr** reads these files and converts them into standard `data.table`
objects for analysis.

## Installation

You can install the development version of rddr from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("alazarovski/rddr")
```

## Quick Start & Data Reference

``` r
library(rddr)
library(data.table)

# Path to the sample data included in the package
# IMPORTANT: Ensure you have run the data generation script locally
data_path <- "inst/extdata" 
```

------------------------------------------------------------------------

### 1. Network Infrastructure

#### Airports (`.arp`)

Basic airport definitions. `read_arp()` automatically converts the raw
“minutes” format into standard Decimal Degrees.

``` r
airports <- read_arp(file.path(data_path, "network.arp"))
head(airports, 2)
#>      icao   lat    lon   fir_id
#>    <char> <num>  <num>   <char>
#> 1:   LFPG  49.0 2.5333 LFFF_FIR
#> 2:   EBBR  50.9 4.4833 EBBU_FIR
```

**Output Columns:** \* `icao`: 4-letter ICAO code (e.g., LFPG). \*
`lat`, `lon`: Latitude/Longitude in **Decimal Degrees**. \* `fir_id`:
The Flight Information Region the airport belongs to.

#### Extended Airport Metadata (`.narp`)

Contains sequencing parameters used for capacity modeling.

``` r
narp <- read_narp(file.path(data_path, "network.narp"))
head(narp[, .(icao, taxitime, tis, trs)], 2)
#>      icao taxitime   tis   trs
#>    <char>    <num> <num> <num>
#> 1:   LFPG       15    10     5
#> 2:   EBBR       10     8     8
```

**Output Columns:** \* `taxitime`: Default taxi time in minutes. \*
`tis`: **Time to Insert Sequence** (minutes). \* `trs`: **Time to Remove
Sequence** (minutes). \* `altitude`: Reference altitude.

#### Navigation Points (`.nnpt`)

Defines Waypoints, VORs, NDBs, and other fixes.

``` r
points <- read_nnpt(file.path(data_path, "points.nnpt"))
head(points, 2)
#>    point_id   type   lat   lon        name
#>      <char> <char> <num> <num>      <char>
#> 1:    DIBER     WZ    50   1.5 DIBER_POINT
#> 2:      KOK    VOR    51   2.5       KOKSY
```

**Output Columns:** \* `point_id`: The name of the point (e.g., KOK,
DIBER). \* `type`: The navigation type (VOR, WZ, NDB, etc.). \* `lat`,
`lon`: Coordinates in Decimal Degrees.

#### Runway Configurations (`.runway`)

Defines which runways (QFU) are active during specific time windows.

``` r
runways <- read_runway(file.path(data_path, "airport.runway"))
head(runways, 2)
#>          date   icao    qfu start_time end_time is_default taxi_time   tis
#>        <Date> <char> <char>      <int>    <int>     <lgcl>     <int> <int>
#> 1: 2024-06-01   LFPG    26R          0     2359       TRUE        15    10
#> 2: 2024-06-01   EBBR    25R        600     2200       TRUE        10     8
#>      trs origin
#>    <int> <char>
#> 1:     5      E
#> 2:     8      E
```

**Output Columns:** \* `qfu`: The runway designator (e.g., 26R). \*
`is_default`: Logical (`TRUE`/`FALSE`). Indicates if this is the
fallback configuration. \* `start_time`/`end_time`: Validity window
(HHMM string).

------------------------------------------------------------------------

### 2. Airspace Geometry

#### 2D Geometry (`.are`)

Defines the polygon shapes of “Airblocks” (Volumes). Returns a
long-format table where each row is a vertex.

``` r
geometry <- read_are(file.path(data_path, "sectors.are"))
head(geometry, 3)
#>    volume_id     lat    lon sequence
#>       <char>   <num>  <num>    <int>
#> 1: VOL_PARIS 80.0000 1.6667        1
#> 2: VOL_PARIS 83.3333 1.6667        2
#> 3: VOL_PARIS 83.3333 5.0000        3
```

**Output Columns:** \* `volume_id`: The ID of the airblock. \*
`sequence`: The order of the vertex (critical for drawing polygons). \*
`lat`, `lon`: Vertex coordinates in Decimal Degrees.

#### Sector Composition (`.sls`)

Links the 2D Volumes (`.are`) to vertical limits to create 3D Elementary
Sectors.

``` r
sectors <- read_sls(file.path(data_path, "sectors.sls"))
head(sectors, 2)
#>          sector_id volume_sign    volume_id fl_bottom fl_top
#>             <char>      <char>       <char>     <int>  <int>
#> 1:    SECTOR_PARIS           +    VOL_PARIS         0    195
#> 2: SECTOR_BRUSSELS           + VOL_BRUSSELS         0    245
```

**Output Columns:** \* `sector_id`: The resulting elementary sector
name. \* `volume_id`: The 2D shape being used. \* `fl_bottom`: Lower
vertical limit (Flight Level). \* `fl_top`: Upper vertical limit (Flight
Level).

#### Airspace Hierarchy (`.spc`)

Defines parent-child relationships (e.g., ACC -\> Sector -\> Elementary
Sector).

``` r
hierarchy <- read_spc(file.path(data_path, "airspace.spc"))
head(hierarchy, 2)
#>    airspace_type airspace_id sub_airspace_id sub_airspace_type
#>           <char>      <char>          <char>            <char>
#> 1:           ACC        LFFF    SECTOR_PARIS            SECTOR
#> 2:           ACC        EBBU SECTOR_BRUSSELS            SECTOR
```

**Output Columns:** \* `airspace_id`: The Parent ID. \*
`sub_airspace_id`: The Child ID. \* `airspace_type`: Type of the parent
(e.g., ACC). \* `sub_airspace_type`: Type of the child (e.g., SECTOR).

------------------------------------------------------------------------

### 3. Configurations & Operations

#### Configurations (`.cfg`)

Maps a “Configuration ID” to the list of Elementary Sectors that are
open and controlled together.

``` r
configs <- read_cfg(file.path(data_path, "sectors.cfg"))
head(configs, 2)
#>    acc_id config_id       sector_id
#>    <char>    <char>          <char>
#> 1:   LFFF    CONF_A    SECTOR_PARIS
#> 2:   EBBU    CONF_1 SECTOR_BRUSSELS
```

**Output Columns:** \* `config_id`: The name of the configuration (e.g.,
CONF_A). \* `sector_id`: A sector included in this configuration. \*
`acc_id`: The ACC owning this configuration.

#### Opening Scheme (`.cos`)

The schedule. Maps a specific Date + Time -\> Configuration ID.

``` r
schedule <- read_cos(file.path(data_path, "opening_scheme.cos"))
head(schedule, 2)
#>          date acc_id start_time end_time config_id origin_type
#>        <Date> <char>     <char>   <char>    <char>      <char>
#> 1: 2024-06-01   LFFF       0000     2359    CONF_A           E
#> 2: 2024-06-01   EBBU       0600     1400    CONF_1           E
```

**Output Columns:** \* `date`: Date object (YYYY-MM-DD). \*
`start_time`/`end_time`: Validity window (HHMM). \* `config_id`: The ID
found in the `.cfg` file. \* `origin_type`: ‘E’ (Environment/Planned) or
‘T’ (Tactical/Actual).

#### Military Opening Times (`.mot`)

Parses airspace activation files. Handles formats V1, V2 (with FL
limits), and V3 automatically.

``` r
mil <- read_mot(file.path(data_path, "military.mot"))
head(mil, 2)
#>    version      zone_id start_time end_time min_fl max_fl opening_type
#>      <int>       <char>     <char>   <char>  <int>  <int>       <char>
#> 1:       2 TSA_TRAINING       0800     1200    100    250         <NA>
#> 2:       1  DANGER_AREA       1400     1600     NA     NA         <NA>
```

**Output Columns:** \* `zone_id`: The airspace/zone name. \*
`min_fl`/`max_fl`: Vertical limits (if Version 2). \* `opening_type`:
Activation type (if Version 3).

------------------------------------------------------------------------

### 4. Traffic & Logic (Advanced Parsing)

#### Traffic Volumes (`.ntfv`)

Defines flow filters. Each Traffic Volume (TV) is a collection of flow
elements (IN/EX/AD).

``` r
tvs <- read_ntfv(file.path(data_path, "traffic.ntfv"))
head(tvs, 2)
#>           tv_id        tv_name tv_category ref_loc_name ref_loc_type
#>          <char>         <char>      <char>       <char>       <char>
#> 1: TV_PARIS_DEP Departure Flow          MO         LFFF          ACC
#>    ref_loc_role min_fl_or_skip_in max_fl_or_skip_out     flow_id flow_type
#>          <char>             <num>              <num>      <char>    <char>
#> 1:            D                NA                 NA AD DEP LFPG        IN
```

**Output Columns:** \* `tv_id`: The Traffic Volume ID. \* `flow_type`:
Filter type (e.g., `IN` for inclusion, `EX` for exclusion). \*
`flow_id`: The element being filtered (e.g., “AD DEP LFPG”). \*
`min_fl_or_skip_in`: Used for specialized flow types.

#### Flight Level Constraints (`.flc2`)

Parses pseudo-code logic rules used to cap flight levels. *Use
`parse_rules = TRUE` to extract regex patterns.*

``` r
flc <- read_flc2(file.path(data_path, "constraints.flc2"), parse_rules = TRUE)
head(flc[, .(rule_id, condition_dep, constraint_type, constraint_value)], 1)
#>    rule_id condition_dep constraint_type constraint_value
#>     <char>        <char>          <char>           <char>
#> 1:    R001          LFPG            <NA>             <NA>
```

**Output Columns:** \* `rule_id`: The name of the rule. \*
`condition_dep`/`condition_arr`: Regex pattern for airports/flows. \*
`constraint_type`: `MAX` (\<), `MIN` (\>), or `EQUAL` (=). \*
`constraint_value`: The Flight Level (integer).

#### Routing Rules (`.awk`)

Parses RAD (Route Availability Document) logic.

``` r
rad <- read_awk(file.path(data_path, "routing.awk"), parse_rules = TRUE)
head(rad[constraint_type == "ROUTING", .(rule_id, condition_dep, routing_constraint)], 1)
#>    rule_id condition_dep routing_constraint
#>     <char>        <char>             <char>
#> 1:    R002          EGLL             - KOK
```

**Output Columns:** \* `routing_constraint`: The required routing string
(e.g., ” - KOK - “). \* `condition_rfl_min`: Minimum Requested Flight
Level for rule to apply.

------------------------------------------------------------------------

### 5. Penalties

#### Turn Penalties (`.tax`)

Defines forbidden or penalized turns based on 3 points.

``` r
turns <- read_tax(file.path(data_path, "penalties.tax"))
head(turns, 1)
#>    point_1 point_2 point_3
#>     <char>  <char>  <char>
#> 1:   DIBER     KOK     BUB
```

**Output Columns:** \* The sequence is defined as `point_1` -\>
`point_2` (Turn Point) -\> `point_3`.

#### Segment Costs (`.pnl`)

Defines extra costs (in Nautical Miles) for specific segments.

``` r
costs <- read_pnl(file.path(data_path, "costs.pnl"))
head(costs, 1)
#>    start_point end_point penalty
#>         <char>    <char>   <num>
#> 1:         KOK       BUB       5
```

**Output Columns:** \* `penalty`: The added cost in NM.

------------------------------------------------------------------------

## Supported File Formats

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
