library(shiny)
library(bslib)
library(tidyverse)
library(leaflet)
library(plotly)
library(tidymodels)
library(xgboost)

# Load Data & Model
crashes_clean <- readRDS("data/crashes_clean.rds")

# Load the trained XGBoost model
# Wrapped in tryCatch to prevent app crash if model is missing
xgb_model <- tryCatch({
  readRDS("models/xgboost_model.rds")
}, error = function(e) {
  NULL 
})

# Prepare Data for UI Choices
weather_choices <- unique(crashes_clean$weather_condition)
lighting_choices <- unique(crashes_clean$lighting_condition)

# Create Location Hierarchy (The "Region -> Neighborhood" logic)
location_hierarchy <- crashes_clean %>%
  distinct(city_side, community_name) %>%
  arrange(city_side, community_name)

# Get the list of Major Regions for the first dropdown
side_choices <- unique(location_hierarchy$city_side)

# Define User Interface (UI)
ui <- page_navbar(
  title = "Chicago Vision Zero Dashboard",
  theme = bs_theme(bootswatch = "flatly"), 
  
  # Tab 1: Map Explorer
  nav_panel(
    title = "Map Explorer",
    layout_sidebar(
      sidebar = sidebar(
        width = 300,
        h4("Filters"),
        selectInput("weather_filter", "Weather Condition:", 
                    choices = c("All", as.character(weather_choices)), 
                    selected = "All"),
        selectInput("season_filter", "Season:", 
                    choices = c("All", "Winter", "Spring", "Summer", "Fall"), 
                    selected = "All"),
        hr(),
        p(class = "text-muted", "Note: Showing a random sample of 10,000 points.")
      ),
      # Map Output
      card(
        full_screen = TRUE,
        card_header("Crash Hotspots (Clustered)"),
        leafletOutput("crash_map", height = "600px")
      )
    )
  ),
  
  # Tab 2: Trends Analysis
  nav_panel(
    title = "Trends Analysis",
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Accidents by Hour of Day"),
        plotlyOutput("hour_plot")
      ),
      card(
        card_header("Impact of Weather on Injuries"),
        plotlyOutput("weather_bar_plot")
      )
    )
  ),
  
  # Tab 3: AI Risk Predictor (With Hierarchical Location)
  nav_panel(
    title = "AI Risk Predictor",
    layout_sidebar(
      sidebar = sidebar(
        title = "Simulate Scenario",
        p("Select a location and conditions to predict injury risk."),
        
        # 1. HIERARCHICAL LOCATION SELECTOR
        h5("1. Location"),
        
        # Level 1: Major Region (Used by Model)
        selectInput("pred_side", "Region (City Side):", 
                    choices = side_choices, 
                    selected = side_choices[1]),
        
        # Level 2: Specific Neighborhood (Filters based on Region)
        selectInput("pred_community", "Neighborhood:", 
                    choices = NULL), # Will be updated by Server
        
        hr(),
        
        # 2. ENVIRONMENTAL CONDITIONS
        h5("2. Conditions"),
        sliderInput("pred_hour", "Hour of Day:", min = 0, max = 23, value = 14),
        selectInput("pred_weather", "Weather:", choices = weather_choices, selected = "CLEAR"),
        selectInput("pred_light", "Lighting:", choices = lighting_choices, selected = "DAYLIGHT"),
        selectInput("pred_season", "Season:", choices = c("Winter", "Spring", "Summer", "Fall"), selected = "Summer"),
        sliderInput("pred_speed", "Speed Limit (mph):", min = 10, max = 55, value = 30)
      ),
      
      # Prediction Output Area
      card(
        card_header("XGBoost Model Prediction"),
        div(
          style = "text-align: center; padding: 40px;",
          
          # Dynamic Location Label
          h4("Risk Analysis for:"),
          h3(textOutput("location_label"), style = "color: #7f8c8d; margin-bottom: 20px;"),
          
          # Score Display
          h2("Probability of Injury"),
          h1(textOutput("risk_score"), style = "font-size: 80px; font-weight: bold; color: #2C3E50;"),
          
          # Risk Level Badge
          uiOutput("risk_badge") 
        ),
        hr(),
        p("Note: This model calculates risk based on the regional profile (City Side) and environmental factors.")
      )
    )
  )
)

# Define Server Logic
server <- function(input, output, session) {
  
  # --- Logic for Tab 1: Map ---
  filtered_crashes <- reactive({
    data <- crashes_clean
    if (input$weather_filter != "All") data <- data %>% filter(weather_condition == input$weather_filter)
    if (input$season_filter != "All") data <- data %>% filter(season == input$season_filter)
    if (nrow(data) > 10000) data <- sample_n(data, 10000)
    data
  })
  
  output$crash_map <- renderLeaflet({
    leaflet(filtered_crashes()) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addCircleMarkers(
        lng = ~longitude, lat = ~latitude, radius = 5,
        color = ~ifelse(injury_category == "Injury", "#e74c3c", "#3498db"),
        stroke = FALSE, fillOpacity = 0.7,
        clusterOptions = markerClusterOptions(), 
        popup = ~paste0("<b>Community:</b> ", community_name, "<br>",
                        "<b>Injuries:</b> ", injuries_total)
      )
  })
  
  # Logic for Tab 2: Plots
  output$hour_plot <- renderPlotly({
    p <- crashes_clean %>% count(crash_hour, injury_category) %>%
      ggplot(aes(x = crash_hour, y = n, fill = injury_category)) +
      geom_col(position = "fill") + scale_fill_manual(values = c("#e74c3c", "#3498db")) + theme_minimal()
    ggplotly(p)
  })
  
  output$weather_bar_plot <- renderPlotly({
    top_weather <- crashes_clean %>% count(weather_condition, sort=TRUE) %>% slice(1:5) %>% pull(weather_condition)
    p <- crashes_clean %>% filter(weather_condition %in% top_weather) %>%
      count(weather_condition, injury_category) %>%
      ggplot(aes(x = weather_condition, y = n, fill = injury_category)) +
      geom_col() + coord_flip() + scale_fill_manual(values = c("#e74c3c", "#3498db")) + theme_minimal()
    ggplotly(p)
  })
  
  # Logic for Tab 3: Prediction (Hierarchical)
  # Update Neighborhood choices when Region (Side) changes
  observeEvent(input$pred_side, {
    # Find all communities that belong to the selected side
    communities <- location_hierarchy %>%
      filter(city_side == input$pred_side) %>%
      pull(community_name)
    
    # Update the second dropdown
    updateSelectInput(session, "pred_community", choices = communities)
  })
  
  # Build the prediction data frame
  predict_data <- reactive({
    tibble(
      crash_hour = as.integer(input$pred_hour),
      weather_condition = factor(input$pred_weather, levels = levels(crashes_clean$weather_condition)),
      lighting_condition = factor(input$pred_light, levels = levels(crashes_clean$lighting_condition)),
      season = factor(input$pred_season, levels = c("Winter", "Spring", "Summer", "Fall")),
      posted_speed_limit = as.integer(input$pred_speed),
      is_weekend = factor("Weekday", levels = c("Weekday", "Weekend")), 
      
      # IMPORTANT: Pass the Region (City Side) to the model
      # The user picks a specific community visually, but the model uses the underlying Region logic
      city_side = factor(input$pred_side, levels = levels(crashes_clean$city_side_factor))
    )
  })
  
  # Make Prediction
  prediction_result <- reactive({
    req(xgb_model)
    tryCatch({
      pred <- predict(xgb_model, new_data = predict_data(), type = "prob")
      return(pred$.pred_Injury)
    }, error = function(e) {
      return(0)
    })
  })
  
  # 4. Outputs
  output$location_label <- renderText({
    # Combine the selections for a nice display
    paste0(input$pred_community, ", ", input$pred_side)
  })
  
  output$risk_score <- renderText({
    if(is.null(xgb_model)) return("Model Missing")
    scales::percent(prediction_result(), accuracy = 0.1)
  })
  
  output$risk_badge <- renderUI({
    if(is.null(xgb_model)) return(NULL)
    prob <- prediction_result()
    if(prob > 0.30) {
      span(class = "badge bg-danger", style = "font-size: 20px; padding: 10px;", "HIGH RISK")
    } else if (prob > 0.15) {
      span(class = "badge bg-warning", style = "font-size: 20px; padding: 10px;", "MEDIUM RISK")
    } else {
      span(class = "badge bg-success", style = "font-size: 20px; padding: 10px;", "LOW RISK")
    }
  })
}


shinyApp(ui, server)