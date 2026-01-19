# Read SOA (Area Definition) File

This function parses SAAM `.soa` files. These files define "Areas,"
which are named collections of airports.

**Structure**: Each line defines one Area:

- Field 1: **Area Name** (Must be \>= 5 chars).

- Field 2..N: **Members** (Airports or other previously defined Area
  names).

**Features**:

- **Recursion**: An Area can contain other sub-Areas (e.g., "Paris"
  contains "Roissy").

- **Wildcards**: Airport names may contain `.` as a wildcard (e.g.,
  `ED..`).

## Usage

``` r
read_soa(soa_file, resolve_recursion = FALSE)
```

## Arguments

- soa_file:

  Path to the .soa file.

- resolve_recursion:

  Logical. If `TRUE`, the function attempts to fully expand sub-areas
  into their constituent airports. Defaults to `FALSE` (returns raw
  hierarchy).

## Value

A `data.table` with the following columns:

- `area_id`: The name of the defined Area.

- `member_id`: The identifier of the member (Airport or Sub-Area).

- `is_wildcard`: Logical. TRUE if the member ID contains wildcards
  (`.`).

## Details

Reads a .soa file defining sets of airports (Areas) for segment
management rules.
