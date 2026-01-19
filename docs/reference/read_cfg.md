# Read CFG (Configuration) File

This function parses SAAM/Gasel `.cfg` files. These files define how
elementary sectors or airspaces are grouped into operational
configurations (e.g., "CONF1", "Night_Config") under a specific ACC
(Area Control Center) or airspace family.

The file structure is defined as follows:

- **Extension**: cfg

- **Origin**: Gasel, SAAM

- **Separator**: Semicolon (;)

- **Sort**: By family/ACC name, then by configuration name.

The file consists of:

1.  **First Line**: Metadata starting with \# (e.g., version, dates,
    record count).

2.  **Body Lines**: Records linking an ACC/Family and Configuration to a
    specific Sector.

**Record Structure**:

- Field 1: **ACC Name** (Family or Grouping ID)

- Field 2: **Configuration Name** (The ID of the specific configuration)

- Field 3: **Sector Name** (The component included in this
  configuration)

## Usage

``` r
read_cfg(cfg_file)
```

## Arguments

- cfg_file:

  Path to the .cfg file.

## Value

A `data.table` with the following columns:

- `acc_id`: The identifier of the ACC or Airspace Family.

- `config_id`: The name of the configuration.

- `sector_id`: The identifier of the sector belonging to this
  configuration.

## Details

Reads a .cfg file defining Air Traffic Control (ATC) configurations and
their sector compositions.
