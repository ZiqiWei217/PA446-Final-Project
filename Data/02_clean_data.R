library(tidyverse)
library(lubridate)
library(janitor)

# Load Raw Data
crashes_raw <- readRDS("data/crashes_raw.rds")

# Data Cleaning & Feature Engineering
crashes_clean <- crashes_raw %>%
  clean_names() %>%
  # Clean geographic data
  filter(!is.na(latitude), !is.na(longitude)) %>%
  filter(latitude != 0, longitude != 0) %>%
  
  # Feature Engineering
  mutate(
    crash_date = ymd_hms(crash_date),
    crash_hour = hour(crash_date),
    day_of_week = wday(crash_date, label = TRUE, abbr = TRUE),
    is_weekend = if_else(day_of_week %in% c("Sat", "Sun"), "Weekend", "Weekday"),
    crash_month = month(crash_date),
    season = case_when(
      crash_month %in% c(12, 1, 2) ~ "Winter",
      crash_month %in% c(3, 4, 5) ~ "Spring",
      crash_month %in% c(6, 7, 8) ~ "Summer",
      crash_month %in% c(9, 10, 11) ~ "Fall"
    ),
    
    # Binary Target, Injury or No Injury
    injury_category = if_else(injuries_total > 0, "Injury", "No Injury")
  ) %>%
  select(
    crash_record_id, crash_date, crash_hour, day_of_week, is_weekend, season,
    latitude, longitude, 
    weather_condition, lighting_condition, roadway_surface_cond,
    posted_speed_limit, prim_contributory_cause,
    injuries_total, injury_category, crash_type
  )

# Save Processed Data
if(!dir.exists("data")) dir.create("data")
saveRDS(crashes_clean, "data/crashes_clean.rds")

print(paste("Cleaning Complete! Processed", nrow(crashes_clean), "rows."))