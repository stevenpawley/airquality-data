library(here)
library(tidyverse)
library(dtplyr)
library(vroom)
library(lubridate)
library(AzureStor)
library(AERtools)
library(duckdb)

source(here("R/functions-aep.R"))

dir.create(here("data/raw"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("data/processed"), showWarnings = FALSE, recursive = TRUE)

# download data from blob storage
con <- get_container('ds-spatial-raw')
blobs <- list_blobs(con, "airquality")

src <- blobs$name[-1]
dst <- here("data/raw", basename(src))
storage_multidownload(con, src, dst)

# create duckdb connection
cluck = dbConnect(
  duckdb::duckdb(),
  dbdir = here("data/processed/airdata"),
  read_only = FALSE
)

write_to_duck(con = cluck, files = dst, name = "airdata")
dbDisconnect(cluck)

# test connection
cluck = dbConnect(
  duckdb::duckdb(),
  dbdir = here("data/processed/airdata"),
  read_only = TRUE
)

airdata = tbl(cluck, "airdata")

airdata |>
  group_by(site, measurement) |>
  summarize(
    n = n(),
    start = min(intervalstart, na.rm = TRUE),
    end = max(intervalend, na.rm = TRUE)
  ) |> 
  ungroup()

