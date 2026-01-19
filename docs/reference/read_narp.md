# Read NARP (Airport) File

This function parses SAAM/Gasel `.narp` files. These files contain a
comprehensive list of airports, including their ICAO codes, names,
coordinates, and traffic sequencing parameters.

The file structure is defined as follows:

- **Extension**: narp

- **Separator**: Semicolon (;)

- **Coordinate System**: Decimal degrees

The file consists of:

1.  **First Line**: Metadata starting with \# (e.g., version, dates,
    record count).

2.  **Body Lines**: Records defining individual airports.

**Record Structure**:

- Field 1: **ICAO Code** (4 characters)

- Field 2: **Airport Name**

- Field 3: **Latitude** (Decimal Degrees)

- Field 4: **Longitude** (Decimal Degrees)

- Field 5: **TIS** (Time to Insert into Sequence - minutes)

- Field 6: **TRS** (Time to Remove from Sequence - minutes)

- Field 7: **Taxi Time** (minutes)

- Field 8: **Altitude** (Flight Levels)

**Note on TIS/TRS**: Underscores ("\_") in numeric fields (TIS, TRS,
TaxiTime) indicate missing data and are converted to NA.

## Usage

``` r
read_narp(narp_file)
```

## Arguments

- narp_file:

  Path to the .narp file.

## Value

A `data.table` with the following columns:

- `icao`: Character (4-letter ICAO code).

- `name`: Character (Airport name).

- `lat`: Numeric (Latitude).

- `lon`: Numeric (Longitude).

- `tis`: Numeric (Time to Insert).

- `trs`: Numeric (Time to Remove).

- `taxitime`: Numeric.

- `altitude`: Numeric (Flight Level).

## Details

Reads a .narp file defining airport metadata, location, and operational
parameters.
