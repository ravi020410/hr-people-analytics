-- =========================================================================================
-- Corporate HR People Analytics - 20+ Advanced SQL Business Queries
-- Author: Ravikant Yadav
-- Database Platform: SQL Server (T-SQL) / PostgreSQL Compatible
-- Description: This script contains 22 production-grade, highly optimized SQL queries
--              designed to answer critical HR people leadership questions regarding employee
--              turnover (attrition), compensation competitiveness, and retention economics.
-- =========================================================================================

-- -----------------------------------------------------------------------------------------
-- QUERY 1: Executive HR KPI Dashboard Scorecard
-- Purpose: Calculates foundational people metrics: active headcount, voluntary attritions,
--          involuntary terminations, and total attrition rates.
-- -----------------------------------------------------------------------------------------
SELECT
    COUNT(EmployeeID) AS Total_Registered_Headcount,
    SUM(CASE WHEN ActiveStatus = 'Active' THEN 1 ELSE 0 END) AS Active_Employee_Headcount,
    SUM(CASE WHEN ActiveStatus = 'Terminated' AND TerminationType = 'Voluntary' THEN 1 ELSE 0 END) AS Voluntary_Attritions,
    SUM(CASE WHEN ActiveStatus = 'Terminated' AND TerminationType = 'Involuntary' THEN 1 ELSE 0 END) AS Involuntary_Terminations,
    ROUND((SUM(CASE WHEN ActiveStatus = 'Terminated' THEN 1.0 ELSE 0.0 END) * 100.0) / COUNT(EmployeeID), 2) AS Cumulative_Attrition_Rate_Percent
FROM Dim_Employees;


-- -----------------------------------------------------------------------------------------
-- QUERY 2: Annualized Voluntary Attrition Rates by Department
-- Purpose: Identifies departments with elevated turnover levels. Highlight business units
--          experiencing retention challenges.
-- -----------------------------------------------------------------------------------------
SELECT
    Department,
    COUNT(EmployeeID) AS Total_Department_Staff,
    SUM(CASE WHEN ActiveStatus = 'Terminated' AND TerminationType = 'Voluntary' THEN 1 ELSE 0 END) AS Voluntary_Exits,
    ROUND((SUM(CASE WHEN ActiveStatus = 'Terminated' AND TerminationType = 'Voluntary' THEN 1.0 ELSE 0.0 END) * 100.0) /
          COUNT(EmployeeID), 2) AS Voluntary_Attrition_Rate_Percent
FROM Dim_Employees
GROUP BY Department
ORDER BY Voluntary_Attrition_Rate_Percent DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 3: Salary Benchmarking & Market Deficit (Compa-Ratio) Analysis
-- Purpose: Calculates employee Compa-Ratios (Base Salary / Market Median Salary).
--          Values below 80% indicate severe salary deficits and high retention risk.
-- -----------------------------------------------------------------------------------------
SELECT
    EmployeeID,
    Department,
    JobRole,
    BaseSalary AS Current_Base_Salary,
    MarketMedianSalary AS Market_Median_Benchmark,
    ROUND((BaseSalary / MarketMedianSalary) * 100.0, 2) AS Compa_Ratio_Percent,
    CASE
        WHEN (BaseSalary / MarketMedianSalary) < 0.80 THEN 'Severe Salary Deficit (<80%)'
        WHEN (BaseSalary / MarketMedianSalary) BETWEEN 0.80 AND 0.95 THEN 'Below Market Value'
        WHEN (BaseSalary / MarketMedianSalary) BETWEEN 0.95 AND 1.05 THEN 'Fair Market Standard'
        ELSE 'Above Market Premium'
    END AS Compensation_Market_Alignment
FROM Fact_Compensation
ORDER BY Compa_Ratio_Percent ASC;


-- -----------------------------------------------------------------------------------------
-- QUERY 4: Attrition Rate vs. Compensation Competitive Alignments
-- Purpose: Measures if low-compa ratios correlate directly with higher attrition rates,
--          verifying if compensation correction budgets are needed.
-- -----------------------------------------------------------------------------------------
WITH CompensationAlignment AS (
    SELECT
        fc.EmployeeID,
        (fc.BaseSalary / fc.MarketMedianSalary) AS Compa_Ratio,
        de.ActiveStatus
    FROM Fact_Compensation fc
    JOIN Dim_Employees de ON fc.EmployeeID = de.EmployeeID
),
AlignmentBuckets AS (
    SELECT
        EmployeeID,
        ActiveStatus,
        CASE
            WHEN Compa_Ratio < 0.80 THEN 'Severe Salary Deficit'
            WHEN Compa_Ratio BETWEEN 0.80 AND 0.95 THEN 'Below Market'
            WHEN Compa_Ratio BETWEEN 0.95 AND 1.05 THEN 'Fair Market Standard'
            ELSE 'Market Premium'
        END AS Compensation_Category
    FROM CompensationAlignment
)
SELECT
    Compensation_Category,
    COUNT(EmployeeID) AS Staff_Sample_Size,
    SUM(CASE WHEN ActiveStatus = 'Terminated' THEN 1 ELSE 0 END) AS Terminated_Exits,
    ROUND((SUM(CASE WHEN ActiveStatus = 'Terminated' THEN 1.0 ELSE 0.0 END) * 100.0) / COUNT(EmployeeID), 2) AS Attrition_Rate_Percent
FROM AlignmentBuckets
GROUP BY Compensation_Category
ORDER BY Attrition_Rate_Percent DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 5: Average Employee Tenure (Months) by Job Role
-- Purpose: Measures average tenure duration to evaluate which roles have short lifespans.
-- -----------------------------------------------------------------------------------------
SELECT
    JobRole,
    COUNT(EmployeeID) AS Total_Sample,
    ROUND(AVG(TenureMonths), 1) AS Average_Tenure_Duration_Months,
    ROUND(AVG(TenureMonths) / 12.0, 2) AS Average_Tenure_Duration_Years
FROM Dim_Employees
GROUP BY JobRole
ORDER BY Average_Tenure_Duration_Months ASC;


-- -----------------------------------------------------------------------------------------
-- QUERY 6: Voluntary Attrition Cost Modeling (Business ROI Impact)
-- Purpose: Translates headcount loss into financial cost, assuming voluntary turnover costs
--          approximately 1.5 times the departing employee's salary in recruitment and ramp-up.
-- -----------------------------------------------------------------------------------------
WITH AttritionSalaries AS (
    SELECT
        de.EmployeeID,
        de.Department,
        de.JobRole,
        fc.BaseSalary
    FROM Dim_Employees de
    JOIN Fact_Compensation fc ON de.EmployeeID = fc.EmployeeID
    WHERE de.ActiveStatus = 'Terminated'
      AND de.TerminationType = 'Voluntary'
)
SELECT
    Department,
    COUNT(EmployeeID) AS Voluntary_Departures,
    ROUND(SUM(BaseSalary), 2) AS Departed_Payroll,
    ROUND(SUM(BaseSalary) * 1.5, 2) AS Estimated_Business_Turnover_Cost_ROI
FROM AttritionSalaries
GROUP BY Department
ORDER BY Estimated_Business_Turnover_Cost_ROI DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 7: Exit Survey Correlation with Primary Reasons for Voluntary Exit
-- Purpose: Aggregates exit survey results to highlight structural root causes of attrition
--          (e.g., Toxic Culture, Low Salary, No Advancement).
-- -----------------------------------------------------------------------------------------
SELECT
    ExitPrimaryReason,
    COUNT(EmployeeID) AS Departures_Responding,
    ROUND((COUNT(EmployeeID) * 100.0) / (SELECT COUNT(*) FROM Fact_Exit_Surveys), 2) AS Response_Share_Percent,
    ROUND(AVG(SatisfactionScore), 1) AS Average_Satisfaction_Score_1to10
FROM Fact_Exit_Surveys
GROUP BY ExitPrimaryReason
ORDER BY Departures_Responding DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 8: Performance Rating vs. Voluntary Attrition Rates (The Regrettable Loss)
-- Purpose: Evaluates if high-performing employees (Performance Score = 4 or 5) are leaving,
--          which represents high-risk "regrettable loss."
-- -----------------------------------------------------------------------------------------
WITH PerformanceExits AS (
    SELECT
        de.EmployeeID,
        de.ActiveStatus,
        de.TerminationType,
        fe.PerformanceRating
    FROM Dim_Employees de
    JOIN Fact_Employee_Evaluations fe ON de.EmployeeID = fe.EmployeeID
)
SELECT
    PerformanceRating AS Employee_Performance_Rating,
    COUNT(EmployeeID) AS Headcount_Sample,
    SUM(CASE WHEN ActiveStatus = 'Terminated' AND TerminationType = 'Voluntary' THEN 1 ELSE 0 END) AS Regrettable_Voluntary_Exits,
    ROUND((SUM(CASE WHEN ActiveStatus = 'Terminated' AND TerminationType = 'Voluntary' THEN 1.0 ELSE 0.0 END) * 100.0) /
          COUNT(EmployeeID), 2) AS Regrettable_Loss_Ratio_Percent
FROM PerformanceExits
GROUP BY PerformanceRating
ORDER BY PerformanceRating DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 9: Salary Growth (Raise Rates) vs. Average Job Tenure
-- Purpose: Reviews salary promotion velocity. Compares total raise percentages against
--          active employee tenure years.
-- -----------------------------------------------------------------------------------------
SELECT
    EmployeeID,
    Department,
    ROUND(TotalPromotionRaisesPercent, 1) AS Cumulative_Raise_Rate_Percent,
    TenureYears,
    ROUND(TotalPromotionRaisesPercent / NULLIF(TenureYears, 0), 2) AS Annualized_Salary_Growth_Speed_Percent
FROM Fact_Compensation
WHERE ActiveStatus = 'Active'
ORDER BY Annualized_Salary_Growth_Speed_Percent DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 10: Retention Risk Heatmap Matrix (Compa-Ratio + Performance Score)
-- Purpose: Cross-references compensation deficits with high performance rating to identify
--          the highest-risk retention alerts (VIP flight risk).
-- -----------------------------------------------------------------------------------------
WITH EmployeeProfiles AS (
    SELECT
        de.EmployeeID,
        de.Department,
        de.JobRole,
        fe.PerformanceRating,
        ROUND((fc.BaseSalary / fc.MarketMedianSalary) * 100.0, 2) AS Compa_Ratio
    FROM Dim_Employees de
    JOIN Fact_Employee_Evaluations fe ON de.EmployeeID = fe.EmployeeID
    JOIN Fact_Compensation fc ON de.EmployeeID = fc.EmployeeID
    WHERE de.ActiveStatus = 'Active'
)
SELECT
    EmployeeID,
    Department,
    JobRole,
    PerformanceRating,
    Compa_Ratio,
    CASE
        WHEN PerformanceRating >= 4 AND Compa_Ratio < 90.0 THEN 'CRITICAL ALERT: Top Performer Underpaid'
        WHEN PerformanceRating >= 4 AND Compa_Ratio BETWEEN 90.0 AND 95.0 THEN 'HIGH WARNING: Top Performer Below Market'
        WHEN PerformanceRating <= 2 AND Compa_Ratio > 110.0 THEN 'OPERATIONAL GAP: Underperformer Overpaid'
        ELSE 'Fair Structural Standard'
    END AS Retention_Risk_Action_Item
FROM EmployeeProfiles
WHERE PerformanceRating >= 4 AND Compa_Ratio < 95.0
ORDER BY Compa_Ratio ASC;


-- -----------------------------------------------------------------------------------------
-- QUERY 11: Departmental Training ROI vs Attrition Mitigation
-- Purpose: Evaluates if employee training hours are correlated with higher retention times
--          and lower attrition rates across business units.
-- -----------------------------------------------------------------------------------------
SELECT
    de.Department,
    ROUND(AVG(fe.TrainingHoursCompleted), 1) AS Average_Training_Hours_Per_Employee,
    ROUND((SUM(CASE WHEN de.ActiveStatus = 'Terminated' THEN 1.0 ELSE 0.0 END) * 100.0) / COUNT(de.EmployeeID), 2) AS Attrition_Rate_Percent
FROM Dim_Employees de
JOIN Fact_Employee_Evaluations fe ON de.Department = fe.Department
GROUP BY de.Department
ORDER BY Average_Training_Hours_Per_Employee DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 12: Manager-Specific Attrition Index
-- Purpose: Identifies if employee departures are concentrated under specific managers or
--          leads, helping HR leaders detect leadership issues.
-- -----------------------------------------------------------------------------------------
SELECT
    ManagerID,
    COUNT(EmployeeID) AS Total_Direct_Reports,
    SUM(CASE WHEN ActiveStatus = 'Terminated' THEN 1 ELSE 0 END) AS Departures,
    ROUND((SUM(CASE WHEN ActiveStatus = 'Terminated' THEN 1.0 ELSE 0.0 END) * 100.0) / COUNT(EmployeeID), 2) AS Attrition_Index_Percent
FROM Dim_Employees
WHERE ManagerID IS NOT NULL
GROUP BY ManagerID
HAVING COUNT(EmployeeID) >= 5
ORDER BY Attrition_Index_Percent DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 13: Voluntary Exit Sentiment Analysis (Job Satisfaction Scores)
-- Purpose: Analyzes exit survey metrics to see if staff satisfaction was slipping in the
--          months preceding their voluntary resignation.
-- -----------------------------------------------------------------------------------------
SELECT
    Department,
    ROUND(AVG(SatisfactionScore), 2) AS Exit_Survey_Satisfaction_Average_1to10,
    ROUND(AVG(WorkLifeBalanceRating), 2) AS Exit_Survey_WorkLife_Balance_Average_1to5,
    COUNT(*) AS Responding_Exits
FROM Fact_Exit_Surveys
GROUP BY Department
ORDER BY Exit_Survey_Satisfaction_Average_1to10 ASC;


-- -----------------------------------------------------------------------------------------
-- QUERY 14: Gender Compensation Parity Audit
-- Purpose: Evaluates equal pay initiatives. Compares average salaries and compa-ratios by
--          gender across identical job levels and departments.
-- -----------------------------------------------------------------------------------------
SELECT
    de.Department,
    de.JobRole,
    de.Gender,
    COUNT(de.EmployeeID) AS Active_Staff_Count,
    ROUND(AVG(fc.BaseSalary), 2) AS Average_Base_Salary,
    ROUND(AVG(fc.BaseSalary / fc.MarketMedianSalary) * 100.0, 2) AS Average_Compa_Ratio_Percent
FROM Dim_Employees de
JOIN Fact_Compensation fc ON de.EmployeeID = fc.EmployeeID
WHERE de.ActiveStatus = 'Active'
GROUP BY de.Department, de.JobRole, de.Gender
ORDER BY de.Department, de.JobRole, de.Gender;


-- -----------------------------------------------------------------------------------------
-- QUERY 15: Extreme Outlier Commute Times vs Attrition Risk
-- Purpose: Identifies if unusually long employee commutes (commute distance > 45 miles)
--          contribute to early voluntary resignations.
-- -----------------------------------------------------------------------------------------
WITH CommuteProfiles AS (
    SELECT
        de.EmployeeID,
        de.CommuteDistanceMiles,
        de.ActiveStatus,
        de.TerminationType
    FROM Dim_Employees de
)
SELECT
    CASE
        WHEN CommuteDistanceMiles < 10 THEN 'Short Commute (<10 miles)'
        WHEN CommuteDistanceMiles BETWEEN 10 AND 25 THEN 'Average Commute'
        WHEN CommuteDistanceMiles BETWEEN 25 AND 45 THEN 'Long Commute'
        ELSE 'Severe Commute (>45 miles)'
    END AS Commute_Category,
    COUNT(EmployeeID) AS Staff_Sample_Count,
    SUM(CASE WHEN ActiveStatus = 'Terminated' AND TerminationType = 'Voluntary' THEN 1 ELSE 0 END) AS Voluntary_Exits,
    ROUND((SUM(CASE WHEN ActiveStatus = 'Terminated' AND TerminationType = 'Voluntary' THEN 1.0 ELSE 0.0 END) * 100.0) /
          COUNT(EmployeeID), 2) AS Attrition_Rate_Percent
FROM CommuteProfiles
GROUP BY
    CASE
        WHEN CommuteDistanceMiles < 10 THEN 'Short Commute (<10 miles)'
        WHEN CommuteDistanceMiles BETWEEN 10 AND 25 THEN 'Average Commute'
        WHEN CommuteDistanceMiles BETWEEN 25 AND 45 THEN 'Long Commute'
        ELSE 'Severe Commute (>45 miles)'
    END
ORDER BY Attrition_Rate_Percent DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 16: Annualized Voluntary Attrition Trends over Time
-- Purpose: Aggregates historical employee departures by resignation year to evaluate if
--          internal retention programs are proving successful.
-- -----------------------------------------------------------------------------------------
SELECT
    YEAR(TerminationDate) AS Year_Of_Exit,
    COUNT(EmployeeID) AS Voluntary_Departures,
    ROUND(SUM(BaseSalaryDeparting), 2) AS Departed_Annual_Salaries
FROM Fact_Exit_Surveys
GROUP BY YEAR(TerminationDate)
ORDER BY Year_Of_Exit;


-- -----------------------------------------------------------------------------------------
-- QUERY 17: Career Advancement (Years Since Last Promotion) vs Attrition Risk
-- Purpose: Reviews structural stagnation. Tests if employees with no promotions in over
--          3 years leave at twice the average rate.
-- -----------------------------------------------------------------------------------------
WITH PromotionProfiles AS (
    SELECT
        de.EmployeeID,
        de.ActiveStatus,
        de.TerminationType,
        fc.YearsSinceLastPromotion
    FROM Dim_Employees de
    JOIN Fact_Compensation fc ON de.EmployeeID = fc.EmployeeID
)
SELECT
    CASE
        WHEN YearsSinceLastPromotion < 1 THEN 'Recently Promoted (<1 yr)'
        WHEN YearsSinceLastPromotion BETWEEN 1 AND 3 THEN 'Mid-Stagnation'
        ELSE 'Severe Career Stagnation (>3 yrs)'
    END AS Career_Advancement_State,
    COUNT(EmployeeID) AS Staff_Sample,
    SUM(CASE WHEN ActiveStatus = 'Terminated' AND TerminationType = 'Voluntary' THEN 1 ELSE 0 END) AS Voluntary_Resignations,
    ROUND((SUM(CASE WHEN ActiveStatus = 'Terminated' AND TerminationType = 'Voluntary' THEN 1.0 ELSE 0.0 END) * 100.0) /
          COUNT(EmployeeID), 2) AS Attrition_Rate_Percent
FROM PromotionProfiles
GROUP BY
    CASE
        WHEN YearsSinceLastPromotion < 1 THEN 'Recently Promoted (<1 yr)'
        WHEN YearsSinceLastPromotion BETWEEN 1 AND 3 THEN 'Mid-Stagnation'
        ELSE 'Severe Career Stagnation (>3 yrs)'
    END
ORDER BY Attrition_Rate_Percent DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 18: HR Record Completeness Audit (Null Quality Checks)
-- Purpose: Quality control check. Identifies missing employee record variables (missing
--          termination fields or unlinked compensation records).
-- -----------------------------------------------------------------------------------------
SELECT
    COUNT(*) AS Total_Employee_Records,
    SUM(CASE WHEN Department IS NULL THEN 1 ELSE 0 END) AS Null_Departments,
    SUM(CASE WHEN ActiveStatus = 'Terminated' AND TerminationType IS NULL THEN 1 ELSE 0 END) AS Null_Termination_Types,
    SUM(CASE WHEN ManagerID IS NULL THEN 1 ELSE 0 END) AS Staff_With_No_Manager_Assigned
FROM Dim_Employees;


-- -----------------------------------------------------------------------------------------
-- QUERY 19: Departed Employee Exit Satisfaction Distribution
-- Purpose: Identifies exit sentiment skewness. Calculates if voluntary exits are departing
--          bitterly (satisfaction scores <= 3) or satisfied (seeking better roles).
-- -----------------------------------------------------------------------------------------
SELECT
    CASE
        WHEN SatisfactionScore <= 3 THEN 'Bitter/Unsatisfied Departures (1-3)'
        WHEN SatisfactionScore BETWEEN 4 AND 7 THEN 'Passive/Neutral Departures'
        ELSE 'Highly Satisfied Departures (8-10)'
    END AS Exit_Sentiment_Category,
    COUNT(EmployeeID) AS Total_Departed_Count,
    ROUND((COUNT(EmployeeID) * 100.0) / (SELECT COUNT(*) FROM Fact_Exit_Surveys), 2) AS Distribution_Share_Percent
FROM Fact_Exit_Surveys
GROUP BY
    CASE
        WHEN SatisfactionScore <= 3 THEN 'Bitter/Unsatisfied Departures (1-3)'
        WHEN SatisfactionScore BETWEEN 4 AND 7 THEN 'Passive/Neutral Departures'
        ELSE 'Highly Satisfied Departures (8-10)'
    END
ORDER BY Distribution_Share_Percent DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 20: Duplicate Record Audit in HR Databases
-- Purpose: Core data cleaning verification query. Ensures no identical employee rows exist.
-- -----------------------------------------------------------------------------------------
SELECT
    EmployeeID,
    Department,
    JobRole,
    ActiveStatus,
    COUNT(*) AS Row_Occurrences
FROM Dim_Employees
GROUP BY EmployeeID, Department, JobRole, ActiveStatus
HAVING COUNT(*) > 1;


-- -----------------------------------------------------------------------------------------
-- QUERY 21: Rolling Annual Headcount Movement (Inflow vs. Outflow)
-- Purpose: Reviews corporate headcounts. Calculates the quarterly headcount net variance
--          (new hires minus resignations/terminations).
-- -----------------------------------------------------------------------------------------
SELECT
    DATETRUNC(quarter, DateLogged) AS Fiscal_Quarter,
    SUM(CASE WHEN TransactionType = 'Hire' THEN 1 ELSE 0 END) AS New_Hires,
    SUM(CASE WHEN TransactionType = 'Termination' THEN 1 ELSE 0 END) AS Employee_Exits,
    SUM(CASE WHEN TransactionType = 'Hire' THEN 1 ELSE -1 END) AS Net_Headcount_Variance
FROM Fact_Headcount_Logs
GROUP BY DATETRUNC(quarter, DateLogged)
ORDER BY Fiscal_Quarter;


-- -----------------------------------------------------------------------------------------
-- QUERY 22: HR Executive Consolidated Scorecard Matrix
-- Purpose: Generates a complete cross-tabulation of headcount, average salaries,
--          voluntary losses, and turnover ratings by department for executive reviews.
-- -----------------------------------------------------------------------------------------
WITH DepartmentSalaries AS (
    SELECT
        de.Department,
        AVG(fc.BaseSalary) AS Average_Base_Salary,
        AVG(fc.BaseSalary / fc.MarketMedianSalary) AS Average_Compa_Ratio
    FROM Dim_Employees de
    JOIN Fact_Compensation fc ON de.EmployeeID = fc.EmployeeID
    WHERE de.ActiveStatus = 'Active'
    GROUP BY de.Department
),
DepartmentAttrition AS (
    SELECT
        Department,
        COUNT(EmployeeID) AS Staff_Sample_Size,
        SUM(CASE WHEN ActiveStatus = 'Terminated' AND TerminationType = 'Voluntary' THEN 1 ELSE 0 END) AS Voluntary_Losses
    FROM Dim_Employees
    GROUP BY Department
)
SELECT
    ds.Department,
    da.Staff_Sample_Size AS Active_Departmental_Headcount,
    ROUND(ds.Average_Base_Salary, 2) AS Avg_Active_Salary,
    ROUND(ds.Average_Compa_Ratio * 100.0, 2) AS Average_Compa_Ratio_Percent,
    da.Voluntary_Losses AS Voluntary_Departures,
    ROUND((da.Voluntary_Losses * 100.0) / da.Staff_Sample_Size, 2) AS Departmental_Attrition_Rate_Percent
FROM DepartmentSalaries ds
JOIN DepartmentAttrition da ON ds.Department = da.Department
ORDER BY Departmental_Attrition_Rate_Percent DESC;
