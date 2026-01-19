# Read COS (Opening Scheme) File

This function parses SAAM/Gasel `.cos` files. These files determine
which configuration (defined in `.cfg` files) is active for a specific
ACC/Airspace during a specific time window.

The file structure is defined as follows:

- **Extension**: cos

- **Origin**: Gasel, SAAM

- **Separator**: Semicolon (;)

- **Sort**: By period, then family, then start time.

The file consists of:

1.  **First Line**: Metadata starting with \# (e.g., version, dates).

2.  **Body Lines**: Records defining the schedule.

**Record Structure**:

- Field 1: **Date** (dd/MM/yyyy)

- Field 2: **ACC Name** (Family/Group ID)

- Field 3: **Start Time** (hh:mm)

- Field 4: **End Time** (hh:mm)

- Field 5: **Configuration Name** (ID of the active configuration)

- Field 6: **Origin** ('E' = Environment/Planned, 'T' = Tactical/Actual)

## Usage

``` r
read_cos(cos_file)
```

## Arguments

- cos_file:

  Path to the .cos file.

## Value

A `data.table` with the following columns:

- `date`: Date object (Date class).

- `acc_id`: The identifier of the ACC/Family.

- `start_time`: Character (hh:mm).

- `end_time`: Character (hh:mm).

- `config_id`: The identifier of the configuration.

- `origin_type`: Character ('E' or 'T').

## Details

Reads a .cos file defining the operational opening scheme (schedule) of
configurations.
