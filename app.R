###############################################################################
# ViT Scholarly Atlas - Interactive Shiny Dashboard
# Inspired by Flash-Freeze-Solution-Dashboard/app.R structure
# Author: GPT-5.1 Codex
# Last Updated: 2025-11-19
###############################################################################

##############################
# 1. Load Required Packages  #
##############################

library(shiny)
library(bslib)
library(shinyWidgets)
library(dplyr)
library(tidyr)
library(readxl)
library(stringr)
library(forcats)
library(scales)
library(plotly)
library(DT)
library(wordcloud2)
library(purrr)

############################################
# 2. Data Loading & Feature Engineering    #
############################################

read_excel_safely <- function(path) {
  tryCatch(
    readxl::read_excel(path),
    error = function(e) {
      stop("Failed to read Excel file: ", path, "\nError: ", e$message)
    }
  )
}

coerce_columns <- function(df, cols) {
  for (col in cols) {
    if (col %in% names(df)) {
      df[[col]] <- as.character(df[[col]])
    }
  }
  df
}

prepare_vit_data <- function() {
  message("Loading ViT scholarly data...")
  
  df_1 <- read_excel_safely("savedrecs (1).xls")
  df_2 <- read_excel_safely("savedrecs (2).xls")
  
  harmonize_cols <- c("Volume", "Issue", "Start Page", "End Page", "Supplement", "DOI")
  df_1 <- coerce_columns(df_1, harmonize_cols)
  df_2 <- coerce_columns(df_2, harmonize_cols)
  
  df <- bind_rows(df_1, df_2)
  
  # basic cleaning
  df <- df %>%
    mutate(
      `Publication Year` = suppressWarnings(as.numeric(`Publication Year`)),
      `Times Cited, WoS Core` = suppressWarnings(as.numeric(`Times Cited, WoS Core`)),
      `Document Type` = if_else(is.na(`Document Type`), "Unknown", `Document Type`),
      `Source Title` = if_else(is.na(`Source Title`), "Unknown", `Source Title`)
    ) %>%
    mutate(
      `Times Cited, WoS Core` = replace_na(`Times Cited, WoS Core`, 0),
      Record_ID = row_number()
    )
  
  # remove columns with >50% missing (same rule as Rmd) & duplicates
  na_ratio <- colMeans(is.na(df))
  cols_to_keep <- names(na_ratio[na_ratio <= 0.5])
  df <- df %>%
    select(all_of(cols_to_keep)) %>%
    distinct()
  
  # author count feature
  df <- df %>%
    mutate(
      Author_Count = case_when(
        !is.na(Authors) ~ str_count(Authors, ";") + 1,
        TRUE ~ NA_real_
      )
    )
  
  # countries expansion (optional if field exists)
  country_field <- "Countries/Regions"
  has_country <- country_field %in% names(df)
  country_long <- NULL
  if (has_country) {
    country_long <- df %>%
      select(Record_ID, !!sym(country_field)) %>%
      filter(!is.na(!!sym(country_field))) %>%
      separate_rows(!!sym(country_field), sep = ";") %>%
      mutate(Country = str_trim(!!sym(country_field))) %>%
      filter(Country != "") %>%
      count(Country, sort = TRUE, name = "Count")
  }
  
  # keyword expansion
  ab_field <- "Abstract"
  keywords_long <- df %>%
    select(Record_ID, !!sym(ab_field)) %>%
    mutate(Abstract_clean = tolower(replace_na(!!sym(ab_field), ""))) %>%
    separate_rows(Abstract_clean, sep = "\\W+") %>%
    rename(Keyword = Abstract_clean) %>%
    mutate(
      Keyword = str_trim(Keyword),
      Keyword = str_replace_all(Keyword, "[^a-z]", "")
    ) %>%
    filter(
      Keyword != "",
      nchar(Keyword) >= 4
    )
  
  stop_words <- c(
    "the","and","of","with","for","on","to","in","a","an","by","from",
    "this","that","these","those","we","our","their","its","it","as","is",
    "are","was","were","be","been","being","into","using","based","via",
    "have","has","had","having","do","does","did","done","doing",
    "paper","study","result","results","method","methods","approach","approaches",
    "analysis","model","models","system","systems","performance","data","task",
    "tasks","effect","effects","application","applications","research","algorithm",
    "algorithms","new","novel","proposed","framework","improvement","improvements",
    "network","networks","deep","learning","machine","artificial","intelligence",
    "can","may","also","one","two","three","first","second","third","used",
    "use","using","show","shows","shown","present","presents","presented",
    "respectively","however","therefore","thus","which","where","when","while",
    "each","both","such","between","among","through","during","over","under",
    "than","more","most","other","some","only","then","even","well","much",
    "different","same","high","low","large","small","good","better","best",
    "various","compared","work","works","found","further","current","like",
    "time","times","power","powers","rate","rates","higher","lower",
    "potential","features","feature","activity","activities","structure","structures",
    "process","processes","technique","techniques","properties","property",
    "parameters","parameter","optimization","optimizations","studies","images",
    "image","detection","detections","accuracy","accuracies","surface","surfaces",
    "temperature","temperatures","obtained","obtain","obtaining","observed",
    "observe","observing","showed","developed","develop","developing","very",
    "will","area","ratio","loss","moreover","error","many","real","could",
    "terms","presence","size","load","flow","test","human","cells","multi",
    "form","free","less","hence","genes","metal","voltage","solution","after",
    "major","linear","there","studied","oxide","nature","fuel","cost","soil",
    "anti","heat","hybrid","gate","electron","along","thermal",
    "carried","carry","carries","performed","perform","performs","demonstrated",
    "demonstrate","demonstrates","indicated","indicate","indicates","revealed",
    "reveal","reveals","suggested","suggest","suggests","achieved","achieve",
    "achieves","significant","significantly","existing","experimental","effective",
    "effectively","important","importantly","successful","successfully","efficient",
    "efficiently","differently","similarly","worse","worst",
    "number","numbers","order","orders","field","fields","conditions","condition",
    "increase","increases","information","informations","treatment","treatments",
    "control","controls","design","designs","review","reviews","maximum","maxima",
    "minimum","minima","value","values","level","levels","addition","additions",
    "role","roles","concentration","concentrations","degrees","degree","against",
    "water","waters","state","states","phase","phases","energy","energies"
  )
  
  keywords_long <- keywords_long %>%
    filter(!Keyword %in% stop_words)
  
  keyword_summary <- keywords_long %>%
    count(Keyword, sort = TRUE, name = "Frequency")
  
  keyword_trend <- keywords_long %>%
    inner_join(df %>% select(Record_ID, Publication_Year = `Publication Year`), by = "Record_ID") %>%
    filter(!is.na(Publication_Year)) %>%
    count(Publication_Year, Keyword, name = "Count")
  
  list(
    records = df,
    keyword_tokens = keywords_long,
    keyword_summary = keyword_summary,
    keyword_trend = keyword_trend,
    country_summary = country_long
  )
}

vit_data <- prepare_vit_data()

############################################
# 3. UI Definition                         #
############################################

ui <- page_navbar(
  title = div(
    icon("chart-line"),
    "ViT Scholarly Atlas",
    style = "font-weight: 700;"
  ),
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#2563eb",
    secondary = "#1d4ed8",
    success = "#22c55e",
    warning = "#f97316",
    info = "#0ea5e9",
    light = "#f8fafc",
    dark = "#0f172a",
    base_font = "Segoe UI"
  ),
  header = tags$head(
    tags$style(HTML("
      :root {
        --atlas-indigo: #1d4ed8;
        --atlas-purple: #7c3aed;
        --atlas-cyan: #06b6d4;
        --atlas-bg: #eef2ff;
        --atlas-card: rgba(255,255,255,0.95);
      }
      body {
        background: linear-gradient(135deg, #eef2ff 0%, #e0f2fe 35%, #fef3c7 100%);
        color: #0f172a;
      }
      .navbar {
        background: linear-gradient(90deg, #1d4ed8 0%, #1e3a8a 60%, #7c3aed 100%);
        border-bottom: none;
        box-shadow: 0 12px 28px rgba(15,23,42,0.35);
      }
      .navbar .navbar-brand, .navbar .nav-link {
        color: #f8fafc !important;
        font-weight: 600;
        letter-spacing: 0.4px;
      }
      .navbar .nav-link.active {
        color: #ffffff !important;
        border-bottom: 2px solid #22d3ee;
      }
      .bslib-value-box {
        border-radius: 18px;
        border: none;
        color: #fff;
        background: linear-gradient(135deg, #1d4ed8 0%, #0ea5e9 100%);
        box-shadow: 0 15px 35px rgba(37,99,235,0.35);
      }
      .bslib-value-box:nth-child(2) {
        background: linear-gradient(135deg, #16a34a 0%, #22d3ee 100%);
      }
      .bslib-value-box:nth-child(3) {
        background: linear-gradient(135deg, #f97316 0%, #facc15 100%);
      }
      .bslib-value-box:nth-child(4) {
        background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
      }
      .bslib-value-box .value-box-showcase i {
        font-size: 34px;
        opacity: 0.75;
      }
      .bslib-sidebar-layout > .sidebar {
        background: linear-gradient(180deg, rgba(15,23,42,0.95) 0%, rgba(30,41,59,0.95) 100%);
        border-right: none;
        color: #e2e8f0;
        box-shadow: 10px 0 25px rgba(15,23,42,0.18);
      }
      .bslib-sidebar-layout > .sidebar label,
      .bslib-sidebar-layout > .sidebar .form-label {
        color: #cbd5f5;
        font-weight: 600;
        text-transform: uppercase;
        font-size: 12px;
        letter-spacing: 0.5px;
      }
      .bslib-sidebar-layout .form-control,
      .bslib-sidebar-layout .selectpicker,
      .bslib-sidebar-layout .bs-searchbox input {
        background: rgba(255,255,255,0.08);
        color: #f8fafc;
        border: 1px solid rgba(248,250,252,0.25);
        border-radius: 12px;
      }
      .bslib-sidebar-layout .form-control:focus,
      .bslib-sidebar-layout .bs-searchbox input:focus {
        border-color: rgba(14,165,233,0.9);
        box-shadow: 0 0 0 1px rgba(14,165,233,0.5);
      }
      .irs--shiny .irs-bar,
      .irs--shiny .irs-single,
      .irs--shiny .irs-handle>i:first-child {
        background: linear-gradient(90deg, #22d3ee, #7c3aed);
        border-color: transparent;
      }
      .bslib-sidebar-layout > .sidebar hr {
        border-color: rgba(255,255,255,0.12);
      }
      .btn-primary {
        border-radius: 999px;
        font-weight: 600;
        border: none;
        box-shadow: 0 10px 20px rgba(37,99,235,0.4);
      }
      .btn-primary:hover {
        transform: translateY(-1px);
        box-shadow: 0 12px 22px rgba(37,99,235,0.5);
      }
      .card {
        border-radius: 18px;
        border: none;
        background: var(--atlas-card);
        box-shadow: 0 20px 45px rgba(15,23,42,0.12);
        backdrop-filter: blur(6px);
      }
      .card-header {
        border-bottom: none;
        font-weight: 700;
        font-size: 16px;
        color: #0f172a;
        letter-spacing: 0.3px;
      }
      .card-header i {
        background: linear-gradient(135deg, #1d4ed8, #22d3ee);
        color: #fff;
        padding: 6px 8px;
        border-radius: 10px;
        margin-right: 8px;
      }
      .plotly.html-widget {
        border-radius: 16px;
        background: #f8fafc;
        padding: 8px;
      }
      .nav-link .icon {
        margin-right: 6px;
      }
      .value-box-value {
        font-size: 32px;
      }
    "))
  ),
  sidebar = sidebar(
    width = 300,
    h4(icon("filter"), " Global Filters"),
    sliderInput(
      "year_range",
      label = "Publication Year",
      min = min(vit_data$records$`Publication Year`, na.rm = TRUE),
      max = max(vit_data$records$`Publication Year`, na.rm = TRUE),
      value = range(vit_data$records$`Publication Year`, na.rm = TRUE),
      sep = ""
    ),
    pickerInput(
      "doc_types",
      label = "Document Type",
      choices = sort(unique(vit_data$records$`Document Type`)),
      selected = unique(vit_data$records$`Document Type`),
      multiple = TRUE,
      options = pickerOptions(actionsBox = TRUE, liveSearch = TRUE)
    ),
    sliderInput(
      "citation_range",
      label = "Times Cited (WoS Core)",
      min = 0,
      max = ceiling(max(vit_data$records$`Times Cited, WoS Core`, na.rm = TRUE)),
      value = c(0, ceiling(max(vit_data$records$`Times Cited, WoS Core`, na.rm = TRUE))),
      step = 5
    ),
    actionButton(
      "reset_filters",
      label = tagList(icon("undo"), "Reset Filters"),
      class = "btn btn-primary w-100 mt-2"
    ),
    hr(),
    tags$div(
      class = "alert alert-info",
      icon("info-circle"), HTML("<b>Dataset:</b> 2,000 ViT papers from WoS<br><b>Updated:</b> 2025-11-19")
    )
  ),
  nav_panel(
    title = tagList(icon("dashboard"), "Overview"),
    layout_columns(
      value_box(
        title = "Total Publications",
        value = textOutput("kpi_total_pubs"),
        showcase = icon("layer-group"),
        theme = "primary"
      ),
      value_box(
        title = "Avg Citations",
        value = textOutput("kpi_avg_citations"),
        showcase = icon("star"),
        theme = "success"
      ),
      value_box(
        title = "Multi-author Share",
        value = textOutput("kpi_multi_author"),
        showcase = icon("users"),
        theme = "warning"
      ),
      value_box(
        title = "Median Year",
        value = textOutput("kpi_median_year"),
        showcase = icon("calendar"),
        theme = "info"
      )
    ),
    layout_columns(
      col_widths = c(7, 5),
      card(
        card_header(icon("chart-area"), "Annual Publication Trend"),
        card_body(plotlyOutput("annual_trend_plot", height = "400px"))
      ),
      card(
        card_header(icon("newspaper"), "Top 15 Journals"),
        card_body(plotlyOutput("top_journals_plot", height = "400px"))
      )
    ),
    br(),
    card(
      card_header(icon("chart-bar"), "Citation Distribution (Histogram + Density)"),
      card_body(plotlyOutput("citation_distribution_plot", height = "420px"))
    )
  ),
  nav_panel(
    title = tagList(icon("font"), "Keyword Intelligence"),
    layout_columns(
      col_widths = c(6,6),
      card(
        card_header(icon("tags"), "Top Keywords"),
        card_body(plotlyOutput("keyword_bar_plot", height = "400px"))
      ),
      card(
        card_header(icon("cloud"), "Keyword Word Cloud"),
        card_body(wordcloud2Output("keyword_wordcloud", height = "400px"))
      )
    ),
    br(),
    card(
      card_header(icon("timeline"), "Keyword Temporal Evolution"),
      card_body(plotlyOutput("keyword_trend_plot", height = "450px"))
    )
  ),
  nav_panel(
    title = tagList(icon("people-arrows"), "Collaboration"),
    layout_columns(
      col_widths = c(6,6),
      card(
        card_header(icon("chart-pie"), "Author Collaboration Breakdown"),
        card_body(plotlyOutput("collab_pie_plot", height = "400px"))
      ),
      card(
        card_header(icon("chart-bar"), "Authors per Paper Distribution"),
        card_body(plotlyOutput("collab_hist_plot", height = "400px"))
      )
    )
  ),
  nav_panel(
    title = tagList(icon("project-diagram"), "Impact Clusters"),
    card(
      card_header(icon("braille"), "K-means Clusters (Year vs Citations vs Authors)"),
      card_body(plotlyOutput("cluster_plot", height = "500px"))
    ),
    br(),
    card(
      card_header(icon("info-circle"), "Cluster Personas & Notes"),
      card_body(uiOutput("cluster_notes"))
    )
  ),
  nav_panel(
    title = tagList(icon("table"), "Data Explorer"),
    card(
      card_header(icon("table-list"), "Raw Records"),
      card_body(DTOutput("records_table"))
    )
  )
)

############################################
# 4. Server Logic                          #
############################################

server <- function(input, output, session) {
  observeEvent(input$reset_filters, {
    updateSliderInput(
      session, "year_range",
      value = range(vit_data$records$`Publication Year`, na.rm = TRUE)
    )
    updatePickerInput(
      session, "doc_types",
      selected = unique(vit_data$records$`Document Type`)
    )
    updateSliderInput(
      session, "citation_range",
      value = c(0, ceiling(max(vit_data$records$`Times Cited, WoS Core`, na.rm = TRUE)))
    )
  })
  
  filtered_records <- reactive({
    req(input$year_range, input$doc_types, input$citation_range)
    vit_data$records %>%
      filter(
        !is.na(`Publication Year`),
        between(`Publication Year`, input$year_range[1], input$year_range[2]),
        `Document Type` %in% input$doc_types,
        between(`Times Cited, WoS Core`, input$citation_range[1], input$citation_range[2])
      )
  })
  
  filtered_keywords <- reactive({
    req(filtered_records())
    vit_data$keyword_tokens %>%
      filter(Record_ID %in% filtered_records()$Record_ID)
  })
  
  # ========== KPIs ==========
  output$kpi_total_pubs <- renderText({
    format(nrow(filtered_records()), big.mark = ",")
  })
  
  output$kpi_avg_citations <- renderText({
    avg <- filtered_records() %>%
      summarise(val = mean(`Times Cited, WoS Core`, na.rm = TRUE)) %>%
      pull(val)
    sprintf("%.1f", avg)
  })
  
  output$kpi_multi_author <- renderText({
    df <- filtered_records()
    if (nrow(df) == 0 || all(is.na(df$Author_Count))) return("0%")
    share <- df %>%
      mutate(flag = Author_Count >= 3) %>%
      summarise(pct = mean(flag, na.rm = TRUE) * 100) %>%
      pull(pct)
    paste0(sprintf("%.1f", share), "%")
  })
  
  output$kpi_median_year <- renderText({
    med <- median(filtered_records()$`Publication Year`, na.rm = TRUE)
    if (is.na(med)) "NA" else format(med, trim = TRUE)
  })
  
  # ========== Plots ==========
  output$annual_trend_plot <- renderPlotly({
    df <- filtered_records() %>%
      count(`Publication Year`, name = "Count") %>%
      arrange(`Publication Year`)
    if (nrow(df) == 0) return(plotly_empty())
    p <- ggplot(df, aes(x = `Publication Year`, y = Count)) +
      geom_line(color = "#2155CD", linewidth = 1.8) +
      geom_point(color = "#0f172a", size = 3.2) +
      geom_smooth(method = "loess", se = FALSE, color = "#f97316", linetype = "dashed", linewidth = 1) +
      scale_y_continuous(labels = comma, expand = expansion(mult = c(0.05, 0.1))) +
      labs(
        title = "Annual Publication Trend",
        subtitle = "Orange dashed line: LOESS smoothing",
        x = "Publication Year",
        y = "Publications"
      ) +
      theme_minimal(base_size = 13) +
      theme(
        plot.title = element_text(face = "bold"),
        plot.subtitle = element_text(color = "#475569"),
        axis.title = element_text(face = "bold")
      )
    ggplotly(p, tooltip = c("x", "y"))
  })
  
  output$top_journals_plot <- renderPlotly({
    df <- filtered_records() %>%
      count(`Source Title`, sort = TRUE, name = "Count") %>%
      head(15) %>%
      mutate(
        Abbrev = str_to_upper(str_replace_all(`Source Title`, "[^A-Za-z ]", "")),
        Abbrev = str_squish(Abbrev),
        Abbrev = map_chr(str_split(Abbrev, "\\s+"), ~ paste0(str_sub(.x, 1, 1), collapse = "")),
        Abbrev = if_else(nchar(Abbrev) >= 2, Abbrev, str_trunc(`Source Title`, 12))
      )
    if (nrow(df) == 0) return(plotly_empty())
    plot_ly(
      df,
      y = ~reorder(Abbrev, Count),
      x = ~Count,
      type = "bar",
      orientation = "h",
      marker = list(color = "#14b8a6"),
      text = ~Count,
      textposition = "outside",
      hovertemplate = "<b>%{customdata}</b><br>Publications: %{x}<extra></extra>",
      customdata = ~`Source Title`
    ) %>%
      layout(
        yaxis = list(title = "", tickfont = list(size = 11)),
        xaxis = list(title = "Publications"),
        margin = list(l = 170, r = 40)
      )
  })
  
  output$citation_distribution_plot <- renderPlotly({
    df <- filtered_records()
    if (nrow(df) == 0) return(plotly_empty())
    max_cit <- quantile(df$`Times Cited, WoS Core`, 0.95, na.rm = TRUE)
    hist_data <- df %>% filter(`Times Cited, WoS Core` <= max_cit)
    p <- ggplot(hist_data, aes(x = `Times Cited, WoS Core`)) +
      geom_histogram(fill = "#fd7e14", color = "white", bins = 40, alpha = 0.8) +
      geom_density(aes(y = after_stat(count)), color = "#e83e8c", linewidth = 1, alpha = 0.5) +
      theme_minimal() +
      labs(x = "Times Cited (<=95% quantile)", y = "Publications")
    ggplotly(p, tooltip = c("x", "y"))
  })
  
  output$keyword_bar_plot <- renderPlotly({
    df <- filtered_keywords() %>%
      count(Keyword, sort = TRUE, name = "Frequency") %>%
      head(20) %>%
      mutate(Keyword = fct_reorder(Keyword, Frequency))
    validate(need(nrow(df) > 0, "No keywords available"))
    p <- ggplot(df, aes(x = Keyword, y = Frequency)) +
      geom_col(fill = "#6f42c1", alpha = 0.85) +
      coord_flip() +
      theme_minimal() +
      labs(x = NULL, y = "Frequency")
    ggplotly(p, tooltip = c("y", "x"))
  })
  
  output$keyword_wordcloud <- renderWordcloud2({
    df <- filtered_keywords() %>%
      count(Keyword, sort = TRUE, name = "Frequency") %>%
      head(220)
    validate(
      need(nrow(df) > 0, "No keywords available")
    )
    palette_cols <- RColorBrewer::brewer.pal(8, "Pastel1")
    wordcloud2(
      df,
      size = 0.45,
      minSize = 1,
      color = rep_len(palette_cols, nrow(df)),
      backgroundColor = "transparent",
      shuffle = TRUE
    )
  })
  
  output$keyword_trend_plot <- renderPlotly({
    top_kw <- filtered_keywords() %>%
      count(Keyword, sort = TRUE, name = "Freq") %>%
      head(8) %>%
      pull(Keyword)
    df <- filtered_keywords() %>%
      filter(Keyword %in% top_kw) %>%
      inner_join(filtered_records() %>% select(Record_ID, Year = `Publication Year`), by = "Record_ID") %>%
      filter(!is.na(Year)) %>%
      count(Year, Keyword, name = "Count")
    if (nrow(df) == 0) return(plotly_empty())
    p <- ggplot(df, aes(x = Year, y = Count, color = Keyword)) +
      geom_line(linewidth = 1.4, alpha = 0.85) +
      geom_point(size = 2.6, alpha = 0.9) +
      geom_smooth(method = "loess", se = FALSE, linetype = "dashed", linewidth = 0.9, alpha = 0.6) +
      labs(
        title = "High-frequency Keyword Trajectories",
        subtitle = "Top 8 keywords with LOESS fit",
        x = "Year",
        y = "Frequency",
        color = "Keyword"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        legend.position = "right",
        plot.title = element_text(face = "bold"),
        plot.subtitle = element_text(color = "#475569")
      )
    ggplotly(p, tooltip = c("x", "y", "color"))
  })
  
  output$collab_pie_plot <- renderPlotly({
    df <- filtered_records() %>%
      filter(!is.na(Author_Count)) %>%
      mutate(
        group = case_when(
          Author_Count == 1 ~ "Single",
          Author_Count <= 3 ~ "2-3 Authors",
          Author_Count <= 5 ~ "4-5 Authors",
          Author_Count <= 10 ~ "6-10 Authors",
          TRUE ~ "10+ Authors"
        )
      ) %>%
      count(group, name = "Count")
    if (nrow(df) == 0) return(plotly_empty())
    plot_ly(
      df,
      labels = ~group,
      values = ~Count,
      type = "pie",
      textinfo = "label+percent"
    )
  })
  
  output$collab_hist_plot <- renderPlotly({
    df <- filtered_records() %>% filter(!is.na(Author_Count))
    if (nrow(df) == 0) return(plotly_empty())
    counts <- df %>% count(Author_Count)
    mean_auth <- weighted.mean(counts$Author_Count, counts$n)
    median_auth <- median(df$Author_Count)
    p <- ggplot(counts, aes(x = Author_Count, y = n)) +
      geom_area(fill = alpha("#67e8f9", 0.6), color = "#06b6d4", linewidth = 1.1) +
      geom_point(color = "#0f172a", size = 2.2) +
      geom_line(color = "#0f172a", linewidth = 1) +
      geom_vline(xintercept = mean_auth, color = "#ff4d4f", linetype = "dashed", linewidth = 1) +
      geom_vline(xintercept = median_auth, color = "#ffa940", linetype = "dashed", linewidth = 1) +
      annotate(
        "text",
        x = mean_auth,
        y = Inf,
        label = paste0("Mean: ", round(mean_auth, 1)),
        vjust = 1.5,
        hjust = -0.1,
        color = "#ff4d4f",
        fontface = "bold",
        size = 3
      ) +
      annotate(
        "text",
        x = median_auth,
        y = Inf,
        label = paste0("Median: ", median_auth),
        vjust = 3,
        hjust = -0.1,
        color = "#ffa940",
        fontface = "bold",
        size = 3
      ) +
      theme_minimal() +
      labs(
        x = "Authors per Paper",
        y = "Publication Count",
        subtitle = "Red dashed line = mean, Orange dashed line = median"
      )
    ggplotly(p, tooltip = c("x", "y"))
  })
  
  cluster_summary <- reactive({
    filtered_records() %>%
      filter(
        !is.na(`Publication Year`),
        !is.na(`Times Cited, WoS Core`),
        !is.na(Author_Count)
      ) %>%
      mutate(
        Year = `Publication Year`,
        Citations = `Times Cited, WoS Core`
      ) %>%
      { df <- .
        if (nrow(df) < 4) return(NULL)
        k_input <- min(3, max(2, nrow(df) - 1))
        features <- df %>%
          transmute(
            Year_z = scale(Year)[,1],
            Cit_z = scale(Citations)[,1],
            Author_z = scale(Author_Count)[,1]
          )
        km <- kmeans(features, centers = k_input, nstart = 25)
        df <- df %>% mutate(Cluster = factor(km$cluster))
        list(data = df, summary = df %>%
               group_by(Cluster) %>%
               summarise(
                 Count = n(),
                 Avg_Year = mean(Year),
                 Avg_Citations = mean(Citations),
                 Avg_Authors = mean(Author_Count),
                 .groups = "drop"
               ) %>%
               mutate(
                 Persona = case_when(
                   Avg_Citations >= quantile(Avg_Citations, 0.75) ~ "High-impact collaborative",
                   Avg_Year >= quantile(Avg_Year, 0.75) ~ "Emerging potential",
                   Avg_Authors <= quantile(Avg_Authors, 0.25) ~ "Lean exploration",
                   TRUE ~ "Steady growers"
                 )
               ))
      }
  })

  output$cluster_plot <- renderPlotly({
    df <- filtered_records() %>%
      filter(
        !is.na(`Publication Year`),
        !is.na(`Times Cited, WoS Core`),
        !is.na(Author_Count)
      )
    if (nrow(df) < 4) {
      return(plotly_empty(type = "scatter", mode = "markers") %>% layout(title = "Not enough data"))
    }
    cluster_obj <- cluster_summary()
    if (is.null(cluster_obj)) {
      return(plotly_empty(type = "scatter", mode = "markers") %>% layout(title = "Not enough data"))
    }
    df <- cluster_obj$data %>%
      mutate(
        Year_jitter = `Publication Year` + runif(n(), -0.4, 0.4),
        Cit_jitter = `Times Cited, WoS Core` + runif(n(), -3, 3),
        Auth_jitter = Author_Count + runif(n(), -0.3, 0.3)
      )
    colors <- RColorBrewer::brewer.pal(4, "Set2")
    plt <- plot_ly(
      df,
      x = ~Year_jitter,
      y = ~Cit_jitter,
      z = ~Auth_jitter,
      color = ~Cluster,
      colors = colors,
      type = "scatter3d",
      mode = "markers",
      marker = list(size = 2.1, opacity = 0.8, line = list(width = 0))
    )

    box_data <- df %>%
      group_by(Cluster) %>%
      summarise(
        xmin = min(Year_jitter),
        xmax = max(Year_jitter),
        ymin = min(Cit_jitter),
        ymax = max(Cit_jitter),
        .groups = "drop"
      )

    for (i in seq_len(nrow(box_data))) {
      row <- box_data[i,]
      df_cluster <- df %>% filter(Cluster == row$Cluster)
      if (nrow(df_cluster) < 4) next
      loess_fit <- try(
        loess(Auth_jitter ~ Year_jitter * Cit_jitter, data = df_cluster, span = 0.75),
        silent = TRUE
      )
      if (inherits(loess_fit, "try-error")) next
      grid_x <- seq(row$xmin, row$xmax, length.out = 15)
      grid_y <- seq(row$ymin, row$ymax, length.out = 15)
      grid <- expand.grid(Year_jitter = grid_x, Cit_jitter = grid_y)
      pred <- predict(loess_fit, grid)
      if (all(is.na(pred))) next
      z_mat <- matrix(pred, nrow = length(grid_x), ncol = length(grid_y))
      color_hex <- colors[as.integer(row$Cluster)]
      plt <- plt %>% add_surface(
        x = grid_x,
        y = grid_y,
        z = z_mat,
        opacity = 0.4,
        showscale = FALSE,
        name = paste("Cluster", row$Cluster, "surface"),
        inherit = FALSE,
        surfacecolor = matrix(1, length(grid_x), length(grid_y)),
        colorscale = list(c(0, color_hex), c(1, color_hex)),
        hoverinfo = "skip"
      )
    }

    plt %>%
      layout(
        scene = list(
          xaxis = list(title = "Year"),
          yaxis = list(title = "Citations"),
          zaxis = list(title = "Authors")
        ),
        legend = list(title = list(text = "Cluster"))
      )
  })

  output$cluster_notes <- renderUI({
    cs <- cluster_summary()
    if (is.null(cs)) return(tags$em("Not enough samples to derive cluster notes."))
    items <- cs$summary %>%
      mutate(
        text = paste0(
          "Cluster ", Cluster, " · ", Persona,
          ": avg year ", round(Avg_Year, 1),
          ", avg citations ", round(Avg_Citations, 1),
          ", avg authors ", round(Avg_Authors, 1)
        )
      ) %>%
      pull(text)
    tags$ul(
      lapply(items, function(x) tags$li(x))
    )
  })
  
  output$records_table <- renderDT({
    df <- filtered_records() %>%
      select(
        Year = `Publication Year`,
        Document_Type = `Document Type`,
        Source = `Source Title`,
        Title,
        Authors,
        Citations = `Times Cited, WoS Core`
      )
    datatable(
      df,
      options = list(pageLength = 15, scrollX = TRUE),
      filter = "top",
      rownames = FALSE
    )
  })
}

############################################
# 5. Run App                               #
############################################

shinyApp(ui, server)

