library(tidyverse)
library(lubridate)
library(janitor)

# Load Raw Data
crashes_raw <- readRDS("data/crashes_raw.rds")

# Data Cleaning & Feature Engineering
crashes_clean <- crashes_raw %>%
  clean_names() %>%
  # Filter missing coordinates (Keep maps clean)
  filter(!is.na(latitude), !is.na(longitude)) %>%
  filter(latitude != 0, longitude != 0) %>%
  # 0 or 99 are usually data entry errors.
  filter(posted_speed_limit > 5 & posted_speed_limit < 80) %>% 
  # (Optional Safety Net) Double check to remove UNKNOWNs if API missed any
  filter(weather_condition != "UNKNOWN", 
         lighting_condition != "UNKNOWN",
         roadway_surface_cond != "UNKNOWN") %>%
  # --- 2. Feature Engineering ---
  mutate(
    crash_date = ymd_hms(crash_date),
    crash_hour = hour(crash_date),
    day_of_week = wday(crash_date, label = TRUE, abbr = TRUE),
    is_weekend = if_else(day_of_week %in% c("Sat", "Sun"), "Weekend", "Weekday"),
    crash_month = month(crash_date),
    season = case_when(
      crash_month %in% c(12, 1, 2, 3) ~ "Winter",
      crash_month %in% c(4, 5) ~ "Spring",
      crash_month %in% c(6, 7, 8) ~ "Summer",
      crash_month %in% c(9, 10, 11) ~ "Fall"
    ),
    # We set levels so "Injury" is the first level (or explicit), helps with confusion matrix interpretation
    injury_category = if_else(injuries_total > 0, "Injury", "No Injury"),
    injury_category = factor(injury_category, levels = c("Injury", "No Injury")) 
  ) %>%
  select(
    crash_record_id, crash_date, crash_hour, day_of_week, is_weekend, season,
    latitude, longitude, 
    weather_condition, lighting_condition, roadway_surface_cond,
    posted_speed_limit, prim_contributory_cause,
    injuries_total, injury_category, crash_type
  ) %>%
  # Drop any remaining NAs just to be safe for ML
  drop_na()

# Save Processed Data
if(!dir.exists("data")) dir.create("data")
saveRDS(crashes_clean, "data/crashes_clean.rds")

print(paste("Cleaning Complete! Processed", nrow(crashes_clean), "rows ready for analysis."))