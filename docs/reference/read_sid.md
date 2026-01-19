# Read SAAM Airport SID Points File

Reads and parses a `.sid` file containing a list of airport Standard
Instrument Departure (SID) points. The file format is expected to be
whitespace-separated, where the first column is the 4-character ICAO
airport code and subsequent columns are navigation point names.

## Usage

``` r
read_sid(sid_file_name)
```

## Arguments

- sid_file_name:

  A single character string specifying the path to the `.sid` file.

## Value

A
[`data.table`](https://rdatatable.gitlab.io/data.table/reference/data.table.html)
with two columns:

- icao_apt:

  Character. The ICAO airport code (e.g., "SAAM").

- sid:

  Character. The SID navigation point name.

If the file is empty or contains no valid data, an empty data.table is
returned.

## Details

The function relies on
[`data.table::fread`](https://rdatatable.gitlab.io/data.table/reference/fread.html)
for high-performance reading and `stringi` for efficient text
processing. It handles:

- Blank lines and whitespace trimming automatically.

- Files with no SIDs (returns empty table).

- Lines containing only an ICAO code (ignored, as there are no SIDs to
  list).

## Examples

``` r
if (FALSE) { # \dontrun{
# Assuming 'airports.sid' exists in your working directory
dt <- read_sid("airports.sid")
print(dt)
} # }
```
