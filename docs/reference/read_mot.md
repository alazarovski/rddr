# Read MOT (Airspace Activation) File

This function parses SAAM `.mot` files (Military Opening Time). These
files define when specific airspaces (usually military zones or Free
Route Airspace) are active or available for civil traffic.

The file structure supports three format versions, indicated by the
first field:

- **Version 1**: Basic activation (Zone, Start, End).

- **Version 2**: Level restricted (Zone, Start, End, Min FL, Max FL).

- **Version 3**: Type restricted (Zone, Start, End, Opening Type).

**Record Structure**:

- Field 1: **Version** (1, 2, or 3).

- Field 2: **Zone Name** (Must match SLS/Map definitions).

- Field 3: **Start Time** (HHMM).

- Field 4: **End Time** (HHMM).

- Field 5: **Lower FL** (Ver 2) OR **Opening Type** (Ver 3).

- Field 6: **Upper FL** (Ver 2 only).

## Usage

``` r
read_mot(mot_file)
```

## Arguments

- mot_file:

  Path to the .mot file.

## Value

A `data.table` with the following columns:

- `version`: Integer (1, 2, or 3).

- `zone_id`: Character.

- `start_time`: Character (HHMM).

- `end_time`: Character (HHMM).

- `min_fl`: Integer (NA for Ver 1 & 3).

- `max_fl`: Integer (NA for Ver 1 & 3).

- `opening_type`: Character (NA for Ver 1 & 2. e.g., "EX", "E").

## Details

Reads a .mot file defining airspace activation times, flight levels, and
opening types.
