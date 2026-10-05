/* ============================================================
   FinTrust Digital Bank - Week 3 Advanced SQL Analysis
   Track: Data Analytics
   Author: Yawa Jacqueline GBEDEVI
   Engine: DuckDB (DBeaver)

   Builds on: Script-week2.sql (8 business questions)
   Purpose: deepen the Week 2 analysis, test its findings and
            close the gaps identified in the Week 3 Part A review.

   Tables:
     customers    <- FinTrust_Customer_Data (1,500 rows)
     transactions <- FinTrust_Transaction_Data, cleaned version
                     (12,000 rows, see Q1 for the load check)

   NOTE: adjust the two file paths below to your own folder.
   Use the CORRECTED CSV (5 stray rows removed from the Clean sheet).
   ============================================================ */


/* ------------------------------------------------------------
   SETUP
   ------------------------------------------------------------ */
CREATE OR REPLACE TABLE transactions AS
SELECT * EXCLUDE (Transaction_DateTime),
       strptime(Transaction_DateTime, '%d %m %Y %H:%M') AS Transaction_DateTime
FROM read_csv_auto('C:/PATH/TO/FinTrust_Transaction_Data_Clean.csv',
                   delim=';', decimal_separator=',');

CREATE OR REPLACE TABLE customers AS
SELECT * FROM read_csv_auto('C:/PATH/TO/FinTrust_Customer_Data.csv',
                            delim=';', decimal_separator=',');

-- Working view: 0/1 indicators make every rate a simple AVG().
-- The Transaction_ID filter is a safety net against empty rows
-- (see Q1). CAST handles Yes/No read either as text or boolean.
CREATE OR REPLACE VIEW tx AS
SELECT *,
       CASE WHEN CAST(International_Transaction AS VARCHAR) IN ('Yes','true') THEN 1 ELSE 0 END AS is_intl,
       CASE WHEN CAST(Risk_Review_Flag AS VARCHAR)          IN ('Yes','true') THEN 1 ELSE 0 END AS is_flagged,
       CASE WHEN Transaction_Status = 'Successful' THEN 1 ELSE 0 END AS is_success,
       CASE WHEN Transaction_Status = 'Failed'     THEN 1 ELSE 0 END AS is_failed,
       CAST(Transaction_DateTime AS DATE) AS tx_date
FROM transactions
WHERE Transaction_ID IS NOT NULL;


/* ------------------------------------------------------------
   Q1. LOAD VALIDATION (test for Week 2 gap #1)
   Business Question: Does the loaded table contain exactly the
   12,000 expected transactions, with no empty or duplicate rows?
   ------------------------------------------------------------ */
SELECT COUNT(*)                       AS total_rows,
       COUNT(Transaction_ID)          AS non_null_ids,
       COUNT(DISTINCT Transaction_ID) AS unique_ids,
       MIN(Transaction_DateTime)      AS first_tx,
       MAX(Transaction_DateTime)      AS last_tx
FROM transactions;

/*Result: 12,000 | 12,000 | 12,000 | 2026-01-01 | 2026-03-31 23:59
 Business Interpretation: the table is complete and clean. The
 original Clean sheet had 12,005 rows (5 stray rows with no ID);
 this check is the re-test after removing them. Expected value
 for the Power BI "Total Transactions" card: 12,000. */


/* ------------------------------------------------------------
   Q2. CUSTOMER BEHAVIOUR: FREQUENCY AND VALUE PER CUSTOMER
   Business Question: Do some segments transact more often, or
   generate more value per customer, than others? (JOIN, GROUP BY)
   Tests the Week 2 Q1 assumption that Premium "may transact
   more frequently".
   ------------------------------------------------------------ */
SELECT c.Customer_Segment,
       COUNT(DISTINCT c.Customer_ID)                                   AS num_customers,
       COUNT(*)                                                        AS num_transactions,
       ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT c.Customer_ID), 2)        AS tx_per_customer,
       ROUND(AVG(t.Amount_NGN), 0)                                     AS avg_amount,
       ROUND(MEDIAN(t.Amount_NGN), 0)                                  AS median_amount,
       ROUND(SUM(t.Amount_NGN) / COUNT(DISTINCT c.Customer_ID), 0)     AS value_per_customer
FROM tx t
JOIN customers c ON t.Customer_ID = c.Customer_ID
GROUP BY c.Customer_Segment
ORDER BY value_per_customer DESC;

/*Result (tx per customer): Student 8.23 | Premium 8.00 | Everyday 7.94 | SME 7.90
        (value per customer, NGN): SME 387,923 | Student 386,604 | Everyday 367,734 | Premium 365,258
 Business Interpretation: Premium customers do NOT transact more
 often than others: frequency is about 8 transactions per customer
 in every segment. The Week 2 assumption is not supported by the
 data and should be removed. Value per customer differs by less
 than 7% between the best and worst segment.*/


/* ------------------------------------------------------------
   Q3. SEGMENT DISTRIBUTION: MEDIANS AND PERCENTILES
   Business Question: Once the skew in transaction amounts is
   taken into account, do segments really differ?
   (aggregate functions, quantiles; re-tests Week 2 Finding 1)
   ------------------------------------------------------------ */
SELECT c.Customer_Segment,
       ROUND(QUANTILE_CONT(t.Amount_NGN, 0.25), 0) AS p25,
       ROUND(QUANTILE_CONT(t.Amount_NGN, 0.50), 0) AS median,
       ROUND(QUANTILE_CONT(t.Amount_NGN, 0.75), 0) AS p75,
       ROUND(QUANTILE_CONT(t.Amount_NGN, 0.90), 0) AS p90,
       ROUND(100.0 * AVG(CASE WHEN t.Amount_NGN > 117922.86 THEN 1 ELSE 0 END), 2) AS pct_high_value
FROM tx t
JOIN customers c ON t.Customer_ID = c.Customer_ID
GROUP BY c.Customer_Segment
ORDER BY median DESC;

/* Result (median, NGN): SME 11,627 | Student 10,531 | Premium 10,219 | Everyday 9,929
        (% above 117,922.86): SME 13.01 | Premium 12.41 | Everyday 12.31 | Student 11.53
 Business Interpretation: on the median, Premium is third, ahead
 of Everyday, so "Premium is the lowest" (Week 2 Finding 1) was an
 effect of the mean being pulled by large amounts. Combined with
 the Python tests (ANOVA p = 0.61, Kruskal-Wallis p = 0.20),
 segments behave similarly. Finding 1 must be revised.*/


/* ------------------------------------------------------------
   Q4. TREND: DAILY ACTIVITY WITH 7-DAY MOVING AVERAGE
   Business Question: Is activity growing, falling or stable
   over the quarter? (CTE + window function)
   ------------------------------------------------------------ */
WITH daily AS (
    SELECT tx_date,
           COUNT(*)        AS num_tx,
           SUM(Amount_NGN) AS daily_value
    FROM tx
    GROUP BY tx_date
)
SELECT tx_date,
       num_tx,
       ROUND(daily_value, 0) AS daily_value,
       ROUND(AVG(num_tx) OVER (ORDER BY tx_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS ma7_tx,
       ROUND(AVG(daily_value) OVER (ORDER BY tx_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0) AS ma7_value
FROM daily
ORDER BY tx_date;

/* Result: 90 days; the 7-day average stays at about 133 transactions per day.
 Business Interpretation: no upward or downward trend. Daily
 volume is almost constant, so a monthly bar chart hides nothing
 and shows nothing. Value per day varies more than volume
 (driven by a few large transactions), which supports tracking
 value with the moving average rather than raw daily bars.*/


/* ------------------------------------------------------------
   Q5. TREND: CALENDAR-ADJUSTED RHYTHM
   Business Question: Is the February "dip" real? Are there busy
   weekdays or peak hours? (normalised by number of days)
   ------------------------------------------------------------ */
-- 5a. Monthly activity per day
SELECT strftime(Transaction_DateTime, '%Y-%m')                                    AS month,
       COUNT(*)                                                                   AS num_tx,
       COUNT(DISTINCT tx_date)                                                    AS num_days,
       ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT tx_date), 1)                         AS tx_per_day,
       ROUND(SUM(Amount_NGN) / COUNT(DISTINCT tx_date), 0)                        AS value_per_day
FROM tx
GROUP BY month
ORDER BY month;

-- Result: Jan 133.3 | Feb 133.4 | Mar 133.3 transactions per day
--         (value per day: 6.08M | 6.28M | 6.33M NGN)

-- 5b. Weekday, normalised by the number of times each weekday occurs
SELECT isodow(Transaction_DateTime)                       AS weekday_no,
       dayname(Transaction_DateTime)                      AS weekday,
       COUNT(*)                                           AS num_tx,
       COUNT(DISTINCT tx_date)                            AS num_days,
       ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT tx_date), 1) AS tx_per_day
FROM tx
GROUP BY 1, 2
ORDER BY 1;

-- Result: Wednesday has 1,602 tx vs about 1,733 for other days, but only
--         because it occurs 12 times in the quarter vs 13. Per day: 133.2 to 133.5 for all.

-- 5c. Hour of day
SELECT hour(Transaction_DateTime) AS hour_of_day,
       COUNT(*)                   AS num_tx,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM tx
GROUP BY hour_of_day
ORDER BY hour_of_day;

/* Result: exactly 500 transactions in each of the 24 hours (4.17%).
 Business Interpretation: the February dip is only a calendar
 effect (28 days), and there is no weekday or hourly peak. Real
 banking activity is never this uniform: this is a limitation of
 the synthetic dataset. It means no capacity-planning or
 peak-hour recommendation can be drawn from this data.*/


/* ------------------------------------------------------------
   Q6. ACCOUNT STATUS: ARE DORMANT AND RESTRICTED ACCOUNTS ACTIVE?
   Business Question: Do Dormant and Restricted customers behave
   differently from Active ones? (JOIN, CASE, aggregates)
   ------------------------------------------------------------ */
SELECT c.Account_Status,
       COUNT(DISTINCT c.Customer_ID)                                AS num_customers,
       COUNT(*)                                                     AS num_tx,
       ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT c.Customer_ID), 2)     AS tx_per_customer,
       ROUND(AVG(t.Amount_NGN), 0)                                  AS avg_amount,
       ROUND(100.0 * AVG(t.is_flagged), 2)                          AS pct_flagged,
       COUNT(DISTINCT CASE WHEN t.Transaction_DateTime >= '2026-03-01'
                           THEN c.Customer_ID END)                  AS customers_active_in_march,
       MAX(t.Transaction_DateTime)                                  AS last_tx
FROM tx t
JOIN customers c ON t.Customer_ID = c.Customer_ID
GROUP BY c.Account_Status
ORDER BY num_customers DESC;

/* Result: Active 1,367 customers, 7.98 tx each, 19.48% flagged
         Dormant 107 customers, 8.09 tx each, 20.44% flagged, 98 active in March
         Restricted 26 customers, 8.62 tx each, 22.32% flagged, 25 active in March
 Business Interpretation: Dormant and Restricted accounts transact
 as much as Active ones, and 98 of 107 Dormant customers made
 transactions in March. In a real bank this would be a data
 consistency alert: the account status does not seem to be
 linked to activity. We treat it as a dataset limitation, and
 the Dormant account rate (107 / 1,500 = 7.1%) should be shown
 with this caveat rather than as a true inactivity KPI.*/


/* ------------------------------------------------------------
   Q7. CHANNEL RELIABILITY: ALL NON-SUCCESSFUL OUTCOMES
   Business Question: Which channels have the most failed,
   reversed or pending transactions, and what value is affected?
   (CASE, aggregates; deepens Week 2 Q6 and Finding 2)
   ------------------------------------------------------------ */
SELECT Channel,
       COUNT(*)                                                                   AS num_tx,
       ROUND(100.0 * AVG(is_success), 2)                                          AS pct_success,
       ROUND(100.0 * AVG(is_failed), 2)                                           AS pct_failed,
       ROUND(100.0 * AVG(CASE WHEN Transaction_Status = 'Reversed' THEN 1 ELSE 0 END), 2) AS pct_reversed,
       ROUND(100.0 * AVG(CASE WHEN Transaction_Status = 'Pending'  THEN 1 ELSE 0 END), 2) AS pct_pending,
       ROUND(100.0 * AVG(1 - is_success), 2)                                      AS pct_not_successful,
       SUM(is_failed)                                                             AS num_failed,
       ROUND(SUM(CASE WHEN is_failed = 1 THEN Amount_NGN ELSE 0 END), 0)          AS value_failed_ngn
FROM tx
GROUP BY Channel
ORDER BY pct_not_successful DESC;

/* Result (% not successful): Mobile App 10.25 | USSD 9.67 | POS 9.15 | Web 9.15 | ATM 8.30
        (failed count): Mobile App 296 | POS 125 | Web 88 | ATM 73 | USSD 48
        (value of failed tx, NGN): Mobile App 13.09M | Web 4.61M | POS 3.92M | ATM 1.73M | USSD 1.48M
 Business Interpretation: the Mobile App has the highest rate, but the
 gaps are small: the global chi-square test across the 5 channels
 gives p = 0.081 for failure rate and p = 0.143 for all
 non-successful outcomes, so the difference is a trend, not a
 proven gap (Week 2 Finding 2 needs to be nuanced). What is
 certain is the absolute impact: the Mobile App accounts for 296
 failed transactions and 13.1M NGN of failed value, nearly 3 times
 more than any other channel, simply because it carries 42.5% of traffic.*/


/* ------------------------------------------------------------
   Q8. RISK REVIEW: INTERNATIONAL x AMOUNT
   Business Question: Do international status and high amount
   add up, or does one of them explain the other?
   (CTE, CASE; extends Week 2 Q8)
   ------------------------------------------------------------ */
WITH banded AS (
    SELECT CASE WHEN Amount_NGN < 10000      THEN '1. <10k'
                WHEN Amount_NGN < 50000      THEN '2. 10k-50k'
                WHEN Amount_NGN <= 117922.86 THEN '3. 50k-118k'
                ELSE                              '4. >118k (outlier zone)'
           END AS amount_band,
           CASE WHEN is_intl = 1 THEN 'International' ELSE 'Domestic' END AS scope,
           is_flagged
    FROM tx
)
SELECT amount_band, scope,
       COUNT(*)                          AS num_tx,
       SUM(is_flagged)                   AS num_flagged,
       ROUND(100.0 * AVG(is_flagged), 2) AS pct_flagged
FROM banded
GROUP BY amount_band, scope
ORDER BY amount_band, scope;

/* Result (% flagged, domestic -> international):
   <10k: 16.92 -> 34.12 | 10k-50k: 16.87 -> 40.65
   50k-118k: 18.23 -> 29.17 | >118k: 31.62 -> 48.15
 Business Interpretation: both factors act independently. In every
 amount band, international transactions are flagged 1.6 to 2.4
 times more often. Amount also matters, but only above the outlier
 threshold (about 17-18% below it, 31.6% above, domestic). The
 highest flag rate (48.15%) is the combination of both. Caution:
 international groups are small (48 to 255 transactions per band),
 so individual percentages are imprecise.*/


/* ------------------------------------------------------------
   Q9. CUSTOMER VALUE CONCENTRATION
   Business Question: How concentrated is transaction value among
   customers? (CTE, NTILE, cumulative window function)
   ------------------------------------------------------------ */
WITH customer_value AS (
    SELECT Customer_ID, SUM(Amount_NGN) AS value
    FROM tx
    GROUP BY Customer_ID
),
ranked AS (
    SELECT *, NTILE(10) OVER (ORDER BY value DESC) AS decile,
           SUM(value) OVER () AS grand_total
    FROM customer_value
)
SELECT decile,
       COUNT(*)                                                   AS num_customers,
       ROUND(SUM(value), 0)                                       AS decile_value,
       ROUND(100.0 * SUM(value) / MAX(grand_total), 2)            AS pct_of_value,
       ROUND(100.0 * SUM(SUM(value)) OVER (ORDER BY decile) / MAX(grand_total), 2) AS cumulative_pct
FROM ranked
GROUP BY decile
ORDER BY decile;

/* Result: top 10% of customers (150) = 25.86% of value; top 30% = 57.81%;
         bottom 50% = 21.19%.
 Business Interpretation: value is concentrated but not extreme
 (a typical Pareto 80/20 would show 80% in the top 20%; here the
 top 20% hold 43.57%). A group of about 450 high-value customers
 deserves a retention and monitoring focus, and could be selected
 by value rather than by the Premium label, which does not separate customers.*/


/* ------------------------------------------------------------
   Q10. TRANSACTION TYPE MIX BY CHANNEL
   Business Question: Does each channel serve a different use?
   (GROUP BY, window function with PARTITION BY)
   ------------------------------------------------------------ */
SELECT Channel, Transaction_Type,
       COUNT(*)                                                           AS num_tx,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY Channel), 1) AS pct_of_channel,
       RANK() OVER (PARTITION BY Channel ORDER BY COUNT(*) DESC)          AS rank_in_channel
FROM tx
GROUP BY Channel, Transaction_Type
ORDER BY Channel, rank_in_channel;

/* Result: Transfer ranks first (28 to 31%) and Card Purchase second
        (23 to 27%) in all 5 channels.
Business Interpretation: channels are not specialised. The same
mix of uses appears everywhere, which confirms Week 2 Finding 3
 (Transfer + Card Purchase = 54.9%) and means that reliability
 work on these two flows benefits every channel.*/


/* ------------------------------------------------------------
   Q11. PREFERRED CHANNEL VERSUS ACTUAL CHANNEL USE
   Business Question: Do customers really use the channel they
   declare as preferred? (CTE, JOIN, comparison with baseline)
   ------------------------------------------------------------ */
WITH usage AS (
    SELECT c.Customer_ID, c.Preferred_Channel,
           COUNT(*)                                                     AS n_tx,
           SUM(CASE WHEN t.Channel = c.Preferred_Channel THEN 1 ELSE 0 END) AS n_on_preferred
    FROM tx t
    JOIN customers c ON t.Customer_ID = c.Customer_ID
    GROUP BY c.Customer_ID, c.Preferred_Channel
),
baseline AS (
    SELECT Channel, 100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS pct_all_tx
    FROM tx
    GROUP BY Channel
)
SELECT u.Preferred_Channel,
       COUNT(*)                                          AS num_customers,
       ROUND(100.0 * SUM(u.n_on_preferred) / SUM(u.n_tx), 1) AS pct_tx_on_preferred_channel,
       ROUND(MAX(b.pct_all_tx), 1)                       AS baseline_pct_all_customers
FROM usage u
JOIN baseline b ON b.Channel = u.Preferred_Channel
GROUP BY u.Preferred_Channel
ORDER BY num_customers DESC;

/* Result: Mobile App 42.5% vs baseline 42.5 | Web 15.9% vs 15.6 | USSD 7.5% vs 7.4
 Business Interpretation: customers who declare a preferred channel
 use it no more than anyone else. The declared preference does not
 predict behaviour. For FinTrust, Preferred_Channel should not be
 used to target channel campaigns, and customers should be profiled
 on observed usage instead. Note also that only 3 of the 5 channels
 (Mobile App, Web, USSD) appear as a preference.*/


/* ------------------------------------------------------------
   Q12. INCOME BAND AND RISK REVIEW
   Business Question: Do income bands differ in amounts or flag
   rates? (JOIN, aggregates)
   ------------------------------------------------------------ */
SELECT c.Monthly_Income_Band,
       COUNT(*)                          AS num_tx,
       ROUND(AVG(t.Amount_NGN), 0)       AS avg_amount,
       ROUND(MEDIAN(t.Amount_NGN), 0)    AS median_amount,
       ROUND(100.0 * AVG(t.is_flagged), 2) AS pct_flagged
FROM tx t
JOIN customers c ON t.Customer_ID = c.Customer_ID
GROUP BY c.Monthly_Income_Band
ORDER BY pct_flagged DESC;

/* Result (% flagged): 250k-499k 20.20 | 100k-249k 20.14 | Below 100k 19.26
                     | 1m+ 18.98 | 500k-999k 18.45
 Business Interpretation: flag rates are close to the global
 19.6% in every band, and "Below 100k" customers have the highest
 average amount (49,478 NGN) while "1m+" has the lowest (43,695).
 Income band does not explain transaction size or risk review in
 this dataset: another sign that the synthetic variables are
 largely independent of each other.*/