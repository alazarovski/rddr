# Read ARP (Airport Definition) File

This function parses `.arp` files, which provide a simple definition of
airport locations used in SAAM assignment processes.

The file structure is defined as follows:

- **Extension**: arp

- **Origin**: Manual input

- **Separator**: Whitespace

- **Coordinate Unit**: Minutes (Decimal)

**Record Structure**:

- Field 1: **Airport ICAO** (4 characters)

- Field 2: **Latitude** (Minutes)

- Field 3: **Longitude** (Minutes)

- Field 4: **FIR Name** (Optional, e.g., "EGTT_FIR" or "NOFIR")

## Usage

``` r
read_arp(arp_file)
```

## Arguments

- arp_file:

  Path to the .arp file.

## Value

A `data.table` with the following columns:

- `icao`: Character (4-letter ICAO code).

- `lat`: Numeric (Latitude in Decimal Degrees).

- `lon`: Numeric (Longitude in Decimal Degrees).

- `fir_id`: Character (The associated Flight Information Region).

## Details

Reads an .arp file defining the geographical location and FIR
association of airports.
