/* ============================================================
   FinTrust Digital Bank - Week 2 SQL Business Analysis
   Track: Data Analytics
   Author: Yawa Jacqueline GBEDEVI
   Engine: DuckDB 

   Tables used:
     customer     <- FinTrust_Customer_Data
     transactions <- FinTrust_Transaction_Data (cleaned version:
                      Device_Type and Location missing values
                      replaced with 'Not Provided', see
                      Data Cleaning Log)
   ============================================================ */


--CREATE DATABASE
 CREATE TABLE transactions AS 
SELECT *
	EXCLUDE (Transaction_DateTime),
    strptime(Transaction_DateTime, '%d %m %Y %H:%M') AS Transaction_DateTime
FROM read_csv_auto(
    'C:\Users\Yvette\Downloads\Analyst_Lab_Africa_Internship\Week 2\FinTrust_Transaction_Data.csv',
    delim=';',
    decimal_separator=','
);

CREATE TABLE customers AS 
SELECT * 
FROM read_csv_auto('C:/Users/Yvette/Downloads/Analyst_Lab_Africa_Internship/Week 2/FinTrust_Customer_Data.csv',
delim=';',
decimal_separator=','
);


/* ------------------------------------------------------------
   Q1. CUSTOMER BEHAVIOUR
   Business Question: Which customer segment generates the
   highest average transaction value?
   ------------------------------------------------------------ */
SELECT c.Customer_Segment,
       COUNT(*) AS num_transactions,
       ROUND(AVG(t.Amount_NGN),2) AS avg_amount,
       ROUND(SUM(t.Amount_NGN),2) AS total_amount
FROM transactions t
JOIN customers c ON t.Customer_ID = c.Customer_ID
GROUP BY c.Customer_Segment
ORDER BY avg_amount DESC;

-- Result: SME 49,115.69 | Student 46,953.20 | Everyday 46,325.11 | Premium 45,637.95
-- Business Interpretation: SME accounts carry the highest average transaction value, not Premium as might be expected.
-- Premium customers may transact more frequently but at moderate amounts,while SME (business) accounts process individually larger sums.
-- FinTrust could review whether current Premium products truly match the high-volume needs of this segment.


/* ------------------------------------------------------------
   Q2. TRANSACTION ACTIVITY
   Business Question: How does transaction volume and value
   evolve month over month?
   ------------------------------------------------------------ */
SELECT strftime(Transaction_DateTime, '%Y-%m') AS month,
       COUNT(*) AS num_transactions,
       ROUND(SUM(Amount_NGN),2) AS total_value
FROM transactions
GROUP BY month
ORDER BY month;

-- Result: Jan 4,133 tx / 188.5M NGN | Feb 3,734 tx / 175.8M NGN | Mar 4,133 tx / 196.2M NGN
/* Business Interpretation: Activity is broadly stable across the quarter,
 with a slight dip in February (fewer days in the month)and a rebound in March. 
 No strong growth or decline trend yet,which gives a baseline to monitor in future months.*/


/* ------------------------------------------------------------
   Q3. TRANSACTION VALUE
   Business Question: How does average transaction value differ
   by transaction type?
   ------------------------------------------------------------ */
SELECT Transaction_Type,
       COUNT(*) AS num_transactions,
       ROUND(AVG(Amount_NGN),2) AS avg_amount,
       ROUND(MIN(Amount_NGN),2) AS min_amount,
       ROUND(MAX(Amount_NGN),2) AS max_amount
FROM transactions
GROUP BY Transaction_Type
ORDER BY avg_amount DESC;

-- Result: Deposit 98,633.33 > Transfer 67,037.67 > Cash Withdrawal 47,393.26
--         > Card Purchase 28,309.73 > Bill Payment 19,094.00 > Airtime/Data 8,249.93
/* Business Interpretation: Deposits and transfers concentrate the
highest values, while card purchases and airtime top-ups are
low-value but likely high-frequency. FinTrust manages two very
different usage profiles: large financial operations and everyday
micro-payments.*/


/* ------------------------------------------------------------
   Q4. TRANSACTION TYPE
   Business Question: Which transaction type is used most often?
   ------------------------------------------------------------ */
SELECT Transaction_Type, COUNT(*) AS num_transactions,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM transactions),2) AS pct_of_total
FROM transactions
GROUP BY Transaction_Type
ORDER BY num_transactions DESC;

/*Result: Transfer 29.58% | Card Purchase 25.28% | Bill Payment 12.29%
         | Cash Withdrawal 11.92% | Deposit 11.07% | Airtime/Data 9.88%
 Business Interpretation: Transfers and card purchases together
 make up 55% of all transaction volume. These are the two features
 FinTrust should prioritise for reliability and user experience,
 since they are what customers use the most.*/


/* ------------------------------------------------------------
   Q5. TRANSACTION CHANNEL
   Business Question: Which channel generates the most total
   transaction value?
   ------------------------------------------------------------ */
SELECT Channel, COUNT(*) AS num_transactions, ROUND(SUM(Amount_NGN),2) AS total_value,
       ROUND(AVG(Amount_NGN),2) AS avg_value
FROM transactions
GROUP BY Channel
ORDER BY total_value DESC;

/* Result: Mobile App 240.1M NGN (5,102 tx) far ahead of POS 104.3M,
         Web 89.3M, ATM 83.9M, USSD 42.8M
 Business Interpretation: The mobile app dominates in both volume
 and total value. It is FinTrust's number-one strategic channel:
 investment in reliability, security or new features has the
 greatest impact when prioritised there.*/


/* ------------------------------------------------------------
   Q6. TRANSACTION STATUS
   Business Question: What is the overall transaction success
   rate, and does it vary by channel?
   ------------------------------------------------------------ */
SELECT Transaction_Status, COUNT(*) AS num_transactions,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM transactions),2) AS pct
FROM transactions
GROUP BY Transaction_Status
ORDER BY num_transactions DESC;

-- Result: Successful 90.47% | Failed 5.25% | Reversed 2.72% | Pending 1.57%

SELECT Channel, Transaction_Status, COUNT(*) AS num_transactions
FROM transactions
GROUP BY Channel, Transaction_Status
ORDER BY Channel, Transaction_Status;


SELECT Channel,
       COUNT(*) AS total_transactions,
       SUM(CASE WHEN Transaction_Status = 'Failed' THEN 1 ELSE 0 END) AS failed_transactions,
       ROUND(100.0 * SUM(CASE WHEN Transaction_Status = 'Failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_failed
FROM transactions
GROUP BY Channel
ORDER BY pct_failed DESC;

/* Business Interpretation: The overall success rate (90.5%) is
 solid, but the 5.25% failure rate still represents 630 transactions
 that may have frustrated customers. Although the mobile app is the most widely 
 used channel (Q5), it is also the one with the highest proportion of failed 
 transactions. Since it was identified earlier as the number-one strategic 
 channel, improving its reliability would have the greatest impact on the 
 absolute number of affected customers.*/


/* ------------------------------------------------------------
   Q7. CUSTOMER SEGMENTS
   Business Question: How does digital engagement differ across
   customer segments?
   ------------------------------------------------------------ */
SELECT Customer_Segment, ROUND(AVG(Digital_Engagement_Score),2) AS avg_engagement,
       COUNT(*) AS num_customers
FROM customers
GROUP BY Customer_Segment
ORDER BY avg_engagement DESC;

/* Result: Everyday 68.37 | SME 68.34 | Student 67.91 | Premium 66.71
 Business Interpretation: The gap between segments is small, meaning digital engagement is fairly
 consistent across the whole customer base rather than concentrated
 in one profile. Premium customers actually show the lowest average
 engagement, which is worth investigating if FinTrust assumed
 Premium customers would be the most digitally active.*/


/* ------------------------------------------------------------
   Q8. RISK-REVIEW PATTERNS
   Business Question: What share of transactions are flagged for
   risk review, and what factors are associated with a higher
   flag rate (international transactions, high transaction amount)?
  
   ------------------------------------------------------------ */
SELECT Risk_Review_Flag, COUNT(*) AS num_transactions,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM transactions),2) AS pct
FROM transactions
GROUP BY Risk_Review_Flag;

-- Result: Yes 19.60% | No 80.40%

SELECT International_Transaction, Risk_Review_Flag, COUNT(*) AS num_transactions
FROM transactions
GROUP BY International_Transaction, Risk_Review_Flag;

-- Result: International transactions flagged (177 of 480) of the time
--          vs (2,175 of 11,520) for domestic transactions
--         

SELECT CASE
         WHEN Amount_NGN < 10000 THEN '1. <10k'
         WHEN Amount_NGN < 50000 THEN '2. 10k-50k'
         WHEN Amount_NGN < 117923 THEN '3. 50k-118k'
         ELSE '4. 118k+ (outlier zone)'
       END AS amount_band,
       COUNT(*) AS num_transactions,
       SUM(CASE WHEN Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END) AS flagged,
       ROUND(100.0*SUM(CASE WHEN Risk_Review_Flag = 'Yes' THEN 1 ELSE 0 END)/COUNT(*),2) AS pct_flagged
FROM transactions
GROUP BY amount_band
ORDER BY amount_band;

/* Result: Flag rate rises from ~17-18% in the lower amount bands to 32.23% for transactions above 117,922.86 NGN (the IQR
outlier threshold identified in the Data Quality Report)
 Business Interpretation: Two factors are clearly associated with
 being flagged: whether a transaction is international (nearly
 double the flag rate) and whether the amount is unusually high
 (flag rate almost doubles above the outlier threshold). This shows
 the flagging logic follows a coherent pattern based on these two
 criteria.*/