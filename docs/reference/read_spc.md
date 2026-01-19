# Read SPC (Airspace) File

This function parses SAAM/Gasel `.spc` files which describe airspace
organization.

## Usage

``` r
read_spc(spc_file)
```

## Arguments

- spc_file:

  Path to the .spc file.

## Value

A `data.table` with the following columns:

- `airspace_type`: The type of the parent airspace (e.g., "AUAG",
  "NAS").

- `airspace_id`: The identifier of the parent airspace.

- `sub_airspace_id`: The identifier of the child element (sub-airspace
  or sector).

- `sub_airspace_type`: The type of the child element (e.g., "AUA",
  "FIR").

## Details

Reads the .spc file defining airspace hierarchy and types.
