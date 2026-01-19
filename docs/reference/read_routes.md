# Read RTS (Routes) File

This function parses SAAM/Gasel `.rts` files. These files define the
structure of airways (routes) by listing the sequence of points
(waypoints, VORs, etc.) that comprise them.

The file structure is defined as follows:

- **Extension**: rts

- **Separator**: Semicolon (;)

- **Sort**: By route name, then by sequence number.

The file consists of:

1.  **First Line**: Metadata starting with \#.

2.  **Body Lines (L)**: Records defining a point on a route.

**Record Structure (L lines)**:

- Field 1: **L** (Link/Line indicator)

- Field 2: **Route Name** (e.g., A1, A100)

- Field 3: **Type** (Usually "AR" for Airway Route)

- Field 4: **Time In** (Validity Start - often 0000...)

- Field 5: **Time Out** (Validity End - often 9999...)

- Field 6: **Point ID** (The navigation point name)

- Field 7: **Point Type** (e.g., SP, DBP, VTR)

- Field 8: **Sequence Number** (Order of the point in the route)

## Usage

``` r
read_routes(routes_file)
```

## Arguments

- routes_file:

  Path to the .rts file.

## Value

A `data.table` ordered by Route and Sequence, with columns:

- `route_id`: The name of the airway/route.

- `type`: Route type (e.g., AR).

- `time_in`: Validity start time (as character).

- `time_out`: Validity end time (as character).

- `point_id`: The identifier of the navigation point.

- `point_type`: The type of the navigation point.

- `sequence`: Integer representing the order of points.

## Details

Reads a .rts file defining the sequence of navigation points that make
up airways/routes.
