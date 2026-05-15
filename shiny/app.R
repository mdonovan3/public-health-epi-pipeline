# Epi Pipeline — Shiny Dashboard
# County-level chronic disease + PM2.5 explorer
# Reads from marts.mart_epi_analysis
#
# Pattern reference: RestaurantAnalyticsDashboard (wlm-shiny project)
#   - fresh theming
#   - future/promises for async background load
#   - reactable + reactablefmtr for tables
#   - skeleton shimmer while loading

library(shiny)
library(shinydashboard)
library(reactable)
library(reactablefmtr)
library(tidyverse)
library(fresh)
library(future)
library(promises)
library(DBI)
library(RPostgres)
library(config)
library(here)

source(here("shiny/functions.R"))
plan(multisession)

cfg <- config::get()

# ── Startup data load ──────────────────────────────────────────────────────────
# Load most recent year on startup so UI has data immediately.
# Full dataset loads async in background (see STEP 13.4 in server).

INIT_DATA <- load_mart_data(year_filter = max_available_year())

# ── Theme ──────────────────────────────────────────────────────────────────────

# [PART 13 · STEP 13.1] Define fresh color theme
# Use create_theme() — clean/academic look suggested
# Apply with use_theme(your_theme) inside dashboardBody()
# See RestaurantAnalyticsDashboard/app.R for full pattern

# ── UI ────────────────────────────────────────────────────────────────────────

ui <- dashboardPage(

  dashboardHeader(title = "County Health Explorer"),

  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview",          tabName = "overview",  icon = icon("map")),
      menuItem("Exposure Analysis", tabName = "exposure",  icon = icon("wind")),
      menuItem("Data Quality",      tabName = "quality",   icon = icon("check-circle"))
    ),

    # [PART 13 · STEP 13.2] Sidebar filter controls
    # Add three selectInput() controls:
    #   state_filter  — choices from sort(unique(INIT_DATA$state_abbr)), include "All"
    #   year_filter   — choices from sort(unique(INIT_DATA$year)), default to max
    #   measure_filter — choices from a named list of the pivoted column names
  ),

  dashboardBody(

    # Apply theme here after completing STEP 13.1
    # use_theme(your_theme),

    tabItems(

      # ── Overview tab ──────────────────────────────────────────────────────────
      tabItem(tabName = "overview",

        fluidRow(
          # [PART 13 · STEP 13.7] Value boxes — national medians
          # valueBoxOutput("vbox_pm25")
          # valueBoxOutput("vbox_obesity")
          # valueBoxOutput("vbox_diabetes")
        ),

        fluidRow(
          box(title = "County Summary", width = 12,
            uiOutput("loading_banner"),
            reactableOutput("county_table")
          )
        )
      ),

      # ── Exposure Analysis tab ──────────────────────────────────────────────────
      tabItem(tabName = "exposure",

        fluidRow(
          box(title = "PM2.5 vs. Chronic Disease", width = 8,
            # [PART 13 · STEP 13.8] Scatter plot
            # plotOutput("scatter_pm25")
          ),
          box(title = "PM2.5 Distribution", width = 4
            # histogram of pm25_annual_mean across counties
            # plotOutput("pm25_hist")
          )
        ),

        fluidRow(
          box(title = "Top Counties by PM2.5", width = 6
            # reactable of highest PM2.5 counties with their disease rates
          ),
          box(title = "Correlations", width = 6
            # table showing PM2.5 correlation with each health measure
          )
        )
      ),

      # ── Data Quality tab ──────────────────────────────────────────────────────
      tabItem(tabName = "quality",

        fluidRow(
          box(title = "PM2.5 Coverage by State", width = 6
            # bar chart — % of counties with PM2.5 data, by state
          ),
          box(title = "Data Completeness", width = 6
            # table — missing value counts per measure per year
          )
        )
      )
    )
  )
)

# ── Server ────────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

  # ── Reactive filtered data ──────────────────────────────────────────────────

  filtered_data <- reactive({

    # [PART 13 · STEP 13.3] Apply sidebar filters to INIT_DATA / full_data()
    # Filter by input$state_filter, input$year_filter, input$measure_filter
    # Return filtered dataframe

    INIT_DATA  # placeholder — replace with filtered version
  })

  # ── Background load: full dataset ──────────────────────────────────────────

  full_data <- reactiveVal(INIT_DATA)

  observe({
    p <- future_promise({

      # [PART 13 · STEP 13.4] Load full dataset (all years) in background
      # load_mart_data()  — no year_filter argument

      NULL  # replace with load_mart_data()
    })
    p %...>% full_data()
  })

  # ── Loading banner ──────────────────────────────────────────────────────────

  output$loading_banner <- renderUI({

    # [PART 13 · STEP 13.5] Show shimmer/banner while full_data is loading
    # Check if full_data() is still the INIT_DATA snapshot
    # Show banner when loading, hide when full_data() is ready
    # See RestaurantAnalyticsDashboard for skeleton shimmer HTML pattern

    NULL
  })

  # ── County table ────────────────────────────────────────────────────────────

  output$county_table <- renderReactable({

    # [PART 13 · STEP 13.6] Build reactable from filtered_data()
    # Columns to show: state_abbr, county_name, year,
    #   pm25_annual_mean, obesity_pct, diabetes_pct, smoking_pct
    # Add color scale formatting on pm25_annual_mean and disease columns
    # Use reactablefmtr color_scales() or color_tiles()

    reactable(filtered_data())  # replace with formatted version
  })

  # ── Value boxes ─────────────────────────────────────────────────────────────

  # [PART 13 · STEP 13.7] National median value boxes
  # output$vbox_pm25     <- renderValueBox({ ... median(filtered_data()$pm25_annual_mean) ... })
  # output$vbox_obesity  <- renderValueBox({ ... median(filtered_data()$obesity_pct) ... })
  # output$vbox_diabetes <- renderValueBox({ ... median(filtered_data()$diabetes_pct) ... })

  # ── Scatter plot ─────────────────────────────────────────────────────────────

  # [PART 13 · STEP 13.8] PM2.5 vs. selected outcome scatter
  # output$scatter_pm25 <- renderPlot({
  #   ggplot(filtered_data() %>% filter(!is.na(pm25_annual_mean)),
  #          aes(x = pm25_annual_mean, y = .data[[input$measure_filter]])) +
  #     geom_point(alpha = 0.4) +
  #     geom_smooth(method = "lm") +
  #     labs(x = "PM2.5 Annual Mean", y = input$measure_filter)
  # })

}

shinyApp(ui, server)
