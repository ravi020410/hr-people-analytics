"""
HR People Analytics - Attrition and Compensation Data Pipeline.

Generates synthetic employee, salary, and exit survey data, then produces
clean analytical summaries for attrition and compensation-risk reporting.
"""

from __future__ import annotations

import os

import numpy as np
import pandas as pd


def generate_hr_data(num_employees: int = 1200) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    np.random.seed(204)

    departments = ["Engineering", "Sales", "Operations", "Finance", "HR", "Marketing", "Customer Success"]
    roles = {
        "Engineering": ["Software Engineer", "Data Engineer", "QA Analyst", "Engineering Manager"],
        "Sales": ["Account Executive", "Sales Manager", "Sales Operations Analyst"],
        "Operations": ["Operations Analyst", "Supply Chain Manager", "Process Lead"],
        "Finance": ["Financial Analyst", "Controller", "FP&A Manager"],
        "HR": ["HR Business Partner", "Recruiter", "People Operations Analyst"],
        "Marketing": ["Marketing Analyst", "Campaign Manager", "Content Strategist"],
        "Customer Success": ["CS Manager", "Support Specialist", "Implementation Consultant"],
    }

    employee_ids = [f"EMP-{10000 + i}" for i in range(num_employees)]
    department_values = np.random.choice(departments, num_employees, p=[0.30, 0.16, 0.14, 0.10, 0.08, 0.10, 0.12])
    tenure = np.random.gamma(2.2, 1.7, num_employees).clip(0.1, 14).round(1)
    performance = np.random.choice([1, 2, 3, 4], num_employees, p=[0.08, 0.24, 0.46, 0.22])
    salary_deviation = np.random.normal(-0.02, 0.09, num_employees)

    base_attrition_risk = 0.08 + (tenure < 1.5) * 0.09 + (salary_deviation < -0.08) * 0.16
    base_attrition_risk += (department_values == "Engineering") * 0.05 + (performance >= 3) * (salary_deviation < -0.08) * 0.09
    exited = np.random.random(num_employees) < np.clip(base_attrition_risk, 0.03, 0.55)

    employees = pd.DataFrame(
        {
            "EmployeeID": employee_ids,
            "Department": department_values,
            "JobRole": [np.random.choice(roles[d]) for d in department_values],
            "Age": np.random.randint(22, 61, num_employees),
            "Gender": np.random.choice(["Female", "Male", "Nonbinary"], num_employees, p=[0.48, 0.50, 0.02]),
            "TenureYears": tenure,
            "PerformanceScore": performance,
            "ActiveStatus": np.where(exited, 0, 1),
        }
    )

    role_base = {
        "Software Engineer": 118000,
        "Data Engineer": 124000,
        "QA Analyst": 86000,
        "Engineering Manager": 152000,
        "Account Executive": 92000,
        "Sales Manager": 128000,
        "Sales Operations Analyst": 88000,
        "Operations Analyst": 76000,
        "Supply Chain Manager": 104000,
        "Process Lead": 98000,
        "Financial Analyst": 84000,
        "Controller": 132000,
        "FP&A Manager": 126000,
        "HR Business Partner": 88000,
        "Recruiter": 76000,
        "People Operations Analyst": 78000,
        "Marketing Analyst": 76000,
        "Campaign Manager": 92000,
        "Content Strategist": 78000,
        "CS Manager": 94000,
        "Support Specialist": 62000,
        "Implementation Consultant": 98000,
    }
    market = np.array([role_base[r] for r in employees["JobRole"]])
    salaries = pd.DataFrame(
        {
            "EmployeeID": employee_ids,
            "EmployeeSalary": np.round(market * (1 + salary_deviation), 2),
            "MarketBenchmarkSalary": market,
            "SalaryDeviationPct": np.round(salary_deviation * 100, 2),
        }
    )

    exit_reason = np.random.choice(
        ["Compensation", "Career Progression", "Workplace Culture", "Manager Fit", "Relocation"],
        num_employees,
        p=[0.34, 0.27, 0.18, 0.13, 0.08],
    )
    surveys = pd.DataFrame(
        {
            "EmployeeID": employee_ids,
            "JobSatisfaction": np.where(exited, np.random.randint(1, 4, num_employees), np.random.randint(3, 6, num_employees)),
            "WorkLifeBalance": np.where(exited, np.random.randint(1, 4, num_employees), np.random.randint(3, 6, num_employees)),
            "PrimaryExitReason": np.where(exited, exit_reason, "Active Employee"),
        }
    )

    return employees, salaries, surveys


def build_summaries(employees: pd.DataFrame, salaries: pd.DataFrame, surveys: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    employee_salary = employees.merge(salaries, on="EmployeeID")
    department_summary = (
        employee_salary.groupby("Department")
        .agg(
            TotalHeadcount=("EmployeeID", "count"),
            VoluntaryExits=("ActiveStatus", lambda s: int((s == 0).sum())),
            AverageTenureYears=("TenureYears", "mean"),
            AverageSalaryDeviationPct=("SalaryDeviationPct", "mean"),
        )
        .reset_index()
    )
    department_summary["AttritionRatePct"] = (
        department_summary["VoluntaryExits"] / department_summary["TotalHeadcount"] * 100
    ).round(2)
    department_summary["AverageTenureYears"] = department_summary["AverageTenureYears"].round(1)
    department_summary["AverageSalaryDeviationPct"] = department_summary["AverageSalaryDeviationPct"].round(2)

    risk = employee_salary.merge(surveys, on="EmployeeID")
    risk["PayCompetitivenessBucket"] = pd.cut(
        risk["SalaryDeviationPct"],
        bins=[-100, -15, -5, 5, 100],
        labels=["Severely Underpaid", "Underpaid", "Paid to Market", "Well Paid"],
    )
    compensation_summary = (
        risk.groupby("PayCompetitivenessBucket", observed=False)
        .agg(
            EmployeeCount=("EmployeeID", "count"),
            VoluntaryExits=("ActiveStatus", lambda s: int((s == 0).sum())),
            AverageDeviationPct=("SalaryDeviationPct", "mean"),
            AverageJobSatisfaction=("JobSatisfaction", "mean"),
        )
        .reset_index()
    )
    compensation_summary["AttritionRatePct"] = (
        compensation_summary["VoluntaryExits"] / compensation_summary["EmployeeCount"] * 100
    ).round(2)
    compensation_summary["AverageDeviationPct"] = compensation_summary["AverageDeviationPct"].round(2)
    compensation_summary["AverageJobSatisfaction"] = compensation_summary["AverageJobSatisfaction"].round(2)
    return department_summary, compensation_summary


if __name__ == "__main__":
    os.makedirs("data", exist_ok=True)
    employees_df, salaries_df, surveys_df = generate_hr_data()
    department_kpis, compensation_kpis = build_summaries(employees_df, salaries_df, surveys_df)

    employees_df.to_csv("data/employees.csv", index=False)
    salaries_df.to_csv("data/salaries.csv", index=False)
    surveys_df.to_csv("data/exit_surveys.csv", index=False)
    department_kpis.to_csv("data/department_attrition_summary.csv", index=False)
    compensation_kpis.to_csv("data/compensation_risk_summary.csv", index=False)

    print("Generated HR analytics datasets and KPI summaries in data/.")
