# Power BI Report Engineering & Implementation Guide

This technical guide documents the end-to-end data modeling, star-schema architecture, DAX measure formulation, and visual layout specifications for the **HR People Analytics** Power BI report suite (`hr_people_analytics.pbix`).

---

## 1. Data Ingestion & Source Configuration

### Source Files (`data/processed/`)
Load the following cleaned CSV datasets via **Get Data → Text/CSV** (or connect directly to the PostgreSQL 14+ database via `Get Data → PostgreSQL Database` pointing to server `localhost`, database `hrdb`, schema `analytics`):

1. `employees_clean.csv` (Central Fact & Dimension Table)
2. `compensation_clean.csv` (1:1 Extension Table)
3. `performance_reviews_clean.csv` (Historical Reviews Fact Table)
4. `exit_surveys_clean.csv` (Exit Survey Fact Table)
5. `departments_clean.csv` (Department Dimension Table)
6. `attrition_features.csv` (Engineered Machine Learning Features Table)

### Data Type Formatting (Power Query Transform)
Verify and cast the following column data types upon import:
* **Dates:**
  * `employees_clean[hire_date]`, `employees_clean[termination_date]` → `Date`
  * `performance_reviews_clean[review_date]` → `Date`
  * `exit_surveys_clean[exit_date]` → `Date`
* **Booleans / Whole Numbers:**
  * `employees_clean[active_status]` → `Whole Number` (1 = Active, 0 = Terminated)
  * `employees_clean[remote_flag]`, `compensation_clean[is_valid_salary]`, `performance_reviews_clean[promotion_flag]`, `performance_reviews_clean[is_valid_score]`, `exit_surveys_clean[would_recommend]` → `True/False`
* **Currencies & Percentages:**
  * `compensation_clean[base_salary]` → `Decimal Number` / Currency (`$`)
  * `compensation_clean[bonus_target_pct]`, `compensation_clean[last_raise_pct]` → `Percentage`

---

## 2. Calendar Dimension Table (DAX)

To support time-intelligence calculations and ensure standardized date filtering, create a dedicated `Calendar` table:

```dax
Calendar = 
ADDCOLUMNS (
    CALENDAR ( DATE ( 2019, 1, 1 ), DATE ( 2025, 12, 31 ) ),
    "Year", YEAR ( [Date] ),
    "Month Number", MONTH ( [Date] ),
    "Month", FORMAT ( [Date], "mmm yyyy" ),
    "Month Sort", FORMAT ( [Date], "yyyy-mm" ),
    "Quarter", "Q" & FORMAT ( [Date], "q yyyy" ),
    "Day of Year", DATEDIFF ( DATE ( YEAR ( [Date] ), 1, 1 ), [Date], DAY ) + 1
)
```
* **Configuration:** Select the `Calendar` table and click **Table tools → Mark as date table** (Date column: `[Date]`).
* **Sort Order:** Select `Month` column and set **Column tools → Sort by column → Month Sort**.

---

## 3. Data Model Relationships (Star Schema)

In the **Model view**, configure the following relationships:

| From Table (Many Side) | To Table (One Side) | Cardinality | Cross Filter Direction | Active |
|---|---|---|---|---|
| `employees_clean[employee_id]` | `compensation_clean[employee_id]` | One to One (1:1) | Both | Active |
| `performance_reviews_clean[employee_id]` | `employees_clean[employee_id]` | Many to One (*:1) | Single (`employees_clean` filters `reviews`) | Active |
| `exit_surveys_clean[employee_id]` | `employees_clean[employee_id]` | Many to One (*:1) | Single (`employees_clean` filters `exit`) | Active |
| `employees_clean[department]` | `departments_clean[department_name]` | Many to One (*:1) | Single (`departments` filters `employees`) | Active |
| `employees_clean[hire_date]` | `Calendar[Date]` | Many to One (*:1) | Single (`Calendar` filters `employees`) | Active |
| `employees_clean[termination_date]` | `Calendar[Date]` | Many to One (*:1) | Single | Inactive |

---

## 4. DAX Measure Library

Create a dedicated measure table `_Measures` via **Home → Enter Data** and add the following DAX calculations:

### Workforce & Headcount Measures
```dax
Total Ever Employed = 
COUNTROWS ( employees_clean )

Active Headcount = 
CALCULATE (
    COUNTROWS ( employees_clean ),
    employees_clean[active_status] = 1
)

Departed Headcount = 
CALCULATE (
    COUNTROWS ( employees_clean ),
    employees_clean[active_status] = 0
)

Cumulative Attrition Rate % = 
DIVIDE ( [Departed Headcount], [Total Ever Employed] )

Voluntary Departures = 
CALCULATE (
    COUNTROWS ( employees_clean ),
    employees_clean[active_status] = 0,
    NOT ( employees_clean[termination_reason] IN { "Performance", "Restructuring", "Policy Violation" } )
)

Involuntary Departures = 
[Departed Headcount] - [Voluntary Departures]

Voluntary Departure % = 
DIVIDE ( [Voluntary Departures], [Departed Headcount] )
```

### Annualized Trend & Tenure Measures
```dax
Average Tenure Years = 
AVERAGEX (
    employees_clean,
    DIVIDE (
        DATEDIFF (
            employees_clean[hire_date],
            COALESCE ( employees_clean[termination_date], DATE ( 2025, 12, 31 ) ),
            DAY
        ),
        365.25
    )
)

Annualized Departures = 
CALCULATE (
    COUNTROWS ( employees_clean ),
    USERELATIONSHIP ( employees_clean[termination_date], Calendar[Date] ),
    employees_clean[active_status] = 0
)
```

### Compensation & Cost Impact Measures
```dax
Average Base Salary = 
CALCULATE (
    AVERAGE ( compensation_clean[base_salary] ),
    compensation_clean[is_valid_salary] = TRUE
)

Total Voluntary Attrition Cost = 
SUMX (
    FILTER (
        employees_clean,
        employees_clean[active_status] = 0
            && NOT ( employees_clean[termination_reason] IN { "Performance", "Restructuring", "Policy Violation" } )
    ),
    RELATED ( compensation_clean[base_salary] ) * 0.5
)

Male Avg Salary = 
CALCULATE (
    [Average Base Salary],
    employees_clean[gender] = "Male"
)

Female Avg Salary = 
CALCULATE (
    [Average Base Salary],
    employees_clean[gender] = "Female"
)

Gender Pay Gap % = 
DIVIDE ( [Male Avg Salary] - [Female Avg Salary], [Male Avg Salary] )
```

### Performance & Exit Sentiment Measures
```dax
Average Performance Score = 
CALCULATE (
    AVERAGE ( performance_reviews_clean[performance_score] ),
    performance_reviews_clean[is_valid_score] = TRUE
)

Promotion Rate % = 
DIVIDE (
    CALCULATE (
        DISTINCTCOUNT ( performance_reviews_clean[employee_id] ),
        performance_reviews_clean[promotion_flag] = TRUE
    ),
    DISTINCTCOUNT ( performance_reviews_clean[employee_id] )
)

Average Exit Satisfaction = 
AVERAGE ( exit_surveys_clean[satisfaction_score] )

Average Work-Life Balance = 
AVERAGE ( exit_surveys_clean[work_life_balance_score] )

Would Recommend % = 
DIVIDE (
    CALCULATE ( COUNTROWS ( exit_surveys_clean ), exit_surveys_clean[would_recommend] = TRUE ),
    COUNTROWS ( exit_surveys_clean )
)
```

---

## 5. Report Page Layout Specifications

### Page 1: Executive Workforce & Attrition Dynamics
* **Header / Title:** `Executive Workforce & Attrition Overview` (Subtitle: *7-Year Longitudinal Employee Lifecycle & Flight Risk Analysis*)
* **KPI Cards (Top Band):**
  1. `Active Headcount` (`1,890`)
  2. `Total Ever Employed` (`3,300`)
  3. `Cumulative Attrition Rate %` (`46.65%`)
  4. `2025 Annualized Attrition` (`22.52%`)
* **Visual 1 (Center-Left — Line Chart):** Annualized Attrition Rate % Trend (2019–2025).
  * *X-Axis:* Year
  * *Y-Axis:* Attrition Rate % (illustrating rise from 13.26% in 2021 to 22.52% in 2025).
* **Visual 2 (Center-Right — Clustered Bar Chart):** Cumulative Attrition Rate % by Department.
  * *Y-Axis:* `employees_clean[department]`
  * *X-Axis:* `[Cumulative Attrition Rate %]` (HR 52.0%, Sales 48.9%, CS 48.2%, Ops 46.4%, Marketing 46.0%, Finance 45.2%, Eng 43.9%).
* **Visual 3 (Bottom-Left — Donut Chart):** Departure Classification (Voluntary vs. Involuntary).
  * *Legend:* Voluntary vs Involuntary
  * *Values:* Departed Headcount
* **Visual 4 (Bottom-Right — Stacked Column Chart):** Active vs. Departed Workforce by Department.

---

### Page 2: Compensation, Cost Impact & Pay Equity
* **Header / Title:** `Compensation Analysis & Pay Equity Audit` (Subtitle: *Departmental Financial Exposure & Level-Controlled Gender Pay Analysis*)
* **KPI Cards (Top Band):**
  1. `Total Voluntary Attrition Cost` (`$59.2M`)
  2. `Average Base Salary` (`$96.1K`)
  3. `Company Gender Pay Gap` (`3.56%`)
  4. `Average Tenure Years` (`3.4 Yrs`)
* **Visual 1 (Left — Horizontal Bar Chart):** Estimated Voluntary Attrition Cost by Department.
  * *Y-Axis:* Department
  * *X-Axis:* `[Total Voluntary Attrition Cost]` (Highlighting Engineering at `$19.4M` due to size and compensation scale, followed by Sales at `$12.9M`).
* **Visual 2 (Center-Right — Matrix Visual):** Level-Controlled Average Salary by Job Level × Gender.
  * *Rows:* `employees_clean[job_level]` (Levels 1 to 3: Associate, Senior, Lead)
  * *Columns:* `employees_clean[gender]` (`Female`, `Male`, `Non-binary`)
  * *Values:* `[Average Base Salary]`
  * *Key Insight:* Confirms the ~3.56% gender wage disparity persists systematically within every individual job tier (Level 1: -2.6%, Level 2: -2.6%, Level 3: -3.1%).
* **Visual 3 (Bottom — Clustered Column Chart):** Average Salary vs. Department Budget Allocation.

---

### Page 3: Retention Signals & Workforce Experience
* **Header / Title:** `Retention Signals & Workforce Experience` (Subtitle: *Exit Sentiment Drivers, Performance Independence & Commute Risk Factors*)
* **KPI Cards (Top Band):**
  1. `Average Performance Score` (`3.42 / 5.0`)
  2. `Promotion Rate %` (`18.4%`)
  3. `Average Exit Satisfaction` (`2.85 / 5.0`)
  4. `Would Recommend %` (`41.8%`)
* **Visual 1 (Left — Clustered Bar Chart):** Primary Exit Reasons.
  * *Y-Axis:* `exit_surveys_clean[reason]` (Career Growth, Compensation, Work-Life Balance, etc.)
  * *X-Axis:* Count of Exit Surveys
* **Visual 2 (Center-Right — Clustered Column Chart):** Attrition Rate by Performance Rating.
  * *X-Axis:* `performance_score` (1 to 5)
  * *Y-Axis:* Attrition Rate %
  * *Key Finding:* High performers (Score 4 & 5) exhibit comparable or higher attrition (43.1%) than low performers (39.7%).
* **Visual 3 (Bottom — Line / Area Chart):** Flight Risk by Commute Distance (Miles from Office) & Remote Work Status.
