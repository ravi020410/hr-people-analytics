-- 02_data_quality_checks.sql
-- Detection queries for the 6 known data-quality issues in this dataset.
-- Run against the raw load to reproduce the audit; run against
-- analytics.employees after cleaning to confirm each fix.

-- 1. Duplicate employee_id records
SELECT employee_id, COUNT(*) AS occurrences
FROM analytics.employees
GROUP BY employee_id
HAVING COUNT(*) > 1;

-- 2. Inconsistent department label casing/whitespace
SELECT DISTINCT department FROM analytics.employees ORDER BY department;

-- 3. Status-sync gap: active_status = 0 but no termination_date
SELECT COUNT(*) AS status_sync_gap_rows,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM analytics.employees WHERE active_status = 0), 2) AS pct_of_departed
FROM analytics.employees
WHERE active_status = 0 AND termination_date IS NULL;

-- 4. hire_date after termination_date (logically impossible)
SELECT employee_id, hire_date, termination_date
FROM analytics.employees
WHERE termination_date IS NOT NULL AND hire_date > termination_date;

-- 5. Zero or negative distance_from_home_miles
SELECT COUNT(*) AS invalid_distance_rows
FROM analytics.employees
WHERE distance_from_home_miles <= 0;

-- 6. Zero or negative base_salary
SELECT employee_id, base_salary FROM analytics.compensation WHERE base_salary <= 0;

-- 7. Performance scores outside the valid 1-5 range
SELECT review_id, employee_id, performance_score
FROM analytics.performance_reviews
WHERE performance_score NOT BETWEEN 1 AND 5;

-- 8. Exit survey rows referencing an employee_id that doesn't exist
SELECT es.exit_survey_id, es.employee_id
FROM analytics.exit_surveys es
LEFT JOIN analytics.employees e ON es.employee_id = e.employee_id
WHERE e.employee_id IS NULL;
