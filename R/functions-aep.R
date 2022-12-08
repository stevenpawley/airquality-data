read_airquality <- function(fp) {
  # read the data portion of the file
  tbl <- vroom(fp, skip = 15, show_col_types = FALSE, progress = TRUE,
               col_names = FALSE)
  
  # read the header
  con <- file(fp, "r")
  headers <- readLines(con, n = 16, skipNul = TRUE)
  close(con)
  
  # extract names from header
  measurements <- str_split(headers[16], ",")[[1]]
  
  parameters <- str_split(headers[12], ",")[[1]]
  parameters <- parameters[-c(1:2)]
  parameters <- str_remove(parameters, "Parameter: ")
  
  method <- str_split(headers[13], ",")[[1]]
  method <- method[-c(1:2)]
  method <- str_remove(method, "Method Name: ")
  
  punits <- str_split(headers[14], ",")[[1]]
  punits <- punits[-c(1:2)]
  punits <- str_remove(punits, "Unit: ")
  punits <- str_replace(punits, "percent", "%")
  punits <- str_replace(punits, "deg c", "degC")
  punits <- str_replace(punits, "^deg$", "degrees")
  
  stationname <- str_split(headers[7], ",")[[1]]
  stationname <- stationname[stationname != ""][[1]]
  stationname <- str_remove(stationname, "StationName: ")
  stationname <- str_extract(stationname, "[A-z0-9\\-\\(\\) ]+")
  stationname <- str_trim(stationname)
  
  # assign measurement to column headers
  measurements[-c(1:2)] <- paste(parameters, punits, method, sep = "_")
  
  tbl_named <- tbl %>% 
    set_names(measurements) %>% 
    rename_with(tolower) %>% 
    mutate(across(-c(intervalstart, intervalend), as.numeric))
  
  # pivot to long form and convert ppm to ppb
  tbl_long <- tbl_named %>%
    pivot_longer(
      cols = -c(intervalstart, intervalend), 
      names_to = c("measurement", "unit", "method"),
      values_to = c("reading"),
      names_sep = "_"
    )
  
  # convert ppm to ppb for all measurements
  tbl_ppb <- tbl_long %>%
    group_by(measurement, unit) |> 
    group_split() |> 
    map_dfr(function(x) {
      unit <- unique(x$unit)
      if (unit == "ppm") {
        x$reading <- x$reading * 1000
        x$unit <- "ppb"
      }
      return(x)
    })
  
  tbl_coalesced <- tbl_ppb %>% 
    lazy_dt() %>% 
    group_by(intervalstart, intervalend, measurement, unit) %>% 
    summarize(reading = mean(reading, na.rm = TRUE)) %>% 
    as_tibble()
  
  tbl_coalesced <- tbl_coalesced %>% 
    mutate(
      intervalstart = parse_date_time(
        intervalstart,
        orders = c("dmY HMS", "mdY HMS"),
        tz = "MST"
      ),
      intervalend = parse_date_time(
        intervalend,
        orders = c("dmY HMS", "mdY HMS"),
        tz = "MST"
      ),
      site = !!stationname
    )
  
  tbl_wide <- tbl_coalesced %>% 
    pivot_wider(names_from = c(measurement, unit), values_from = reading)
  
  stopifnot(nrow(tbl_wide) == nrow(tbl_named))
  
  return(tbl_coalesced)
}

write_to_duck = function(con, files, name) {
  tbl = read_airquality(dst[1])
  tbl = drop_na(tbl)
  
  if (!dbExistsTable(cluck, name)) {
    dbCreateTable(cluck, name, tbl)  
  }
  
  dbAppendTable(cluck, name, tbl)
  
  for (fp in files[-1]) {
    tbl = read_airquality(fp)
    dbAppendTable(cluck, name, tbl)
  }
}
