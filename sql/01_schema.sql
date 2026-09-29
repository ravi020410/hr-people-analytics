-- 01_schema.sql
-- PostgreSQL DDL for the HR people-analytics schema. Every table/column name
-- here is used verbatim in 03_business_analysis_queries.sql and matches what
-- scripts/clean_and_load.py actually loads.

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.departments (
    department_id     INTEGER PRIMARY KEY,
    department_name    VARCHAR(50) NOT NULL,
    division             VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS analytics.employees (
    employee_id             VARCHAR(20) PRIMARY KEY,
    department                VARCHAR(50) NOT NULL,
    job_role                    VARCHAR(50) NOT NULL,
    job_level                     SMALLINT NOT NULL,
    gender                         VARCHAR(20) NOT NULL,
    age                             SMALLINT NOT NULL,
    education_level                   VARCHAR(20) NOT NULL,
    marital_status                     VARCHAR(20) NOT NULL,
    hire_date                            DATE NOT NULL,
    termination_date                       DATE,                        -- NULL = still active OR a status-sync gap (see data_quality_flag)
    termination_reason                       VARCHAR(30),
    active_status                              SMALLINT NOT NULL,        -- 1 = active, 0 = departed
    distance_from_home_miles                     NUMERIC(6,1) NOT NULL,
    remote_flag                                    BOOLEAN NOT NULL,
    data_quality_flag                                VARCHAR(30),        -- e.g. 'MISSING_TERM_DATE'
    is_valid_distance                                  BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS analytics.compensation (
    employee_id      VARCHAR(20) REFERENCES analytics.employees(employee_id),
    base_salary        NUMERIC(10,2) NOT NULL,
    bonus_target_pct     NUMERIC(5,2) NOT NULL,
    last_raise_pct         NUMERIC(5,2) NOT NULL,
    is_valid_salary          BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS analytics.performance_reviews (
    review_id           INTEGER PRIMARY KEY,
    employee_id           VARCHAR(20) REFERENCES analytics.employees(employee_id),
    review_date             DATE NOT NULL,
    performance_score         SMALLINT NOT NULL,     -- valid range 1-5, see is_valid_score
    promotion_flag               BOOLEAN NOT NULL,
    is_valid_score                  BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS analytics.exit_surveys (
    exit_survey_id             INTEGER PRIMARY KEY,
    employee_id                  VARCHAR(20) REFERENCES analytics.employees(employee_id),
    exit_date                      DATE NOT NULL,
    reason                            VARCHAR(30) NOT NULL,
    satisfaction_score                 SMALLINT NOT NULL,
    work_life_balance_score              SMALLINT NOT NULL,
    would_recommend                        BOOLEAN NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_employees_dept ON analytics.employees(department);
CREATE INDEX IF NOT EXISTS idx_comp_employee ON analytics.compensation(employee_id);
CREATE INDEX IF NOT EXISTS idx_perf_employee ON analytics.performance_reviews(employee_id);
CREATE INDEX IF NOT EXISTS idx_exit_employee ON analytics.exit_surveys(employee_id);
