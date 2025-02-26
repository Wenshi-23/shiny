library(teal)
library(teal.modules.clinical)
library(teal.modules.general)
library(ggpmisc)
library(ggpp)
library(goftest)
library(random.cdisc.data)
library(ggplot2)
library(sparkline)
library(dplyr)

# Data preparation
data <- teal_data()
data <- within(data, {
  ADSL <- teal.modules.general::rADSL
  ADTTE <- teal.modules.general::rADTTE
  ADLB <- teal.modules.general::rADLB
  
  ADRS <- random.cdisc.data::cadrs %>%
    dplyr::filter(PARAMCD %in% c("BESRSPI", "INVET"))
  
  IRIS <- iris
  MTCARS <- mtcars
  
  # Convert to explicit NA
  ADSL <- df_explicit_na(ADSL)
  ADTTE <- df_explicit_na(ADTTE)
  ADLB <- df_explicit_na(ADLB)
  ADRS <- df_explicit_na(ADRS)
})

datanames <- c("ADSL", "ADTTE", "ADLB", "ADRS", "IRIS", "MTCARS")
datanames(data) <- datanames
join_keys(data) <- default_cdisc_join_keys[datanames]

# Configuration
arm_ref_comp <- list(
  ACTARMCD = list(
    ref = "ARM B",
    comp = c("ARM A", "ARM C")
  ),
  ARM = list(
    ref = "B: Placebo",
    comp = c("A: Drug X", "C: Combination")
  )
)

# Modules configuration
data_table_mod <- tm_data_table(
  label = "Data Review",
  variables_selected = list(
    ADSL = c("STUDYID", "USUBJID", "SUBJID", "SITEID", "AGE", "SEX"),
    ADTTE = c(
      "STUDYID", "USUBJID", "SUBJID", "SITEID",
      "PARAM", "PARAMCD", "ARM", "ARMCD", "AVAL", "CNSR"
    )
  )
)

description_mod <- tm_t_summary(
  label = "Description Table",
  dataname = "ADSL",
  arm_var = choices_selected(c("ARM", "ARMCD"), "ARM"),
  summarize_vars = choices_selected(
    c("SEX", "RACE", "BMRKR2", "EOSDY", "DCSREAS"),
    c("SEX", "RACE")
  ),
  useNA = "ifany"
)

description_by_var_mod <- tm_t_summary_by(
  label = "BDS by Visit",
  dataname = "ADLB",
  arm_var = choices_selected(
    choices = variable_choices(data[["ADSL"]], c("ARM", "ARMCD")),
    selected = "ARM"
  ),
  by_vars = choices_selected(
    choices = variable_choices(data[["ADLB"]], c("PARAM", "AVISIT")),
    selected = c("PARAM", "AVISIT")
  ),
  summarize_vars = choices_selected(
    choices = variable_choices(data[["ADLB"]], c("AVAL")),
    selected = c("AVAL")
  ),
  useNA = "ifany",
  paramcd = choices_selected(
    choices = value_choices(data[["ADLB"]], "PARAMCD", "PARAM"),
    selected = "ALT"
  )
)

tm_outliers_mod1 <- tm_outliers(
  label = "Outliers",
  outlier_var = data_extract_spec(
    dataname = "ADSL",
    select = select_spec(
      label = "Select variable:",
      choices = variable_choices(data[["ADSL"]], c("AGE", "BMRKR1")),
      selected = "AGE",
      fixed = FALSE
    )
  ),
  categorical_var = data_extract_spec(
    dataname = "ADSL",
    select = select_spec(
      label = "Select variables:",
      choices = variable_choices(
        data[["ADSL"]],
        subset = names(Filter(isTRUE, sapply(data[["ADSL"]], is.factor)))
      ),
      selected = "RACE",
      multiple = FALSE,
      fixed = FALSE
    )
  )
)

tte_mod <- tm_t_tte(
  label = "Time To Event Table",
  dataname = "ADTTE",
  arm_var = choices_selected(
    variable_choices(data[["ADSL"]], c("ARM", "ARMCD", "ACTARMCD")),
    "ARM"
  ),
  arm_ref_comp = arm_ref_comp,
  paramcd = choices_selected(
    value_choices(data[["ADTTE"]], "PARAMCD", "PARAM"),
    "OS"
  ),
  strata_var = choices_selected(
    variable_choices(data[["ADSL"]], c("SEX", "BMRKR2")),
    "SEX"
  ),
  time_points = choices_selected(c(6, 8), 6),
  event_desc_var = choices_selected(
    variable_choices(data[["ADTTE"]], "EVNTDESC"),
    "EVNTDESC",
    fixed = TRUE
  )
)

# Initialize app
app <- init(
  data = data,
  modules = modules(
    data_table_mod,
    tm_variable_browser(
      label = "Variable Browser",
      ggplot2_args = teal.widgets::ggplot2_args(labs = list(subtitle = "Plot generated by Variable Browser Module"))
    ),
    tm_g_distribution(
      label = "Distribution",
      dist_var = teal.transform::data_extract_spec(
        dataname = "IRIS",
        select = teal.transform::select_spec(variable_choices("IRIS"), "Petal.Length")
      ),
      ggplot2_args = teal.widgets::ggplot2_args(
        labs = list(subtitle = "Plot generated by Distribution Module")
      )
    ),
    tm_outliers_mod1,
    description_mod,
    description_by_var_mod,
    tte_mod
  ),
  filter = teal_slices(
    teal_slice(dataname = "IRIS", varname = "Species", selected = "setosa")
  ),
  title = build_app_title(title = "My teal app"),
  header = h3("My teal application"),
  footer = tags$div(a("Powered by teal", href = "https://insightsengineering.github.io/teal/latest-tag/"))
)

# Convert teal app to Shiny app and return it
shiny::shinyApp(app$ui, app$server)