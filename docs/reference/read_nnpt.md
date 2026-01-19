# Read NNPT (Navigation Point) File

This function parses `.nnpt` files used to define navigation points
(waypoints, VORs, NDBs, etc.).

The file structure is defined as follows:

- **Extension**: nnpt

- **Separator**: Semicolon (;)

- **Coordinate System**: Decimal degrees

The file consists of:

1.  **First Line**: An integer representing the total number of records.

2.  **Subsequent Lines**: Records containing the point definition.

**Record Structure**:

- Field 1: **ID** (e.g., \*01BP)

- Field 2: **Type** (e.g., DB)

- Field 3: **Latitude** (Decimal Degrees)

- Field 4: **Longitude** (Decimal Degrees)

- Field 5: **Name** (Underscore "\_" indicates no data)

## Usage

``` r
read_nnpt(nnpt_file)
```

## Arguments

- nnpt_file:

  Path to the .nnpt file.

## Value

A `data.table` with the following columns:

- `point_id`: The unique identifier of the navigation point.

- `type`: The type classification of the point.

- `lat`: Latitude in decimal degrees.

- `lon`: Longitude in decimal degrees.

- `name`: The descriptive name (NA if original was "\_").

## Details

Reads a .nnpt file containing a list of navigation points with
coordinates.
