usethis::use_package("data.table")
usethis::use_package("stringi")

# 1. Clear previous artifacts
devtools::clean_vignettes()

# 2. Document (updates the NAMESPACE and documentation)
devtools::document()

# 3. Build vignettes again
devtools::build_vignettes()

devtools::install(build_vignettes = TRUE)

# Then check if it opens:
browseVignettes("rddr")

pkgdown::build_site()

read_nnpt(nnpt_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/AIRAC_479E.nnpt")
read_cfg(cfg_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/AIRAC_479E.cfg")
read_narp(narp_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/AIRAC_479E.narp")
read_ntfv(ntfv_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/AIRAC_479E.ntfv")
rte <- read_routes(routes_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/AIRAC_479E.routes")
read_runway(runway_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/AIRAC_479E.runway")
read_tax(tax_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/DCTRAD_2106_Exception_Turn_Angle.tax")
read_soa(soa_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/VST_2106_Area_Definition_RAD_Appendix_2.soa")
read_aco(aco_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/Free_Route_2106_Areas.aco")
read_arp(arp_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/VST_2106_Airports.arp")
read_mot(mot_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/Night_2106_Time.mot")
read_awk(awk_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/VST_2106_Airport_Zone.awk")
dt <- read_flc2(flc2_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/VST_2106_FLConstraints.flc2", parse_rules = T)

dt <- read_awk(awk_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/DCTNight_2106_Segment_Management.awk", parse_rules = T)

rule <- dt$rule_code
stri_count_fixed(rule[805:807], "if")
#rule <- "if ((ARR ~ /EDGG_FIR/) && (!(ARR ~ /EDDG|EDDK|.../)) && (POINT ~ /KOGOL/)) FL_CONT=-245"

# --- PART 1: Capture ALL keywords before a "~" (handles space or no space) ---
# Logic: Find word characters [A-Z0-9_]+ that are followed by any amount of space (//s*) and a ~
keywords <- purrr::map(rule, ~ regmatches(.x, gregexpr("[A-Z0-9_]+(?=//s*~)", .x, perl = TRUE))[[1]])
# Result: c("ARR", "ARR", "POINT")

do.call(c, keywords) |> unique()

dt[stringr::str_detect(rule_code, "CLIMB_RATE")]


are_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/DCTNight_2106_Areas.are"

are <- read_are(are_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/DCTNight_2106_Areas.are")
sls <- read_sls(sls_file = "C:/Users/alazarov/Desktop/RProjects/aim/ddr/ENV_PostOPS_AIRAC_2106_17JUN2021_With_Airspace_Closure/DCTNight_2106_Areas.sls")
make_elem_sect(sls = sls, are = are, make_sf = T)
