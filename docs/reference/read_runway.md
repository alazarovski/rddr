# Read RUNWAY File

This function parses SAAM/Gasel `.runway` files. These files define
which runways (QFU) are active for specific airports on specific dates,
along with their operational parameters.

The file structure is defined as follows:

- **Extension**: runway

- **Origin**: Gasel, SAAM

- **Separator**: Semicolon (;)

- **Sort**: By Date, then Airport, then QFU.

The file consists of:

1.  **First Line**: Metadata starting with \#.

2.  **Body Lines**: Records defining runway usage.

**Record Structure**:

- Field 1: **Date** (dd/MM/yyyy)

- Field 2: **Airport ICAO** (4 chars)

- Field 3: **QFU** (Runway Designator, e.g., 29C, 06)

- Field 4: **Start Time** (HHMM)

- Field 5: **End Time** (HHMM)

- Field 6: **Default** (Y/N - Is this the default runway configuration?)

- Field 7: **Taxi Time** (Minutes)

- Field 8: **TIS** (Time to Insert into Sequence - Minutes)

- Field 9: **TRS** (Time to Remove from Sequence - Minutes)

- Field 10: **Origin** (E=Environment/Planned, T=Tactical/Actual)

## Usage

``` r
read_runway(runway_file)
```

## Arguments

- runway_file:

  Path to the .runway file.

## Value

A `data.table` with the following columns:

- `date`: Date object.

- `icao`: Character.

- `qfu`: Character (Runway ID).

- `start_time`: Character (HHMM).

- `end_time`: Character (HHMM).

- `is_default`: Logical (TRUE if 'Y', FALSE if 'N').

- `taxi_time`: Integer.

- `tis`: Integer.

- `trs`: Integer.

- `origin`: Character.

## Details

Reads a .runway file defining runway configurations, availability, and
sequencing parameters.
