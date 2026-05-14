# Epi Pipeline — Shiny Dashboard
# County-level chronic disease + PM2.5 explorer
# Reads from marts.mart_epi_analysis — no DuckDB needed, mart handles performance
#
# Pattern based on RestaurantAnalyticsDashboard:
#   - future/promises for async load
#   - reactable for tables
#   - fresh theming
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

# ── Theme ──────────────────────────────────────────────────────────────────────
# TODO: define color theme — suggest clean light theme for academic feel
# See RestaurantAnalyticsDashboard/app.R for full fresh theme pattern

# ── Startup data load ──────────────────────────────────────────────────────────
# Load most recent year synchronously so UI has data on first render
# Full dataset loads async in background

INIT_DATA <- load_mart_data(year_filter = max_available_year())

# ── UI ────────────────────────────────────────────────────────────────────────

ui <- dashboardPage(
  dashboardHeader(title = "County Health Explorer"),

  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview",         tabName = "overview",  icon = icon("map")),
      menuItem("Exposure Analysis", tabName = "exposure", icon = icon("wind")),
      menuItem("Data Quality",     tabName = "quality",   icon = icon("check-circle"))
    ),

    # TODO: add filter controls
    # selectInput("state_filter", "State", choices = c("All", state_list)),
    # selectInput("year_filter",  "Year",  choices = year_list),
    # selectInput("measure_filter", "Measure", choices = measure_list)
  ),

  dashboardBody(
    # TODO: add fresh theme here
    # use_theme(your_theme),

    tabItems(

      # ── Overview tab ────────────────────────────────────────────────────────
      tabItem(tabName = "overview",
        fluidRow(
          # TODO: value boxes — national median PM2.5, obesity, diabetes, smoking
          # valueBoxOutput("vbox_pm25"),
          # valueBoxOutput("vbox_obesity"),
          # valueBoxOutput("vbox_diabetes")
        ),
        fluidRow(
          box(
            title = "County Summary", width = 12,
            # TODO: reactable county table with search, sort, pagination
            # reactableOutput("county_table")
            uiOutput("loading_banner"),
            reactableOutput("county_table")
          )
        )
      ),

      # ── Exposure Analysis tab ────────────────────────────────────────────────
      tabItem(tabName = "exposure",
        fluidRow(
          box(
            title = "PM2.5 vs. Chronic Disease", width = 8,
            # TODO: scatter plot — ggplot or plotly
            # plotOutput("scatter_pm25")
          ),
          box(
            title = "PM2.5 Distribution", width = 4,
            # TODO: histogram of PM2.5 by state/region
            # plotOutput("pm25_hist")
          )
        ),
        fluidRow(
          box(
            title = "Top Counties by PM2.5", width = 6,
            # TODO: reactable of highest PM2.5 counties with disease rates
          ),
          box(
            title = "Correlation Table", width = 6,
            # TODO: gt or reactable showing PM2.5 correlation with each measure
          )
        )
      ),

      # ── Data Quality tab ─────────────────────────────────────────────────────
      tabItem(tabName = "quality",
        fluidRow(
          box(
            title = "PM2.5 Coverage by State", width = 6,
            # TODO: bar chart — % counties with PM2.5 data per state
          ),
          box(
            title = "Data Completeness", width = 6,
            # TODO: table showing missing values per measure per year
          )
        )
      )
    )
  )
)

# ── Server ────────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

  # Reactive data — filtered by user inputs
  filtered_data <- reactive({
    # TODO: apply state/year/measure filters from sidebar inputs
    INIT_DATA
  })

  # ── Background load: full dataset ──────────────────────────────────────────
  full_data <- reactiveVal(INIT_DATA)

  observe({
    p <- future_promise({
      # TODO: load full dataset (all years) here
      # load_mart_data()
      NULL
    })
    p %...>% full_data()
  })

  # ── Loading banner ──────────────────────────────────────────────────────────
  output$loading_banner <- renderUI({
    # TODO: show/hide based on whether full_data has loaded
    # See RestaurantAnalyticsDashboard for skeleton shimmer pattern
    NULL
  })

  # ── County table ────────────────────────────────────────────────────────────
  output$county_table <- renderReactable({
    # TODO: build reactable from filtered_data()
    # Include: state, county, year, pm25, obesity, diabetes, smoking
    # Add conditional formatting (color scale on pm25, disease rates)
    reactable(filtered_data())
  })

  # ── Value boxes ─────────────────────────────────────────────────────────────
  # TODO: output$vbox_pm25, output$vbox_obesity, output$vbox_diabetes

  # ── Scatter plot ─────────────────────────────────────────────────────────────
  # TODO: output$scatter_pm25 — ggplot scatter with lm trend line

}

shinyApp(ui, server)
