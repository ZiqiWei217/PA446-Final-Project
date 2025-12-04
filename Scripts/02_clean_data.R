library(tidyverse)
library(lubridate)
library(janitor)
library(sf)

# Load Raw Data
crashes_raw <- readRDS("data/crashes_raw.rds")

# Get Chicago Community Areas (Spatial Data)
ca_boundaries <- read_sf("https://data.cityofchicago.org/resource/igwz-8jzy.geojson") %>%
  select(community_area = area_numbe, community_name = community) %>%
  mutate(community_area = as.numeric(community_area))

# Perform Spatial Join (Fixing the missing 'community_area' error)
# Convert raw crash data to a spatial object (points)
crashes_sf <- crashes_raw %>%
  clean_names() %>%
  # Remove rows with invalid coordinates
  filter(!is.na(latitude), !is.na(longitude), latitude != 0, longitude != 0) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)

# Join points with polygons to find out which community each crash happened in
crashes_joined <- st_join(crashes_sf, ca_boundaries) %>%
  st_drop_geometry() # Convert back to a standard dataframe for speed

# Define Professional Mapping (Official 9 Sides of Chicago)
# Map the 77 Community Areas to 9 larger City Sides for better analysis.
community_map <- tribble(
  ~community_area, ~city_side,
  1, "Far North Side", 2, "Far North Side", 3, "Far North Side", 4, "Far North Side",
  5, "North Side", 6, "North Side", 7, "North Side",
  8, "Central", 32, "Central", 33, "Central",
  9, "Far North Side", 10, "Far North Side", 11, "Far North Side", 12, "Far North Side",
  13, "Far North Side", 14, "Far North Side", 76, "Far North Side", 77, "Far North Side",
  15, "Northwest Side", 16, "Northwest Side", 17, "Northwest Side", 18, "Northwest Side",
  19, "Northwest Side", 20, "Northwest Side",
  21, "North Side", 22, "North Side",
  23, "West Side", 24, "West Side", 25, "West Side", 26, "West Side",
  27, "West Side", 28, "West Side", 29, "West Side", 30, "West Side", 31, "West Side",
  34, "South Side", 35, "South Side", 36, "South Side", 37, "South Side",
  38, "South Side", 39, "South Side", 40, "South Side", 41, "South Side",
  42, "South Side", 43, "South Side", 69, "South Side",
  44, "Far South Side", 45, "Far South Side", 46, "Far South Side", 47, "Far South Side",
  48, "Far South Side", 49, "Far South Side", 50, "Far South Side", 51, "Far South Side",
  52, "Far South Side", 53, "Far South Side", 54, "Far South Side", 55, "Far South Side",
  56, "Southwest Side", 57, "Southwest Side", 58, "Southwest Side", 59, "Southwest Side",
  60, "Southwest Side", 61, "Southwest Side", 62, "Southwest Side", 63, "Southwest Side",
  64, "Southwest Side", 65, "Southwest Side", 66, "Southwest Side", 67, "Southwest Side",
  68, "Southwest Side",
  70, "Far Southwest Side", 71, "Far Southwest Side", 72, "Far Southwest Side",
  73, "Far Southwest Side", 74, "Far Southwest Side", 75, "Far Southwest Side"
)

# Final Processing and Cleaning
crashes_clean <- crashes_joined %>%
  # Now filter valid community areas (since we just created them)
  filter(!is.na(community_area)) %>%
  
  # Join with our side mapping
  left_join(community_map, by = "community_area") %>%
  
  # Ensure names are Title Case (e.g., "Rogers Park")
  mutate(community_name = str_to_title(community_name)) %>% 
  
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
    # Create factors for modeling
    # Note: We replace NA sides just in case, though filter handles most
    city_side = replace_na(city_side, "Unknown"),
    city_side_factor = as.factor(city_side),
    injury_category = if_else(injuries_total > 0, "Injury", "No Injury")
  ) %>%
  
  # Remove Unknown locations if any remain
  filter(city_side != "Unknown") %>%
  
  select(
    crash_record_id, crash_date, crash_hour, day_of_week, is_weekend, season,
    latitude, longitude, 
    weather_condition, lighting_condition, roadway_surface_cond,
    posted_speed_limit, prim_contributory_cause,
    # Geographic columns
    community_area, community_name, city_side, city_side_factor,
    injuries_total, injury_category
  )

# Save Data
if(!dir.exists("data")) dir.create("data")
saveRDS(crashes_clean, "data/crashes_clean.rds")

print("Cleaning Complete: Spatial Join and Professional Sides successfully applied!")