# Read ARE (Newmaxo ASCII Region) File

This function parses SAAM/Newmaxo `.are` files. These files define the
2D geometry of airblocks. The file is structured as a repeating sequence
of a Header line followed by multiple Body lines (vertices).

- **Extension**: are

- **Origin**: Newmaxo, SAAM, CAPAN

- **Separator**: Blank (whitespace)

**Header Line (Metadata)**:

- Field 1: Number of points (vertices)

- Field 2-3: Label latitude/longitude (Center of label, not a vertex)

- Field 4-14: Attributes (Levels, flags, colors)

- Field 15: **Volume Name** (Airblock ID)

**Body Line (Geometry)**:

- Field 1: Latitude (minutes)

- Field 2: Longitude (minutes)

## Usage

``` r
read_are(are_file)
```

## Arguments

- are_file:

  Path to the .are file.

## Value

A `data.table` ordered by sequence, containing:

- `volume_id`: The identifier of the airblock/volume.

- `lat`: Latitude in decimal degrees.

- `lon`: Longitude in decimal degrees.

- `sequence`: The original ordering of the points (crucial for polygon
  closure).

## Details

Reads the .are file defining the coordinates (vertices) of
airblocks/volumes.
