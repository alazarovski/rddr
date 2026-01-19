# Read SLS (Sector Level) File

This function parses SAAM/Airspace Editor `.sls` files which define the
composition of sectors by mapping them to specific volumes (airblocks)
and defining vertical limits.

The file structure is defined as follows:

- **Extension**: sls

- **Origin**: Airspace Editor

- **Separator**: Blank (whitespace)

- **Sort**: Grouped by sector name

**Functionality**: The file links sectors to volumes defined in the ARE
(ASCII Region) file.

The file consists of rows with the following fields:

1.  **sector_id**: Sector name (Max 19 chars).

2.  **volume_sign**: Always "+" (indicates the volume is added to the
    sector).

3.  **volume_id**: Refers to the name of the volume in the ARE file (max
    24 chars).

4.  **fl_bottom**: Flight Level (FL), overwrites the level in the ARE
    file.

5.  **fl_top**: Flight Level (FL), overwrites the level in the ARE file.

*Note: Meta lines supported in previous SLS formats are not supported in
this parser. Use SPC format for metadata.*

## Usage

``` r
read_sls(sls_file)
```

## Arguments

- sls_file:

  Path to the .sls file.

## Value

A `data.table` containing sector definitions with columns:

- `sector_id`: The identifier for the sector.

- `volume_sign`: The inclusion flag (should be "+").

- `volume_id`: The identifier for the airblock/volume.

- `fl_bottom`: The lower vertical limit (Flight Level).

- `fl_top`: The upper vertical limit (Flight Level).

## Details

Reads the .sls file defining sector vertical limits and airblock
mapping.
