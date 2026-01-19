library(data.table)
library(stringi)

parse_flc2_constraints <- function(flc_dt) {

  # 1. Extract The Conditionals (Left Hand Side)
  # Look for "DEP ~ /.../" patterns
  flc_dt[, condition_dep := stri_match_first_regex(rule_code, "DEP\\s*~\\s*/([^/]+)/")[,2]]

  # Look for "ARR ~ /.../" patterns
  flc_dt[, condition_arr := stri_match_first_regex(rule_code, "ARR\\s*~\\s*/([^/]+)/")[,2]]

  # Look for "POINT ~ /.../" patterns
  flc_dt[, condition_point := stri_match_first_regex(rule_code, "POINT\\s*~\\s*/([^/]+)/")[,2]]

  # 2. Extract the Constraint (Right Hand Side)
  # Look for "FL_CONT=" followed by a value
  # We capture the sign (optional) and the digits
  constraint_match <- stri_match_first_regex(rule_code, "FL_CONT\\s*=\\s*([-+>]?)(\\d+)")

  flc_dt[, raw_sign := constraint_match[,2]]
  flc_dt[, constraint_fl := as.integer(constraint_match[,3])]

  # 3. Determine Constraint Type based on the sign
  flc_dt[, constraint_type := fcase(
    raw_sign == "-" | raw_sign == "<", "MAX", # Ceiling
    raw_sign == "+" | raw_sign == ">", "MIN", # Floor
    raw_sign == "", "EQUAL",                  # Exact FL (rare but possible)
    default = NA_character_
  )]

  # Return clean table
  return(flc_dt[!is.na(constraint_fl), .(rule_id, condition_dep, condition_arr, condition_point, constraint_type, constraint_fl)])
}
