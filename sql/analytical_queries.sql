-- =========================================================================================
-- HR People Analytics & Retention - Analytical Queries
-- Author: Ravikant Yadav
-- Database Platform: SQL Server (T-SQL) / PostgreSQL Compatible
-- Description: This script contains advanced SQL queries executed to transform and analyze
--              employee demographic and compensation logs. It showcases SQL indicators for
--              attrition rates, average tenure, and salary deviations from market benchmarks.
-- =========================================================================================

-- -----------------------------------------------------------------------------------------
-- QUERY 1: Database Relationship Verification
-- Purpose: Inspect join integrity between employee records, compensation tables, and surveys.
-- -----------------------------------------------------------------------------------------

SELECT TOP 5
    e.EmployeeID,
    e.Department,
    e.JobRole,
    e.TenureYears,
    e.ActiveStatus,
    s.EmployeeSalary,
    s.MarketBenchmarkSalary,
    v.JobSatisfaction,
    v.WorkLifeBalance
FROM Dim_Employee e
JOIN Fact_Salaries s ON e.EmployeeID = s.EmployeeID
LEFT JOIN Exit_Surveys v ON e.EmployeeID = v.EmployeeID;


-- -----------------------------------------------------------------------------------------
-- QUERY 2: Departmental Attrition Rate & Average Tenure Analysis
-- Techniques Used: CASE WHEN, Aggregate Calculations, Numeric Casting
-- Purpose: Calculate total headcount, voluntary exits, and voluntary attrition rates by
--          department to locate high-turnover areas.
-- -----------------------------------------------------------------------------------------

SELECT
    Department,
    COUNT(EmployeeID) AS TotalHeadcount,
    -- Count of employees who voluntarily exited (ActiveStatus = 0)
    SUM(CASE WHEN ActiveStatus = 0 THEN 1 ELSE 0 END) AS VoluntaryExits,
    -- Calculate Attrition Rate %
    ROUND(
        (SUM(CASE WHEN ActiveStatus = 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(EmployeeID),
        2
    ) AS AttritionRatePct,
    -- Average tenure of employees in years
    ROUND(AVG(CAST(TenureYears AS DECIMAL(10,2))), 1) AS AverageTenureYears
FROM Dim_Employee
GROUP BY Department
ORDER BY AttritionRatePct DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 3: Compensation Competitiveness & Salary Deviation Tracker
-- Techniques Used: CTEs, Subqueries, Relational Joins, Mathematical Calculations
-- Purpose: Isolate employees who are undercompensated relative to market averages and track
--          their corresponding attrition rate.
-- -----------------------------------------------------------------------------------------

WITH SalaryAnalysis AS (
    SELECT
        e.EmployeeID,
        e.Department,
        e.JobRole,
        e.ActiveStatus,
        e.PerformanceScore,
        s.EmployeeSalary,
        s.MarketBenchmarkSalary,
        -- Calculate percentage deviation from the local market standard
        ROUND(((s.EmployeeSalary - s.MarketBenchmarkSalary) / s.MarketBenchmarkSalary) * 100, 2) AS SalaryDeviationPct
    FROM Dim_Employee e
    JOIN Fact_Salaries s ON e.EmployeeID = s.EmployeeID
),
UnderpaidBuckets AS (
    SELECT
        EmployeeID,
        Department,
        ActiveStatus,
        PerformanceScore,
        SalaryDeviationPct,
        CASE
            WHEN SalaryDeviationPct <= -15 THEN 'Severely Underpaid (<-15%)'
            WHEN SalaryDeviationPct BETWEEN -14.99 AND -5 THEN 'Underpaid (-5% to -15%)'
            WHEN SalaryDeviationPct BETWEEN -4.99 AND 5 THEN 'Paid to Market (-5% to +5%)'
            ELSE 'Well Paid (>+5%)'
        END AS PayCompetitivenessBucket
    FROM SalaryAnalysis
)
SELECT
    PayCompetitivenessBucket,
    COUNT(EmployeeID) AS EmployeeCount,
    SUM(CASE WHEN ActiveStatus = 0 THEN 1 ELSE 0 END) AS VoluntaryExits,
    -- Rate of attrition within each compensation bucket
    ROUND((SUM(CASE WHEN ActiveStatus = 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(EmployeeID), 2) AS AttritionRatePct,
    ROUND(AVG(SalaryDeviationPct), 2) AS AverageDeviationPct,
    -- Number of high performers (PerformanceScore >= 3) who exited in this bucket
    SUM(CASE WHEN ActiveStatus = 0 AND PerformanceScore >= 3 THEN 1 ELSE 0 END) AS HighPerformerExits
FROM UnderpaidBuckets
GROUP BY PayCompetitivenessBucket
ORDER BY AverageDeviationPct ASC;


-- -----------------------------------------------------------------------------------------
-- QUERY 4: Attrition Factor Mapping (Exit Survey Sentiment Correlation)
-- Techniques Used: CASE WHEN, Joins, Multi-Group Aggregations
-- Purpose: Correlate employee scores for job satisfaction and work-life balance with their
--          actual exit reasons to identify operational issues.
-- -----------------------------------------------------------------------------------------

SELECT
    e.Department,
    COUNT(e.EmployeeID) AS TotalExits,
    -- Core average feedback ratings from exit surveys (1-5 scale)
    ROUND(AVG(CAST(v.JobSatisfaction AS DECIMAL(10,2))), 2) AS AvgJobSatisfactionRating,
    ROUND(AVG(CAST(v.WorkLifeBalance AS DECIMAL(10,2))), 2) AS AvgWorkLifeBalanceRating,
    -- Map dominant voluntary exit reasons
    SUM(CASE WHEN v.PrimaryExitReason = 'Compensation' THEN 1 ELSE 0 END) AS ExitReason_Compensation,
    SUM(CASE WHEN v.PrimaryExitReason = 'Career Progression' THEN 1 ELSE 0 END) AS ExitReason_CareerProgression,
    SUM(CASE WHEN v.PrimaryExitReason = 'Workplace Culture' THEN 1 ELSE 0 END) AS ExitReason_Culture
FROM Dim_Employee e
JOIN Exit_Surveys v ON e.EmployeeID = v.EmployeeID
WHERE e.ActiveStatus = 0 -- Only focus on employees who exited
GROUP BY e.Department
ORDER BY TotalExits DESC;


-- -----------------------------------------------------------------------------------------
-- QUERY 5: Employee Performance vs. Salary Compression Analysis
-- Techniques Used: CTEs, Window Functions (DENSE_RANK), Partitioning
-- Purpose: Highlight high-performing employees whose salaries are compressed (lower than
--          the average salary of lower-performing peers in the same department).
-- -----------------------------------------------------------------------------------------

WITH DepartmentPerformanceMetrics AS (
    SELECT
        e.Department,
        e.PerformanceScore,
        AVG(s.EmployeeSalary) AS AvgSalaryForPerformanceTier
    FROM Dim_Employee e
    JOIN Fact_Salaries s ON e.EmployeeID = s.EmployeeID
    WHERE e.ActiveStatus = 1 -- Only look at active employee cohorts
    GROUP BY e.Department, e.PerformanceScore
)
SELECT
    e.EmployeeID,
    e.Department,
    e.PerformanceScore,
    s.EmployeeSalary,
    ROUND(p.AvgSalaryForPerformanceTier, 2) AS DeptAverageForTier,
    -- Isolate high performers underpaid compared to department average
    CASE
        WHEN e.PerformanceScore = 4 AND s.EmployeeSalary < p.AvgSalaryForPerformanceTier THEN 'Retention Alert: Critical Talent Underpaid'
        WHEN e.PerformanceScore = 3 AND s.EmployeeSalary < p.AvgSalaryForPerformanceTier THEN 'High Performer Compressed'
        ELSE 'Salary Aligned'
    END AS RetentionRiskAssessment
FROM Dim_Employee e
JOIN Fact_Salaries s ON e.EmployeeID = s.EmployeeID
JOIN DepartmentPerformanceMetrics p ON e.Department = p.Department AND e.PerformanceScore = p.PerformanceScore
WHERE e.ActiveStatus = 1 AND e.PerformanceScore >= 3
ORDER BY e.Department, e.PerformanceScore DESC, s.EmployeeSalary ASC;
