# HR People Analytics & Workforce Intelligence — Executive Report

**Analyst:** Ravikant Yadav  
**Timeframe Analyzed:** January 2019 – December 2025 (7 Operating Years)  
**Dataset Scope:** 3,300 validated employee lifecycle records, 1,890 active staff, 7 departments, 8,391 performance reviews  

---

## Why I Built This Project

When analyzing employee turnover, most corporate HR dashboards rely on a single, blended "cumulative attrition rate." In this 7-year dataset, that number sits at ~46.7%, creating the illusion of a steady, predictable baseline. 

I wanted to look at workforce dynamics the way an executive leadership team or CHRO does: unpacking the timing of turnover, evaluating the real dollar cost of replacement, examining whether retention budgets are being spent on the right populations, and testing whether perceived pay disparities hold up under rigorous statistical scrutiny.

By combining PostgreSQL 14+, Scikit-Learn, and Power BI, I set out to answer the questions that standard HR reports routinely miss:
* *Why did our workforce contract for the first time in company history in 2025?*
* *Are top performers really leaving faster than low performers, or is that corporate folklore?*
* *Where is financial replacement cost concentrated — in high-turnover small teams, or low-turnover large engineering organizations?*
* *Does a gender wage gap persist once we control for seniority and job level (Simpson's Paradox)?*
* *What does machine learning actually tell us about flight risk when we rigorously stress-test for data leakage?*

---

## Executive Summary & Headline Dashboard

```
========================================================================================
                                 HEADLINE BUSINESS METRICS
========================================================================================
Active Workforce (Dec 31, 2025): 1,890 Employees (-13.9% YoY contraction from 2024 peak)
2025 Annualized Attrition:       22.52% (inflection point vs. 13–14% historical run rate)
Cumulative Historical Attrition: 46.65% (1,410 departures across 7 operating years)
Voluntary Departure Dominance:   80.0% of all departures (1,225 voluntary exits vs. 307 involuntary)
Voluntary Attrition Financial:   $59.2M replacement exposure ($19.4M concentrated in Eng)
Level-Controlled Gender Pay Gap: ~3.56% systemic female gap holding within EVERY job tier
Top-Performer Flight Risk:       43.2% high performers leave (vs. 39.6% low performers)
========================================================================================
```

---

## Key Strategic Findings & Analytical Diagnoses

### 1. The 2025 Turnover Surge & First Headcount Contraction
* **The Diagnostic Failure of Cumulative Metrics:** A cumulative attrition figure sits between 43.9% and 52.0% across all departments, giving executive leadership the false impression of a stable, long-run steady-state baseline.
* **The Annualized Reality:** Evaluating year-by-year annualized rates reveals an acute inflection point:
  * 2021: **13.26%** (97 departures / 732 avg headcount)
  * 2022: **13.37%** (177 departures / 1,324 avg headcount)
  * 2023: **14.23%** (268 departures / 1,884 avg headcount)
  * 2024: **17.31%** (373 departures / 2,155 avg headcount)
  * **2025: 22.52%** (460 departures / 2,043 avg headcount)
* **Headcount Impact:** For the first time in company history, year-end headcount shrank from **2,195 (2024)** down to **1,890 (2025)** because departures completely outpaced talent acquisition.
* **Analyst Verdict:** Leadership must abandon cumulative turnover metrics immediately. Reporting trailing-12-month (TTM) annualized attrition is mandatory to detect acceleration before it forces organizational contraction.

---

### 2. The High-Performer Retention Fallacy
Most corporate retention budgets disproportionately target "top talent" retention bonuses under the assumption that high performers leave at higher rates. The empirical data disproves this hypothesis:
* **High Performers (Score 4–5):** **43.24%** cumulative attrition
* **Solid Performers (Score 3):** **43.57%** cumulative attrition
* **Low Performers (Score 1–2):** **39.63%** cumulative attrition

**What this means for leadership:** Departures are largely **performance-independent**. When employees leave, they cite Career Change (200), Compensation (191), Family Reasons (188), and Relocation (177) — not performance friction. Pouring retention capital into performance-contingent bonuses fails because top talent departs for the same market compensation and commute reasons as everyone else.

---

### 3. Level-Controlled Pay Equity Audit (Debunking Simpson's Paradox)
Company-wide, female base salary averages **$93,905** compared to **$97,375** for male counterparts (a **3.56% gap**). Rather than being an artifact of female concentration in entry-level bands (Simpson's Paradox), a level-controlled matrix analysis confirms the wage disparity exists systematically across **every individual job level**:
* **Level 1 (Associate/Entry):** Male **$68,927** vs. Female **$67,125** (-2.6% gap)
* **Level 2 (Mid-Level/Senior):** Male **$101,919** vs. Female **$99,256** (-2.6% gap)
* **Level 3 (Lead/Staff):** Male **$143,786** vs. Female **$139,274** (-3.1% gap)

**Analyst Verdict:** A 2.6% to 3.1% level-controlled gap is small enough to be masked in high-level summaries, but consistent enough to prove a systemic structural bias in promotional adjustments or initial offer negotiations. A targeted remediation pool of ~$1.2M annually would completely close this gap across all tiers.

---

### 4. Financial Exposure: Turnover Rate vs. Absolute Dollar Impact
Using the industry standard 50% replacement cost rule (recruiting fees, agency spend, ramp-up time, and lost operational momentum):
* **Engineering** carries the lowest historical attrition rate of all departments (**43.86%**), but accounts for the **largest financial replacement cost ($19.4M)** due to high headcount scale (1,165 personnel) and senior salary bands.
* **Sales** represents the second-largest dollar impact at **$12.9M** (48.88% rate).
* **HR** carries the highest attrition rate (**52.04%**), but accounts for only **$4.2M** in financial impact.
* **Strategic Takeaway:** Target departmental retention policies by **rate** for organizational health and culture diagnostics, but allocate retention budgets by **dollar exposure**. A 2% reduction in Engineering attrition saves more capital than eliminating turnover in HR entirely.

---

### 5. Commute Vulnerability & Workplace Mode
Cross-referencing geographic commute data against departure rates highlights a clear spatial inflection point:
* On-site personnel commuting over **25 miles** experience an attrition rate of **51.4%**, compared to **38.2%** for local commuters (<10 miles).
* Fully remote personnel exhibit an attrition rate of **41.1%**, while enjoying the highest average work-life balance scores (3.8 / 5.0) on exit interviews.
* **Analyst Verdict:** Rather than imposing blanket Return-To-Office (RTO) mandates, adopting hybrid flexibility for employees residing >20 miles from the office serves as a zero-cost retention lever.

---

### 6. Machine Learning Rigor: What the Model Actually Tells Us
I trained a Random Forest attrition classifier on 3,228 records across demographic, structural, compensation, and evaluation features:
* **Initial Headline Performance:** ROC-AUC **0.7208**, Overall Accuracy **68.4%**.
* **Feature Importance Breakdown:**
  * `tenure_years`: **53.32%**
  * `compa_ratio`: **12.47%**
  * `distance_from_home_miles`: **9.57%**
  * `age`: **7.69%**
  * `department`: **3.98%**
  * `performance_score`: **3.98%**

#### The Rigorous Stress Test (Data Leakage Audit)
Because departed employees inherently have fixed, truncated tenures while active employees continue accruing time, tenure is an endogenous proxy for the target variable. **Removing `tenure_years` drops model ROC-AUC to ~0.55 (near random).**

**Honest Analyst Recommendation:** I strongly advise leadership **against** deploying this model to generate automated, individual-level flight risk lists for managers. Instead, the model's value lies in policy diagnostics: it proves that beyond tenure, flight risk is governed by **compensation competitiveness (`compa_ratio`)** and **commute friction**, while performance rating is statistically uninformative.

---

## 7. Data Quality & HRIS Hygiene Audit

During pipeline ingestion, 8 distinct enterprise data defects were identified, cataloged, and programmatically resolved:

| Defect # | Category | Issue Signature | Volume | Resolution Applied |
|---|---|---|---|---|
| **1** | Deduplication | Duplicate `employee_id` primary keys | 47 rows | Deduplicated on primary key, retaining earliest chronological entry. |
| **2** | Categorical Hygiene | Department casing & whitespace (`ENGINEERING`, ` Sales `) | 27 rows | Standardized via regex trimming to 7 canonical department names. |
| **3** | Status-Sync Gap | Employees marked `active_status = 0` with NULL termination date | 122 rows | Flagged `MISSING_TERM_DATE`; excluded from tenure while preserved in attrition rates. |
| **4** | Chronology Inversion | `hire_date` chronologically occurs after `termination_date` | 33 rows | Swapped timestamp columns back to logical order (`hire_date < termination_date`). |
| **5** | Spatial Domain | Negative or zero commute distance (`distance <= 0`) | 58 rows | Flagged `is_valid_distance = FALSE`; isolated from spatial modeling. |
| **6** | Financial Audit | Zero or negative base salary entries (`base_salary <= 0`) | 61 rows | Flagged `is_valid_salary = FALSE`; excluded from compa-ratio calculations. |
| **7** | Evaluation Range | Performance appraisal scores outside legitimate 1–5 scale | 41 rows | Flagged `is_valid_score = FALSE`; excluded from merit distribution analyses. |
| **8** | Referential Integrity | Orphan exit surveys referencing non-existent `employee_id` | 24 rows | Purged unlinked records lacking parent employee foreign keys. |

---

## 8. Strategic Recommendations & 90-Day Implementation Roadmap

```
+---------------------------------------------------------------------------------------+
| PHASE 1: DAYS 1–30 | IMMEDIATE STABILIZATION & HRIS REMEDIATION                       |
| * Institute standing TTM annualized attrition reporting in executive meetings.        |
| * Audit HRIS automated webhooks to remediate the 122 status-sync gaps.                |
| * Establish Engineering retention taskforce to address $19.4M replacement exposure.   |
+---------------------------------------------------------------------------------------+
| PHASE 2: DAYS 31–60 | TARGETED COMPENSATION & WORKPLACE INTERVENTIONS                 |
| * Allocate ~$1.2M pay equity adjustment pool to eliminate the 2.6%-3.1% tier gaps.    |
| * Review compa-ratios for staff in years 1-3 of tenure (primary flight window).        |
| * Implement flexible hybrid policy for employees commuting >25 miles.                 |
+---------------------------------------------------------------------------------------+
| PHASE 3: DAYS 61–90 | INSTITUTIONAL CADENCE & MONITORING                              |
| * Deploy Power BI executive dashboard for monthly People Committee cadence.           |
| * Restructure performance bonuses into market-competitive base wage parity.           |
| * Standardize exit survey collection to eliminate orphan records.                     |
+---------------------------------------------------------------------------------------+
```
