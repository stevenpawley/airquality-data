library(here)
library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(airdataAB)
library(AzureStor)
library(AERtools)
library(ggplot2)
library(lubridate)

# download data from blob storage
con <- get_container('ds-spatial-raw')
blobs <- list_blobs(con, "airquality")

src <- blobs$name[-1]
dir.create(here("tmp"))
dst <- here("tmp", basename(src))
storage_multidownload(con, src, dst)

# read all tables
tbls = lapply(dst, fread_airdata_csv)
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
