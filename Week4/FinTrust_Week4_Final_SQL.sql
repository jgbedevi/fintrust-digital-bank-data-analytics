/* ============================================================
   FinTrust Digital Bank - Week 4 Final SQL Analysis
   Track: Data Analytics
   Author: Yawa Jacqueline GBEDEVI
   Engine: DuckDB (works in DBeaver or with sql/run_sql.py)

   Purpose: the 10 most important business queries of the project,
   rewritten and re-tested for the final submission. Every result
   below was re-run on the cleaned data and compared with the
   Power BI dashboard and the Python notebook.

   Tables
     customers    <- data/FinTrust_Customer_Data.csv (1,500 rows)
     transactions <- data/FinTrust_Transaction_Data_Clean.csv (12,000 rows)
                     (188 rows with a missing Device_Type or Location
                      carry the value 'Not Provided')

   Run from the week4/ folder so the relative paths work.
   ============================================================ */

CREATE OR REPLACE TABLE customers AS
SELECT * FROM read_csv_auto('data/FinTrust_Customer_Data.csv');

CREATE OR REPLACE TABLE transactions AS
SELECT * FROM read_csv_auto('data/FinTrust_Transaction_Data_Clean.csv');

-- Working view: 0/1 indicators make every rate a simple AVG().
CREATE OR REPLACE VIEW tx AS
SELECT t.*,
       c.Customer_Segment, c.Account_Status, c.Preferred_Channel,
       c.Monthly_Income_Band, c.City,
       CASE WHEN International_Transaction = 'Yes' THEN 1 ELSE 0 END AS is_intl,
       CASE WHEN Risk_Review_Flag          = 'Yes' THEN 1 ELSE 0 END AS is_flagged,
       CASE WHEN Transaction_Status = 'Successful' THEN 1 ELSE 0 END AS is_success,
       CASE WHEN Transaction_Status = 'Failed'     THEN 1 ELSE 0 END AS is_failed,
       CAST(Transaction_DateTime AS DATE) AS tx_date,
       CASE WHEN Amount_NGN < 10000      THEN '1. <10k'
            WHEN Amount_NGN < 50000      THEN '2. 10k-50k'
            WHEN Amount_NGN < 117922.86  THEN '3. 50k-118k'
            ELSE                              '4. >118k' END AS amount_band
FROM transactions t
JOIN customers c USING (Customer_ID);


/* ------------------------------------------------------------
   F1. LOAD CHECK AND KPI RECONCILIATION
   Business question: do the loaded tables match the control
   values used in the dashboard?
   Techniques: aggregations, MEDIAN, JOIN (through the view)
   ------------------------------------------------------------ */
SELECT COUNT(*)                                        AS total_transactions,
       COUNT(DISTINCT Transaction_ID)                  AS unique_ids,
       COUNT(DISTINCT Customer_ID)                     AS customers_with_tx,
       (SELECT COUNT(*) FROM customers)                AS total_customers,
       ROUND(SUM(Amount_NGN) / 1e6, 2)                 AS total_value_m,
       ROUND(AVG(Amount_NGN), 0)                       AS avg_value,
       ROUND(MEDIAN(Amount_NGN), 0)                    AS median_value,
       ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT tx_date), 2) AS tx_per_day,
       ROUND(100 * AVG(is_success), 2)                 AS success_rate,
       ROUND(100 * AVG(is_failed), 2)                  AS failure_rate,
       ROUND(100 * AVG(is_flagged), 2)                 AS risk_review_rate,
       SUM(is_intl)                                    AS intl_tx
FROM tx;
/* Business reading: 12,000 transactions, 1,500 customers, all linked.
   These are the control values for every dashboard card. */


/* ------------------------------------------------------------
   F2. SEGMENT PROFILE
   Business question: do the four segments really behave differently?
   Techniques: JOIN, GROUP BY, MEDIAN, subquery for customer counts
   ------------------------------------------------------------ */
SELECT s.Customer_Segment,
       s.customers,
       COUNT(*)                                      AS transactions,
       ROUND(COUNT(*) * 1.0 / s.customers, 2)        AS tx_per_customer,
       ROUND(AVG(t.Amount_NGN), 0)                   AS avg_value,
       ROUND(MEDIAN(t.Amount_NGN), 0)                AS median_value,
       ROUND(100 * AVG(t.is_success), 2)             AS success_rate,
       ROUND(100 * AVG(t.is_flagged), 2)             AS flag_rate
FROM tx t
JOIN (SELECT Customer_Segment, COUNT(*) AS customers
      FROM customers GROUP BY Customer_Segment) s USING (Customer_Segment)
GROUP BY s.Customer_Segment, s.customers
ORDER BY tx_per_customer DESC;
/* Business reading: segments are very close on every measure.
   Premium is not the lowest on the median. Student has the lowest
   success rate (89.30%) but the gap is not significant (p = 0.17). */


/* ------------------------------------------------------------
   F3. CHANNEL RELIABILITY AND WEIGHT OF EACH CHANNEL IN FAILURES
   Business question: where do failures happen, and is a channel
   really worse or just bigger?
   Techniques: GROUP BY, conditional aggregation, window function
   ------------------------------------------------------------ */
SELECT Channel,
       COUNT(*)                                           AS transactions,
       SUM(is_failed)                                     AS failed,
       ROUND(100 * AVG(is_failed), 2)                     AS failure_rate,
       ROUND(100 * (1 - AVG(is_success)), 2)              AS not_successful_rate,
       ROUND(SUM(CASE WHEN is_failed = 1 THEN Amount_NGN END), 0) AS failed_value,
       ROUND(100.0 * SUM(is_failed) / SUM(SUM(is_failed)) OVER (), 1) AS share_of_all_failures,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)             AS share_of_all_transactions
FROM tx
GROUP BY Channel
ORDER BY failed DESC;
/* Business reading: the Mobile App holds 47.0% of failures with 42.5%
   of transactions. It leads in number (296) and in value (13.1M NGN),
   but the gap in rate is not proven across the five channels
   (chi-square p = 0.081). */


/* ------------------------------------------------------------
   F4. RISK REVIEW: INTERNATIONAL STATUS x AMOUNT BAND
   Business question: do international status and high amount
   add up, or does one explain the other?
   Techniques: CTE, CASE, GROUP BY
   ------------------------------------------------------------ */
WITH base AS (
    SELECT amount_band,
           CASE WHEN is_intl = 1 THEN 'International' ELSE 'Domestic' END AS scope,
           is_flagged
    FROM tx
)
SELECT amount_band, scope,
       COUNT(*)                           AS num_tx,
       SUM(is_flagged)                    AS num_flagged,
       ROUND(100.0 * AVG(is_flagged), 2)  AS pct_flagged
FROM base
GROUP BY amount_band, scope
ORDER BY amount_band, scope;
/* Business reading: in every band the international rate is 1.5 to
   2.4 times the domestic rate. The amount effect only appears above
   117,923 NGN. International groups are small (48 to 255 per band),
   so single percentages are imprecise. */


/* ------------------------------------------------------------
   F5. RISK REVIEW BY TRANSACTION TYPE (LIFT VERSUS OVERALL RATE)
   Business question: which transaction types concentrate flags?
   Techniques: GROUP BY, window functions (overall rate), lift
   ------------------------------------------------------------ */
SELECT Transaction_Type,
       COUNT(*)                                        AS num_tx,
       SUM(is_flagged)                                 AS num_flagged,
       ROUND(100.0 * AVG(is_flagged), 2)               AS flag_rate,
       ROUND(AVG(is_flagged) / (SUM(SUM(is_flagged)) OVER () * 1.0 / SUM(COUNT(*)) OVER ()), 2) AS lift_vs_overall,
       ROUND(100.0 * SUM(is_flagged) / SUM(SUM(is_flagged)) OVER (), 1) AS share_of_all_flags
FROM tx
GROUP BY Transaction_Type
ORDER BY flag_rate DESC;
/* Business reading: Transfer and Cash Withdrawal are flagged about
   1.45 and 1.29 times the overall rate, and together hold a bit more
   than half of all flags. */


/* ------------------------------------------------------------
   F6. WEIGHT OF HIGH-VALUE TRANSACTIONS
   Business question: how much of the total value comes from the
   few very large transactions?
   Techniques: CTE, CASE, aggregation with window total
   ------------------------------------------------------------ */
WITH grp AS (
    SELECT CASE WHEN Amount_NGN > 117922.86 THEN 'High value (> 117,923)'
                ELSE 'Other' END AS grp,
           Amount_NGN
    FROM tx
)
SELECT grp,
       COUNT(*)                                             AS num_tx,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS pct_of_count,
       ROUND(SUM(Amount_NGN) / 1e6, 1)                      AS value_m,
       ROUND(100.0 * SUM(Amount_NGN) / SUM(SUM(Amount_NGN)) OVER (), 1) AS pct_of_value
FROM grp
GROUP BY grp
ORDER BY num_tx;
/* Business reading: 12.3% of transactions carry 62.5% of the value.
   The average (46,706) is 4.5 times the median (10,306). */


/* ------------------------------------------------------------
   F7. CUSTOMER VALUE CONCENTRATION
   Business question: is value concentrated in a small group of customers?
   Techniques: CTE, NTILE, cumulative window function
   ------------------------------------------------------------ */
WITH customer_value AS (
    SELECT Customer_ID, SUM(Amount_NGN) AS value
    FROM tx GROUP BY Customer_ID
),
ranked AS (
    SELECT *, NTILE(10) OVER (ORDER BY value DESC) AS decile,
           SUM(value) OVER () AS grand_total
    FROM customer_value
)
SELECT decile,
       COUNT(*)                                                    AS num_customers,
       ROUND(100.0 * SUM(value) / MAX(grand_total), 2)             AS pct_of_value,
       ROUND(100.0 * SUM(SUM(value)) OVER (ORDER BY decile) / MAX(grand_total), 2) AS cumulative_pct
FROM ranked
GROUP BY decile
ORDER BY decile;
/* Business reading: top 20% of customers hold 43.57% of value, top 30%
   hold 57.81%. Concentrated, but far from an 80/20 pattern. */


/* ------------------------------------------------------------
   F8. PREFERRED CHANNEL VERSUS ACTUAL CHANNEL (ROW PERCENTAGES)
   Business question: do customers use the channel they declare?
   Techniques: JOIN, GROUP BY, window function for row percentages
   ------------------------------------------------------------ */
SELECT Preferred_Channel, Channel AS actual_channel,
       COUNT(*) AS num_tx,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY Preferred_Channel), 2) AS pct_of_row
FROM tx
GROUP BY Preferred_Channel, Channel
ORDER BY Preferred_Channel, num_tx DESC;
/* Business reading: whatever channel a customer declares, about 42%
   of their transactions are on the Mobile App (42.5% for everyone).
   The declared preference does not describe actual behaviour.
   This is the same table as the "Preferred versus actual channel
   (% of each row)" visual of the Customers page. */


/* ------------------------------------------------------------
   F9. ACCOUNT STATUS VERSUS REAL ACTIVITY
   Business question: are Dormant accounts really inactive?
   Techniques: CTE, JOIN, CASE, conditional aggregation
   ------------------------------------------------------------ */
WITH last_tx AS (
    SELECT Customer_ID, MAX(Transaction_DateTime) AS last_tx, COUNT(*) AS n_tx
    FROM tx GROUP BY Customer_ID
)
SELECT c.Account_Status,
       COUNT(*)                                             AS customers,
       ROUND(AVG(l.n_tx), 2)                                AS tx_per_customer,
       SUM(CASE WHEN l.last_tx >= TIMESTAMP '2026-03-02' THEN 1 ELSE 0 END) AS active_last_30_days,
       ROUND(100.0 * AVG(CASE WHEN l.last_tx >= TIMESTAMP '2026-03-02' THEN 1 ELSE 0 END), 1) AS pct_active_last_30_days
FROM customers c
JOIN last_tx l USING (Customer_ID)
GROUP BY c.Account_Status
ORDER BY customers DESC;
/* Business reading: 98 of 107 Dormant customers transacted in the last
   30 days of the data. The Dormant label does not measure inactivity. */


/* ------------------------------------------------------------
   F10. DAILY ACTIVITY WITH 7-DAY MOVING AVERAGE
   Business question: is there a real trend, or only calendar effects?
   Techniques: CTE, window function with a frame
   ------------------------------------------------------------ */
WITH daily AS (
    SELECT tx_date, COUNT(*) AS n_tx, SUM(Amount_NGN) AS value
    FROM tx GROUP BY tx_date
)
SELECT tx_date, n_tx,
       ROUND(AVG(n_tx) OVER (ORDER BY tx_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS moving_avg_7d,
       ROUND(value / 1e6, 2) AS value_m
FROM daily
ORDER BY tx_date
LIMIT 10;
/* Business reading: 133 or 134 transactions every day. February only
   looks lower because it has 28 days. The pattern is unusually regular
   (synthetic data), so no growth or peak-hour conclusion is possible. */
