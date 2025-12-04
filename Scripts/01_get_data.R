library(tidyverse)
library(janitor)

# Define API Endpoint
base_url <- "https://data.cityofchicago.org/resource/85ca-t3if.csv"

# Build the Query URL
query <- paste0(
  base_url,
  "?$where=crash_date%20>=%20'2023-01-01'",
  "&", "$limit=50000"
)

# Fetch Data
print("Downloading Crash Data... (Please wait)")
crashes_raw <- read_csv(query)

# Quick Check
print(paste("Downloaded", nrow(crashes_raw), "rows."))
print(head(crashes_raw))

# Save locally
if(!dir.exists("data")) dir.create("data")
saveRDS(crashes_raw, "data/crashes_raw.rds")

print("Success! Data saved to data/crashes_raw.rds")