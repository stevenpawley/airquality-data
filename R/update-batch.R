library(here)
library(airdataAB)
library(dplyr)
library(lubridate)
library(purrr)

airdata <- readRDS(here("data/airdata.rds"))

last_dates <- 
  left_join(airdata, parameters_aqhi, by = c("station", "measure")) |> 
  filter(type == "Operational") |> 
  group_by(station) |> 
  summarize(last_date = max(datetime, na.rm = TRUE)) |> 
  filter(year(last_date) >= 2022)

new_data <- 
  map2_dfr(last_dates$station, last_dates$last_date, function(sta, dttm) {
    message(sta)
    collect_air(sta, start = dttm, end = now(),  source = "aqhi")
  })

saveRDS(new_data, here("data/airdata-daily.rds"))
