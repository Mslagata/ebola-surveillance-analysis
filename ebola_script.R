# =====================================================================
# Ebola (Bundibugyo virus disease) outbreak, DRC 2026
# Descriptive surveillance analysis: weekly epicurve and CFR
# Data: INSP DRC situation reports, via INRB-UMIE/BDBV2026-Data (GitHub)
# Author: Jackline Lagat
# =====================================================================
#
# BEFORE YOU RUN:
#   1. Open your RStudio project (ebola-surveillance-analysis).
#   2. Put the CSV files in a folder called "data" inside the project.
#   3. Click "Source" (or Ctrl + Shift + Enter) to run everything.
# =====================================================================


# ---- STEP 1: Install and load packages ------------------------------
# Run the install line ONCE only (remove the # to run it), then add the # back.
# install.packages(c("tidyverse", "lubridate"))

library(tidyverse)   # data cleaning (dplyr), reading files (readr), charts (ggplot2)
library(lubridate)   # working with dates

dir.create("figures", showWarnings = FALSE)   # folder for saving charts


# ---- STEP 2: Load the data (treat "ND" as missing) -----------------
# ND = "not reported". It is NOT zero, so we tell R to read it as NA (missing).
cases <- read_csv("data/insp_sitrep__national_cumulative_confirmed_cases__daily.csv",
                  na = c("", "NA", "ND"))

deaths <- read_csv("data/insp_sitrep__national_cumulative_confirmed_deaths__daily.csv",
                   na = c("", "NA", "ND"))

# Look at the first rows to check the data loaded properly
head(cases)
head(deaths)


# ---- STEP 3: Data quality check -------------------------------------
# How many report dates are there, and how many values are missing (ND)?
cat("Number of report dates (cases): ", nrow(cases), "\n")
cat("Missing / not reported (cases): ", sum(is.na(cases$national_cumulative_confirmed_cases)), "\n")
cat("Missing / not reported (deaths):", sum(is.na(deaths$national_cumulative_confirmed_deaths)), "\n")
cat("First report:", format(min(cases$date)), " Last report:", format(max(cases$date)), "\n")


# ---- STEP 4: Clean and join cases + deaths into one table -----------
ebola <- cases %>%
  full_join(deaths, by = c("nom", "date")) %>%          # join by place and date
  rename(cum_cases  = national_cumulative_confirmed_cases,
         cum_deaths = national_cumulative_confirmed_deaths) %>%
  mutate(date = as.Date(date)) %>%
  arrange(date)

head(ebola)


# ---- STEP 5: Convert cumulative totals into WEEKLY new cases --------
# The data are running totals. Reports are not published every day, so:
#   (a) group report dates into weeks (starting Monday)
#   (b) take the last (highest) running total reported in each week
#   (c) new cases this week = this week's total - last week's total
weekly <- ebola %>%
  mutate(week = floor_date(date, unit = "week", week_start = 1)) %>%
  group_by(week) %>%
  summarise(cum_cases  = max(cum_cases,  na.rm = TRUE),   # na.rm skips ND values
            cum_deaths = max(cum_deaths, na.rm = TRUE),
            .groups = "drop") %>%
  mutate(new_cases  = cum_cases  - lag(cum_cases,  default = 0),
         new_deaths = cum_deaths - lag(cum_deaths, default = 0),
         # the latest week may only have a few days of reports so far
         week_status = if_else(week + 6 <= max(ebola$date),
                               "Complete week", "Incomplete (still reporting)"))

print(weekly, n = Inf)


# ---- STEP 6: Plot the weekly epicurve -------------------------------
epicurve <- ggplot(weekly, aes(x = week, y = new_cases, fill = week_status)) +
  geom_col(width = 6) +
  scale_fill_manual(values = c("Complete week" = "#B22222",
                               "Incomplete (still reporting)" = "grey70"),
                    name = NULL) +
  scale_x_date(date_breaks = "2 weeks", date_labels = "%d %b") +
  labs(title    = "Weekly new confirmed Ebola (Bundibugyo) cases, DRC, 2026",
       subtitle = "Derived from cumulative totals in national situation reports",
       x = "Week (starting Monday)",
       y = "New confirmed cases",
       caption = "Source: INSP DRC situation reports via INRB-UMIE BDBV2026-Data. Preliminary data.") +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "top")

epicurve   # shows the chart in the Plots pane
ggsave("figures/epicurve.png", epicurve, width = 9, height = 5, dpi = 150, bg = "white")


# ---- STEP 7: Plot weekly deaths (second chart) ----------------------
deaths_chart <- ggplot(weekly, aes(x = week, y = new_deaths, fill = week_status)) +
  geom_col(width = 6) +
  scale_fill_manual(values = c("Complete week" = "#404040",
                               "Incomplete (still reporting)" = "grey70"),
                    name = NULL) +
  scale_x_date(date_breaks = "2 weeks", date_labels = "%d %b") +
  labs(title = "Weekly new confirmed Ebola deaths, DRC, 2026",
       x = "Week (starting Monday)", y = "New confirmed deaths",
       caption = "Source: INSP DRC situation reports via INRB-UMIE BDBV2026-Data. Preliminary data.") +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "top")

deaths_chart
ggsave("figures/weekly_deaths.png", deaths_chart, width = 9, height = 5, dpi = 150, bg = "white")


# ---- STEP 8: Key numbers for your README ----------------------------
latest <- ebola %>% filter(!is.na(cum_cases), !is.na(cum_deaths)) %>% slice_tail(n = 1)
peak   <- weekly %>% filter(week_status == "Complete week") %>% slice_max(new_cases, n = 1)

cat("\n========== KEY FINDINGS ==========\n")
cat("Latest report date:      ", format(latest$date), "\n")
cat("Total confirmed cases:   ", latest$cum_cases, "\n")
cat("Total confirmed deaths:  ", latest$cum_deaths, "\n")
cat("CFR among confirmed (%): ", round(100 * latest$cum_deaths / latest$cum_cases, 1), "\n")
cat("Peak week (starting):    ", format(peak$week), "with", peak$new_cases, "new cases\n")


# ---- STEP 9: Save the weekly table ----------------------------------
write_csv(weekly, "data/weekly_summary.csv")
