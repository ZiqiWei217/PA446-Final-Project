library(tidyverse)
library(janitor)
library(utils)

# Define API Endpoint
base_url <- "https://data.cityofchicago.org/resource/85ca-t3if.csv"

# Expand Time Range (Fix Temporal Bias)
# To capture full seasonality, we need data covering at least a full year.
where_clause <- "crash_date >= '2023-01-01' AND weather_condition != 'UNKNOWN' AND lighting_condition != 'UNKNOWN' AND roadway_surface_cond != 'UNKNOWN'"

#  Increase Download Limit
query_url <- paste0(
  base_url,
  "?$where=", URLencode(where_clause),
  "&$limit=300000" # Fetch everything first
)

# Fetch Data
tryCatch({
  crashes_all <- read_csv(query_url)
  print(paste("Downloaded Total Rows:", nrow(crashes_all)))
  # Random Sampling
  set.seed(123) # Ensure reproducibility
  crashes_sample <- crashes_all %>%
    slice_sample(n = 100000)
  print(paste("Randomly sampled:", nrow(crashes_sample), "rows for analysis."))

  # Save locally
  if(!dir.exists("data")) dir.create("data")
  saveRDS(crashes_sample, "data/crashes_raw.rds")
  
  print("Success! Data saved to data/crashes_raw.rds")
  
}, error = function(e) {
  print("Error downloading data:")
  print(e)
})