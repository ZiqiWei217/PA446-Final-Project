# Chicago Vision Zero: Interactive Traffic Safety Dashboard

##  Project Overview
This project is an interactive data dashboard developed for **PA 446: Coding for Civic Data Applications**. It supports Chicago’s **"Vision Zero"** initiative, which aims to eliminate traffic fatalities and severe injuries. 
By leveraging open data from the City of Chicago, this dashboard enables residents, urban planners, and policy analysts to visualize crash hotspots, explore temporal trends, and understand how environmental factors (such as weather and lighting) impact road safety.

##  Target Audience
*   **Chicago Residents:** To identify high-risk intersections in their neighborhoods and commute routes.
*   **City Planners & Advocates:** To analyze crash patterns and prioritize infrastructure improvements.

## Data Source

All data is sourced programmatically from the **Chicago Data Portal** via API:

*   **Primary Dataset:** [Traffic Crashes - Crashes](https://data.cityofchicago.org/Transportation/Traffic-Crashes-Crashes/85ca-t3if)
    *   *Update Frequency:* Daily
    *   *Scope:* Focuses on crash data from 2023 to present to ensure relevance and optimize dashboard performance.
    *   *Key Variables:* `CRASH_DATE`, `POSTED_SPEED_LIMIT`, `WEATHER_CONDITION`, `PRIM_CONTRIBUTORY_CAUSE`.

*   **Supplementary Dataset:** [Traffic Crashes - People](https://data.cityofchicago.org/Transportation/Traffic-Crashes-People/u6pd-qa9d)
    *   *Update Frequency:* Daily
    *   *Description:* Details on individuals involved (drivers, passengers, pedestrians, cyclists). Used to determine injury severity and vulnerable road user status.
    *   *Join Key:* `CRASH_RECORD_ID` (One-to-Many relationship with Crashes).

*   **Supplementary Dataset:** [Traffic Crashes - Vehicles](https://data.cityofchicago.org/Transportation/Traffic-Crashes-Vehicles/68nd-jvt3)
    *   *Update Frequency:* Daily
    *   *Description:* Details on the vehicles involved (Type, Make, Model). Used to analyze if larger vehicles (SUVs/Trucks) cause more severe accidents.
    *   *Join Key:* `CRASH_RECORD_ID`

*   **Geographic Context:** [Boundaries - Community Areas (current)](https://data.cityofchicago.org/Facilities-Geographic-Boundaries/Boundaries-Community-Areas-current-/cauq-8yn6)
    *   *Format:* GeoJSON / Shapefile
    *   *Usage:* Used to aggregate crash points into 77 distinct neighborhoods for the interactive map layers and demographic comparison.

## Methodology & Tech Stack
This project is built using **R** and the **Shiny/Quarto** framework. Key steps include:

1.  **Data Acquisition:** Fetched via Socrata Open Data API (`RSocrata`) with strict filtering to manage dataset size.
2.  **Data Wrangling & Spatial Analysis:** * **Spatial Joins:** Utilized the `sf` package to map raw GPS coordinates to official Chicago Community Areas (1-77) and 9 broader City Sides.
    * **Feature Engineering:** Derived temporal features (`Season`, `Weekend_Indicator`) and categorized risk factors to enhance analytical depth.
3.  **Advanced Analysis (Machine Learning):** * **Algorithm:** Implemented an **XGBoost (Gradient Boosting)** model using `tidymodels` to predict the probability of crash injuries.
    * **Optimization:** Applied `scale_pos_weight` parameters to handle class imbalance between injury and non-injury outcomes.
4.  **Visualization & Interaction:** * **Mapping:** Interactive, clustered crash maps using `leaflet`.
    * **Hierarchical Logic:** Implemented cascading user inputs (Region → Neighborhood) for localized risk simulation.
    * **Dynamic Charts:** Trend analysis using `ggplot2` and `plotly`.
