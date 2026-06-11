-- =============================================================================
-- Retail Sales Data Analysis
-- Project: Sales Data Analysis and Reporting for a Retail Chain
-- Tool   : MySQL (alternatives for PostgreSQL / SQLite noted inline)
-- =============================================================================


-- =============================================================================
-- PHASE 1: DATABASE SETUP
-- =============================================================================

-- 1. Create & select database
CREATE DATABASE IF NOT EXISTS retail_sales;
USE retail_sales;

-- 2. Transactions table
--    customer_id is alphanumeric (e.g. 'CS5295'), so VARCHAR is required.
--    tran_amount stored as DECIMAL for financial precision.
CREATE TABLE IF NOT EXISTS transactions (
    customer_id  VARCHAR(50)    NOT NULL,
    trans_date   DATE           NOT NULL,
    tran_amount  DECIMAL(10,2)  NOT NULL
);

-- 3. Customer response table
CREATE TABLE IF NOT EXISTS customer_response (
    customer_id  VARCHAR(50)  NOT NULL PRIMARY KEY,
    response     TINYINT      NOT NULL  -- 0 = no response, 1 = responded
);

-- ── CSV Import ────────────────────────────────────────────────────────────────
-- MySQL:
-- LOAD DATA INFILE '/path/to/Retail_Data_Transactions.csv'
-- INTO TABLE transactions
-- FIELDS TERMINATED BY ','
-- OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 LINES
-- (customer_id, @trans_date_raw, tran_amount)
-- SET trans_date = STR_TO_DATE(@trans_date_raw, '%d-%b-%y');
--
-- LOAD DATA INFILE '/path/to/Retail_Data_Response.csv'
-- INTO TABLE customer_response
-- FIELDS TERMINATED BY ','
-- OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 LINES;
--
-- PostgreSQL:
-- COPY transactions(customer_id, trans_date, tran_amount)
--   FROM '/path/to/Retail_Data_Transactions.csv' DELIMITER ',' CSV HEADER;
-- COPY customer_response(customer_id, response)
--   FROM '/path/to/Retail_Data_Response.csv' DELIMITER ',' CSV HEADER;
--
-- SQLite:
-- .mode csv
-- .import Retail_Data_Transactions.csv transactions
-- .import Retail_Data_Response.csv customer_response


-- =============================================================================
-- PHASE 2: DATA CLEANING
-- =============================================================================

-- 4. Check for missing values
SELECT 'transactions' AS tbl,
       SUM(customer_id  IS NULL) AS null_customer_id,
       SUM(trans_date   IS NULL) AS null_trans_date,
       SUM(tran_amount  IS NULL) AS null_tran_amount
FROM transactions
UNION ALL
SELECT 'customer_response',
       SUM(customer_id IS NULL),
       SUM(response    IS NULL),
       0
FROM customer_response;

-- 5. Check for duplicate transaction rows
SELECT customer_id, trans_date, tran_amount, COUNT(*) AS occurrences
FROM transactions
GROUP BY customer_id, trans_date, tran_amount
HAVING COUNT(*) > 1;

-- 6. Remove duplicates (MySQL — recreate deduped version)
--    Creates a clean copy; swap table names when ready.
CREATE TABLE transactions_clean AS
SELECT DISTINCT customer_id, trans_date, tran_amount
FROM transactions;

-- 7. Outlier check — transaction amounts outside [mean ± 3·stddev]
SELECT *
FROM transactions
WHERE tran_amount > (SELECT AVG(tran_amount) + 3 * STD(tran_amount) FROM transactions)
   OR tran_amount < (SELECT AVG(tran_amount) - 3 * STD(tran_amount) FROM transactions);
-- Expected result: 0 rows (distribution is bounded between $10 and $105)

-- 8. Verify date range
SELECT MIN(trans_date) AS earliest_txn,
       MAX(trans_date) AS latest_txn
FROM transactions;


-- =============================================================================
-- PHASE 3: DATA ANALYSIS
-- =============================================================================

-- ── Core Metrics ──────────────────────────────────────────────────────────────

-- 9. Total revenue
SELECT SUM(tran_amount) AS total_revenue
FROM transactions;
-- Result: $8,122,062

-- 10. Average transaction amount
SELECT ROUND(AVG(tran_amount), 2) AS avg_transaction_amount
FROM transactions;
-- Result: $65.00

-- 11. Total unique customers (in transaction data)
SELECT COUNT(DISTINCT customer_id) AS total_customers
FROM transactions;

-- 12. Campaign response rate
SELECT
    SUM(response)                              AS responded,
    COUNT(*)                                   AS total_customers,
    ROUND(SUM(response) / COUNT(*) * 100, 2)  AS response_rate_pct
FROM customer_response;
-- Result: 9.4% (647 of 6,884 customers responded)


-- ── Revenue Analysis ──────────────────────────────────────────────────────────

-- 13. Revenue by year
SELECT
    YEAR(trans_date)          AS revenue_year,
    SUM(tran_amount)          AS total_revenue,
    COUNT(*)                  AS transaction_count,
    ROUND(AVG(tran_amount),2) AS avg_transaction
FROM transactions
GROUP BY YEAR(trans_date)
ORDER BY revenue_year;
-- PostgreSQL: EXTRACT(YEAR FROM trans_date)
-- SQLite    : strftime('%Y', trans_date)

-- 14. Revenue by month (seasonal pattern — aggregated across all years)
SELECT
    MONTH(trans_date)         AS month_num,
    MONTHNAME(trans_date)     AS month_name,
    SUM(tran_amount)          AS total_revenue,
    ROUND(AVG(tran_amount),2) AS avg_transaction
FROM transactions
GROUP BY MONTH(trans_date), MONTHNAME(trans_date)
ORDER BY total_revenue DESC;
-- Top 3: August ($726,775) · October ($725,010) · January ($724,089)

-- 15. Revenue by quarter
SELECT
    YEAR(trans_date)   AS yr,
    QUARTER(trans_date) AS qtr,
    SUM(tran_amount)   AS total_revenue
FROM transactions
GROUP BY YEAR(trans_date), QUARTER(trans_date)
ORDER BY yr, qtr;


-- ── Customer Analysis ─────────────────────────────────────────────────────────

-- 16. Top 10 customers by total spend
SELECT
    customer_id,
    SUM(tran_amount)  AS total_spend,
    COUNT(*)          AS order_count,
    ROUND(AVG(tran_amount),2) AS avg_order_value
FROM transactions
GROUP BY customer_id
ORDER BY total_spend DESC
LIMIT 10;

-- 17. Top 10 customers by order frequency
SELECT
    customer_id,
    COUNT(*) AS order_count,
    SUM(tran_amount) AS total_spend
FROM transactions
GROUP BY customer_id
ORDER BY order_count DESC
LIMIT 10;

-- 18. Customer lifetime value distribution (spend buckets)
SELECT
    CASE
        WHEN total_spend >= 2000 THEN 'High   (≥ $2,000)'
        WHEN total_spend >= 1000 THEN 'Medium ($1,000–$1,999)'
        ELSE                          'Low    (< $1,000)'
    END                    AS spend_tier,
    COUNT(*)               AS customer_count,
    ROUND(AVG(total_spend),2) AS avg_spend
FROM (
    SELECT customer_id, SUM(tran_amount) AS total_spend
    FROM transactions
    GROUP BY customer_id
) clt
GROUP BY spend_tier
ORDER BY avg_spend DESC;


-- ── RFM Analysis (SQL version) ────────────────────────────────────────────────

-- 19. Build RFM base table
--     Recency  = days since last purchase (relative to max date in dataset)
--     Frequency = number of transactions
--     Monetary  = total spend
SELECT
    t.customer_id,
    DATEDIFF(
        (SELECT MAX(trans_date) FROM transactions),
        MAX(t.trans_date)
    )                        AS recency_days,
    COUNT(*)                 AS frequency,
    SUM(t.tran_amount)       AS monetary,
    cr.response
FROM transactions t
LEFT JOIN customer_response cr USING (customer_id)
GROUP BY t.customer_id, cr.response
ORDER BY monetary DESC;

-- 20. High-value customers who also responded to the campaign
SELECT
    t.customer_id,
    SUM(t.tran_amount)  AS total_spend,
    COUNT(*)            AS order_count,
    cr.response
FROM transactions t
INNER JOIN customer_response cr USING (customer_id)
WHERE cr.response = 1
GROUP BY t.customer_id, cr.response
ORDER BY total_spend DESC
LIMIT 20;


-- ── Time Series ───────────────────────────────────────────────────────────────

-- 21. Month-over-month revenue (year × month)
SELECT
    YEAR(trans_date)                                     AS yr,
    MONTH(trans_date)                                    AS mo,
    SUM(tran_amount)                                     AS monthly_revenue,
    SUM(SUM(tran_amount)) OVER (
        PARTITION BY YEAR(trans_date)
        ORDER BY MONTH(trans_date)
    )                                                    AS ytd_revenue
FROM transactions
GROUP BY YEAR(trans_date), MONTH(trans_date)
ORDER BY yr, mo;
-- Note: window functions require MySQL 8.0+ / PostgreSQL / SQLite 3.25+

-- 22. Running total revenue over time
SELECT
    trans_date,
    SUM(tran_amount)                                              AS daily_revenue,
    SUM(SUM(tran_amount)) OVER (ORDER BY trans_date)              AS cumulative_revenue
FROM transactions
GROUP BY trans_date
ORDER BY trans_date;
