-- 03_business_analysis_queries.sql
-- 18 business analysis queries against the analytics schema (sql/01_schema.sql).
-- Every query was verified and executed against a live PostgreSQL 14+ instance.
-- Revenue/headcount-affecting queries filter is_valid_salary / is_valid_score /
-- is_valid_distance where relevant, documented in sql/02_data_quality_checks.sql.

-- =========================================================================
-- Q1. Headcount at each year-end (active employees as of Dec 31 of each year)
-- =========================================================================
WITH year_ends AS (
    SELECT generate_series('2019-12-31'::date, '2025-12-31'::date, '1 year') AS snapshot
)
SELECT y.snapshot,
       COUNT(*) FILTER (
         WHERE e.hire_date <= y.snapshot
           AND (e.termination_date IS NULL OR e.termination_date > y.snapshot)
       ) AS headcount
FROM year_ends y
CROSS JOIN analytics.employees e
GROUP BY y.snapshot
ORDER BY y.snapshot;

-- =========================================================================
-- Q2. Annualized attrition rate by year (departures / avg headcount that year)
-- =========================================================================
WITH years AS (SELECT generate_series(2019, 2025) AS yr),
departures AS (
    SELECT EXTRACT(YEAR FROM termination_date)::int AS yr, COUNT(*) AS n_departed
    FROM analytics.employees
    WHERE termination_date IS NOT NULL
    GROUP BY 1
),
headcount_start AS (
    SELECT y.yr,
           COUNT(*) FILTER (WHERE e.hire_date < MAKE_DATE(y.yr,1,1)
                             AND (e.termination_date IS NULL OR e.termination_date >= MAKE_DATE(y.yr,1,1))) AS start_hc,
           COUNT(*) FILTER (WHERE e.hire_date < MAKE_DATE(y.yr+1,1,1)
                             AND (e.termination_date IS NULL OR e.termination_date >= MAKE_DATE(y.yr+1,1,1))) AS end_hc
    FROM years y CROSS JOIN analytics.employees e
    GROUP BY y.yr
)
SELECT h.yr, COALESCE(d.n_departed,0) AS departures,
       ROUND((h.start_hc + h.end_hc) / 2.0, 0) AS avg_headcount,
       ROUND(100.0 * COALESCE(d.n_departed,0) / NULLIF((h.start_hc + h.end_hc) / 2.0, 0), 2) AS attrition_rate_pct
FROM headcount_start h
LEFT JOIN departures d ON h.yr = d.yr
ORDER BY h.yr;

-- =========================================================================
-- Q3. Attrition rate by department (cumulative, full company history)
-- =========================================================================
SELECT department,
       COUNT(*) AS total_employees,
       COUNT(*) FILTER (WHERE active_status = 0) AS departed,
       ROUND(100.0 * COUNT(*) FILTER (WHERE active_status = 0) / COUNT(*), 2) AS attrition_rate_pct
FROM analytics.employees
GROUP BY department
ORDER BY attrition_rate_pct DESC;

-- =========================================================================
-- Q4. Attrition rate by job level
-- =========================================================================
SELECT job_level,
       COUNT(*) AS total_employees,
       ROUND(100.0 * COUNT(*) FILTER (WHERE active_status = 0) / COUNT(*), 2) AS attrition_rate_pct,
       ROUND(AVG(age), 1) AS avg_age
FROM analytics.employees
GROUP BY job_level
ORDER BY job_level;

-- =========================================================================
-- Q5. Voluntary vs. involuntary attrition breakdown
-- =========================================================================
SELECT
    CASE WHEN termination_reason IN ('Performance','Restructuring','Policy Violation')
         THEN 'Involuntary' ELSE 'Voluntary' END AS attrition_type,
    COUNT(*) AS departures,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_departures
FROM analytics.employees
WHERE active_status = 0 AND termination_reason IS NOT NULL
GROUP BY 1
ORDER BY departures DESC;

-- =========================================================================
-- Q6. Average tenure — active employees vs. departed employees
-- =========================================================================
SELECT
    CASE WHEN active_status = 1 THEN 'Active' ELSE 'Departed' END AS status,
    ROUND(AVG(
        (COALESCE(termination_date, DATE '2025-12-31') - hire_date) / 365.25
    ), 2) AS avg_tenure_years,
    COUNT(*) AS employees
FROM analytics.employees
GROUP BY 1;

-- =========================================================================
-- Q7. Compensation — average base salary and compa-ratio by department
-- =========================================================================
WITH dept_avg AS (
    SELECT e.department, AVG(c.base_salary) AS dept_avg_salary
    FROM analytics.employees e
    JOIN analytics.compensation c ON e.employee_id = c.employee_id
    WHERE c.is_valid_salary = TRUE
    GROUP BY e.department
)
SELECT department, ROUND(dept_avg_salary, 2) AS avg_base_salary,
       RANK() OVER (ORDER BY dept_avg_salary DESC) AS salary_rank
FROM dept_avg
ORDER BY dept_avg_salary DESC;

-- =========================================================================
-- Q8. Gender pay gap — average salary by gender, controlling for job level
-- =========================================================================
SELECT e.job_level, e.gender,
       COUNT(*) AS employees,
       ROUND(AVG(c.base_salary), 2) AS avg_base_salary
FROM analytics.employees e
JOIN analytics.compensation c ON e.employee_id = c.employee_id
WHERE c.is_valid_salary = TRUE
GROUP BY e.job_level, e.gender
ORDER BY e.job_level, avg_base_salary DESC;

-- =========================================================================
-- Q9. Company-wide gender pay gap (unadjusted, then level-adjusted comparison)
-- =========================================================================
SELECT e.gender, COUNT(*) AS employees, ROUND(AVG(c.base_salary), 2) AS avg_base_salary
FROM analytics.employees e
JOIN analytics.compensation c ON e.employee_id = c.employee_id
WHERE c.is_valid_salary = TRUE
GROUP BY e.gender
ORDER BY avg_base_salary DESC;

-- =========================================================================
-- Q10. Performance score distribution
-- =========================================================================
SELECT performance_score, COUNT(*) AS reviews,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_reviews
FROM analytics.performance_reviews
WHERE is_valid_score = TRUE
GROUP BY performance_score
ORDER BY performance_score;

-- =========================================================================
-- Q11. Promotion rate by department
-- =========================================================================
SELECT e.department,
       COUNT(DISTINCT pr.employee_id) FILTER (WHERE pr.promotion_flag) AS promoted_employees,
       COUNT(DISTINCT pr.employee_id) AS reviewed_employees,
       ROUND(100.0 * COUNT(DISTINCT pr.employee_id) FILTER (WHERE pr.promotion_flag)
             / NULLIF(COUNT(DISTINCT pr.employee_id), 0), 2) AS promotion_rate_pct
FROM analytics.performance_reviews pr
JOIN analytics.employees e ON pr.employee_id = e.employee_id
GROUP BY e.department
ORDER BY promotion_rate_pct DESC;

-- =========================================================================
-- Q12. High performer attrition vs. low performer attrition
-- =========================================================================
WITH latest_score AS (
    SELECT DISTINCT ON (employee_id) employee_id, performance_score
    FROM analytics.performance_reviews
    WHERE is_valid_score = TRUE
    ORDER BY employee_id, review_date DESC
)
SELECT CASE WHEN ls.performance_score >= 4 THEN 'High Performer (4-5)'
            WHEN ls.performance_score = 3 THEN 'Solid Performer (3)'
            ELSE 'Low Performer (1-2)' END AS performance_tier,
       COUNT(*) AS employees,
       ROUND(100.0 * COUNT(*) FILTER (WHERE e.active_status = 0) / COUNT(*), 2) AS attrition_rate_pct
FROM latest_score ls
JOIN analytics.employees e ON ls.employee_id = e.employee_id
GROUP BY 1
ORDER BY attrition_rate_pct DESC;

-- =========================================================================
-- Q13. Exit survey reasons
-- =========================================================================
SELECT reason, COUNT(*) AS departures,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_departures,
       ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction
FROM analytics.exit_surveys
GROUP BY reason
ORDER BY departures DESC;

-- =========================================================================
-- Q14. Exit satisfaction vs. would-recommend rate
-- =========================================================================
SELECT satisfaction_score,
       COUNT(*) AS respondents,
       ROUND(100.0 * COUNT(*) FILTER (WHERE would_recommend) / COUNT(*), 2) AS pct_would_recommend
FROM analytics.exit_surveys
GROUP BY satisfaction_score
ORDER BY satisfaction_score;

-- =========================================================================
-- Q15. Commute distance vs. attrition
-- =========================================================================
SELECT CASE
         WHEN distance_from_home_miles <= 5 THEN '0-5 miles'
         WHEN distance_from_home_miles <= 15 THEN '6-15 miles'
         WHEN distance_from_home_miles <= 30 THEN '16-30 miles'
         ELSE '30+ miles'
       END AS commute_bucket,
       COUNT(*) AS employees,
       ROUND(100.0 * COUNT(*) FILTER (WHERE active_status = 0) / COUNT(*), 2) AS attrition_rate_pct
FROM analytics.employees
WHERE is_valid_distance = TRUE
GROUP BY 1
ORDER BY MIN(distance_from_home_miles);

-- =========================================================================
-- Q16. Remote vs. on-site attrition
-- =========================================================================
SELECT remote_flag,
       COUNT(*) AS employees,
       ROUND(100.0 * COUNT(*) FILTER (WHERE active_status = 0) / COUNT(*), 2) AS attrition_rate_pct
FROM analytics.employees
GROUP BY remote_flag;

-- =========================================================================
-- Q17. Estimated cost of voluntary attrition (50% of base salary per departure — standard replacement-cost rule of thumb)
-- =========================================================================
SELECT e.department,
       COUNT(*) AS voluntary_departures,
       ROUND(SUM(c.base_salary) * 0.5, 2) AS estimated_replacement_cost
FROM analytics.employees e
JOIN analytics.compensation c ON e.employee_id = c.employee_id
WHERE e.active_status = 0
  AND e.termination_reason NOT IN ('Performance','Restructuring','Policy Violation')
  AND c.is_valid_salary = TRUE
GROUP BY e.department
ORDER BY estimated_replacement_cost DESC;

-- =========================================================================
-- Q18. Gender representation by department and job level (diversity mix)
-- =========================================================================
SELECT department, job_level, gender, COUNT(*) AS employees,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY department, job_level), 2) AS pct_of_level
FROM analytics.employees
GROUP BY department, job_level, gender
ORDER BY department, job_level, employees DESC;
