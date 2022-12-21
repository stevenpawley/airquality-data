library(here)
library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(airdataAB)
library(ggplot2)
library(lubridate)

# read all tables
src = list.files(here("raw"), full.names = TRUE, pattern = "*.csv")
tbls = lapply(src, fread_airdata_csv)
airdata = rbindlist(tbls)
airdata = airdata |> 
  as_tibble() |> 
  distinct()
saveRDS(airdata, "data/airdata.rds")

# check data
jan1 <- tbls %>%
  filter(
    station == "Airdrie",
    measure == "Wind Speed",
    datetime > make_datetime(2022, 1, 1, tz = "America/Edmonton"),
    datetime < make_datetime(2022, 1, 2, tz = "America/Edmonton")
  )

jan1_live <- collect_air(
  station = "Airdrie",
  start  = make_datetime(2022, 1, 1, tz = "America/Edmonton"),
  end = make_datetime(2022, 1, 2, tz = "America/Edmonton"),
  averaging = "1hr",
  source = "aqhi"
) |>
  filter(measure == "Wind Speed")

ggplot() +
  geom_line(data = jan1, aes(x = datetime, y = value), linewidth = 2) +
  geom_line(data = jan1_live, aes(x = datetime, y = value), colour = 'red')
