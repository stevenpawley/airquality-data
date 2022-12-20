library(here)
library(airdataAB)
library(dplyr)
library(lubridate)
library(purrr)

# read previous data
airdata_daily <- readRDS(here("data/airdata-daily.rds"))

# get the last date recorded for each station
last_dates <- airdata_daily |>
  group_by(station) |> 
  summarize(last_date = max(datetime, na.rm = TRUE)) |> 
  filter(year(last_date) >= 2022)

# download new_data
new_data <- 
  map2_dfr(last_dates$station, last_dates$last_date, function(sta, dttm) {
    message(sta)
    collect_air(sta, start = dttm, end = now(),  source = "aqhi")
  })

# merge new_data with previous daily data
updated_data <- bind_rows(airdata_daily, new_data)

# remove any duplicates
updated_data <- updated_data |> 
  distinct()

# store
saveRDS(updated_data, here("data/airdata-daily.rds"))
