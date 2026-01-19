# Read RLEX (Route Length Extension Exception) File

This function parses SAAM/Gasel `.rlex` files. These files specify
exceptions to standard route length validation rules, allowing specific
departure-arrival pairs to have a defined route length extension (in
Nautical Miles).

The file structure is defined as follows:

- **Extension**: rlex

- **Origin**: Produced manually

- **Separator**: Whitespace (Space or Tab)

**Record Structure**:

- Field 1: **ADEP** (Departure Airport ICAO)

- Field 2: **ADES** (Arrival Airport ICAO)

- Field 3: **Allowed Extension** (Numeric, in NM)

## Usage

``` r
read_rlex(rlex_file)
```

## Arguments

- rlex_file:

  Path to the .rlex file.

## Value

A `data.table` with the following columns:

- `adep`: Departure airport ICAO code.

- `ades`: Arrival airport ICAO code.

- `allowed_extension`: The allowed extension in Nautical Miles.

## Details

Reads a .rlex file defining allowed route length extensions between
airport pairs.
