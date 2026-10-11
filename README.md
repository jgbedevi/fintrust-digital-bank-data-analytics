# FinTrust Digital Bank: Data Analytics Track

**Programme:** AnalystLab Africa, Experience Lab Internship
**Project:** FinTrust Financial Intelligence & Digital Banking Support Solution
**Track:** Data Analytics
**Intern:** Yawa Jacqueline GBEDEVI

## About this repository

This repository contains my work for the FinTrust Digital Bank project across the four weeks of the AnalystLab Africa Experience Lab. FinTrust is a fictional digital bank built for this programme. All customer and transaction data is synthetic and intended for educational purposes only.

The project starts from two datasets (1,500 customers and 12,000 transactions, January to March 2026) and ends with a tested Power BI dashboard, SQL and Python analyses, validated business insights and recommendations.

**Tools:** Excel, SQL (DuckDB), Python (pandas, SciPy, statsmodels, scikit-learn, Matplotlib, Seaborn), Power BI, Word, GitHub.

## Repository structure

```
week1/   Understand & Plan
week2/   Analyse & Prepare
week3/   Develop & Integrate
week4/   Test, Refine & Present (final submission)
```

## Progress

### Week 1: Understand & Plan
Business understanding, resource review, data profiling, analytical questions, KPI planning, and dashboard wireframe.
- [`FinTrust_Week1_DataAnalytics_GBEDEVI_EN.docx`](week1/FinTrust_Week1_DataAnalytics_GBEDEVI_EN.docx)

### Week 2: Analyse & Prepare
Data cleaning and data quality report, first KPIs, first SQL analysis and the first set of business findings.
- _Add the Week 2 files and their links here._

### Week 3: Develop & Integrate
Deeper analysis, five Python charts, SQL analysis, first full four-page Power BI dashboard, validated findings and recommendations.
- [`FinTrust_Week3_KPI_Analysis.docx`](week3/FinTrust_Week3_KPI_Analysis.docx)
- [`FinTrust_Week3_Findings.docx`](week3/FinTrust_Week3_Findings.docx)
- [`FinTrust_Week3_Recommandations.docx`](week3/FinTrust_Week3_Recommandations.docx)
- [`FinTrust_Week3_Documentation.docx`](week3/FinTrust_Week3_Documentation.docx)
- [`FinTrust_Week3_SQL_Analysis.sql`](week3/FinTrust_Week3_SQL_Analysis.sql)
- [`FinTrust_Week3_Python_Analysis.ipynb`](week3/FinTrust_Week3_Python_Analysis.ipynb)
- [`FinTrust_Week3_Dashboard.pdf`](week3/FinTrust_Week3_Dashboard.pdf)

### Week 4: Test, Refine & Present
Final version of the work, with testing, validation and documentation. The full instructions to install, run and read the results are in [`week4/README.md`](week4/README.md).

| Deliverable | File |
|---|---|
| Final report (review, SQL, dashboard, insights, validation, limitations) | [`week4/docs/FinTrust_Week4_Final_Report.docx`](week4/docs/FinTrust_Week4_Final_Report.docx) |
| Final SQL (10 business queries) | [`week4/sql/FinTrust_Week4_Final_SQL.sql`](week4/sql/FinTrust_Week4_Final_SQL.sql) |
| Final Python notebook (executed) | [`week4/notebooks/FinTrust_Week4_Final_Analysis.ipynb`](week4/notebooks/FinTrust_Week4_Final_Analysis.ipynb) |
| Final dashboard (Power BI file and PDF export) | _Add the link to the .pbix and the PDF._ |
| Presentation slides | [`week4/docs/FinTrust_Week4_Presentation.pptx`](week4/docs/FinTrust_Week4_Presentation.pptx) |

**Main results of the final week**
- 21 of 21 dashboard values matched an independent recalculation in Python, and 12 of 12 data quality tests passed.
- The average transaction (46,706 NGN) is about 4.5 times the median (10,306 NGN). About 12% of transactions carry 62% of the total value.
- The Mobile App has the most failed transactions because it carries the most traffic. A higher failure rate is not proven once the test is corrected for several comparisons.
- The risk review flag follows international status, transaction type (Transfer, Cash Withdrawal) and amounts above about 118,000 NGN. Customer segment adds nothing.
- Six findings were re-tested with a second method. All held, and two needed a more careful wording.

## Disclaimer

FinTrust Digital Bank is a fictional organisation created for the AnalystLab Africa Experience Lab. All customer and transaction data used is synthetic and intended for educational purposes only. `Risk_Review_Flag` is an educational label and is not a real fraud determination. Nothing in this repository is a production banking system or financial advice.
