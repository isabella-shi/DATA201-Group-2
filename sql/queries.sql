USE FinancialTransactions;

CREATE USER IF NOT EXISTS 'flaskuser'@'localhost'
  IDENTIFIED WITH caching_sha2_password BY 'flaskpass123!';

GRANT ALL PRIVILEGES ON FinancialTransactions.* TO 'flaskuser'@'localhost';

FLUSH PRIVILEGES;

-- Creating a sample of 100,000 rows from Transactions
CREATE TABLE Transactions_Sample AS
SELECT * FROM Transactions
WHERE (id % 133) = 0
LIMIT 100000;

-- =====================
-- Isabella's Queries
-- =====================

-- Average credit score by age group
SELECT
	CASE
		WHEN current_age BETWEEN 18 AND 25 THEN '18-25'
        WHEN current_age BETWEEN 26 AND 39 THEN '26-39'
        WHEN current_age BETWEEN 40 AND 59 THEN '40-59'
        ELSE '60+'
	END AS age_group, ROUND(AVG(credit_score)) AS avg_credit_score, COUNT(*) AS num_users
FROM Users
GROUP BY age_group
ORDER BY MIN(age_group);

-- Average income and debt by gender
SELECT gender, ROUND(AVG(yearly_income),2) AS avg_income, ROUND(AVG(total_debt),2) AS avg_debt
FROM Users
GROUP BY gender;

-- Average debt for users above and below average credit score
SELECT 'Above average credit score' AS credit_score_group, ROUND(AVG(total_debt),2) AS avg_debt, ROUND(AVG(credit_score)) AS avg_credit_score
FROM Users
WHERE credit_score > (
	SELECT AVG(credit_score)
    FROM Users
)
UNION
SELECT 'Below average credit score' AS credit_score_group, ROUND(AVG(total_debt),2) AS avg_debt, ROUND(AVG(credit_score)) AS avg_credit_score
FROM Users
WHERE credit_score < (
	SELECT AVG(credit_score)
    FROM Users
);

-- Rank users by total spending within each age group
SELECT u.id,
	CASE
		WHEN u.current_age BETWEEN 18 AND 25 THEN '18-25'
		WHEN u.current_age BETWEEN 26 AND 39 THEN '26-39'
		WHEN u.current_age BETWEEN 40 AND 59 THEN '40-59'
		ELSE '60+'
	END AS age_group,
	ROUND(SUM(t.amount), 2) AS total_spending,
    RANK() OVER (
		PARTITION BY
			CASE
				WHEN u.current_age BETWEEN 18 AND 25 THEN '18-25'
				WHEN u.current_age BETWEEN 26 AND 39 THEN '26-39'
				WHEN u.current_age BETWEEN 40 AND 59 THEN '40-59'
				ELSE '60+'
			END
		ORDER BY SUM(t.amount) DESC
	) AS spending_rank
FROM Users u
JOIN Cards c ON u.id = c.client_id
JOIN Transactions_Sample t ON c.id = t.card_id
GROUP BY u.id, u.current_age
ORDER BY age_group, spending_rank;

-- User spending summary view & three follow up queries using the view
CREATE VIEW UserSpendingSummary AS
SELECT u.id, u.gender, u.current_age, u.credit_score, COUNT(t.id) AS total_transactions, ROUND(SUM(t.amount), 2) AS total_spent
FROM Users u
JOIN Cards c ON u.id = c.client_id
JOIN Transactions_Sample t ON c.id = t.card_id
GROUP BY u.id, u.gender, u.current_age, u.credit_score;

-- Top 10 highest spenders overall
SELECT *
FROM UserSpendingSummary
ORDER BY total_spent DESC
LIMIT 10;

-- Top 10 users with high spending & good credit
SELECT *
FROM UserSpendingSummary
WHERE total_spent > (
	SELECT AVG(total_spent)
    FROM UserSpendingSummary
) AND credit_score >= 750
ORDER BY total_spent DESC
LIMIT 10;

-- Top 10 high-frequency, low-spend users
SELECT *, ROUND(total_spent / total_transactions, 2) AS avg_per_transaction
FROM UserSpendingSummary
WHERE total_transactions > (
    SELECT AVG(total_transactions)
    FROM UserSpendingSummary
)
AND total_spent < (
    SELECT AVG(total_spent)
    FROM UserSpendingSummary
)
ORDER BY total_transactions DESC
LIMIT 10;

-- Users with risky financial profile: high debt and low credit score
WITH AvgMetrics AS (
	SELECT AVG(total_debt) AS avg_debt, AVG(credit_score) AS avg_score
    FROM Users
)
SELECT u.id, u.total_debt, u.credit_score, u.yearly_income
FROM Users u, AvgMetrics a
WHERE u.total_debt > a.avg_debt AND u.credit_score < a.avg_score
ORDER BY u.total_debt DESC;

-- Index on date in Transactions to speed up time-based queries
CREATE INDEX idx_transaction_date ON Transactions(date);

EXPLAIN ANALYZE SELECT id, amount, date
FROM Transactions
WHERE date BETWEEN '2018-07-12 00:00:00' AND '2018-07-12 23:59:59'
ORDER BY date;


-- =====================
-- Rene's Queries
-- =====================

-- Top 10 users ranked by their total debt relative to their yearly income.
SELECT id, gender, yearly_income, total_debt,(total_debt / yearly_income) AS debt_to_income_ratio
FROM Users
WHERE yearly_income > 0
ORDER BY debt_to_income_ratio DESC
LIMIT 10;

-- Card Brand Market Share
SELECT card_brand, COUNT(*) AS total_cards
FROM Cards
GROUP BY card_brand;

-- Find high income with low debt users
WITH AvgStats AS (
    SELECT AVG(yearly_income) AS avg_income, 
           AVG(total_debt) AS avg_debt
    FROM Users
)
SELECT u.id, u.yearly_income, u.total_debt, u.credit_score
FROM Users u, AvgStats a
WHERE u.yearly_income > a.avg_income 
  AND u.total_debt < a.avg_debt
ORDER BY u.yearly_income DESC;

-- Detect potential fraud through geographical anomalies.
WITH UserAvgSpending AS (
    SELECT c.client_id, AVG(t.amount) * 5 AS threshold
    FROM Transactions_Sample t
    JOIN Cards c ON c.id = t.card_id
    GROUP BY c.client_id
)
SELECT t.id AS trans_id, c.client_id, t.amount, t.date, z.city, z.state
FROM Transactions_Sample t
JOIN Cards c ON c.id = t.card_id
JOIN ZipCodes z ON t.zip = z.zip
JOIN UserAvgSpending uas ON c.client_id = uas.client_id
WHERE t.amount > uas.threshold
ORDER BY t.amount DESC
LIMIT 50;

-- Identify transactions occurring within 60 minutes for potential fraud detection.
CREATE OR REPLACE VIEW Rapid_Transaction_Alerts AS
WITH TransactionIntervals AS (
    SELECT 
        card_id, 
        date AS current_trans_time,
        LAG(date) OVER (PARTITION BY card_id ORDER BY date) AS prev_trans_time
    FROM Transactions_Sample
)
SELECT *
FROM TransactionIntervals
WHERE TIMESTAMPDIFF(MINUTE, prev_trans_time, current_trans_time) < 60;
SELECT *
FROM Rapid_Transaction_Alerts;

-- Explain analyze before index
EXPLAIN ANALYZE
SELECT *
FROM Rapid_Transaction_Alerts;

-- Explain analyze after index
CREATE INDEX idx_card_date ON Transactions_Sample(card_id, date);

EXPLAIN ANALYZE
SELECT *
FROM Rapid_Transaction_Alerts;

-- Correlating card holdings and credit scores to identify high-risk users.
SELECT 
    CASE 
        WHEN card_count = 1 THEN 'Low Holdings'
        WHEN card_count BETWEEN 2 AND 4 THEN 'Medium Holdings'
        ELSE 'High Holdings'
    END AS holding_tier,
    CASE 
        WHEN credit_score >= 750 THEN 'Excellent'
        WHEN credit_score >= 650 THEN 'Good'
        ELSE 'Fair/Poor'
    END AS credit_tier,
    COUNT(*) AS customer_count,
    AVG(total_debt) AS avg_debt_level
FROM (
    SELECT u.id, u.credit_score, u.total_debt, COUNT(c.client_id) AS card_count
    FROM Users u
    LEFT JOIN Cards c ON u.id = c.client_id
    GROUP BY u.id
) AS UserStats
GROUP BY holding_tier, credit_tier
ORDER BY field(holding_tier, 'High Holdings', 'Medium Holdings', 'Low Holdings'), 
         field(credit_tier, 'Excellent', 'Good', 'Fair/Poor');
         
-- Identify the top 10 highest-spending customers within each gender and age segment to find valuable users.
      WITH UserSpending AS (
    SELECT 
        u.id AS user_id,
        u.gender,
        CASE 
            WHEN u.current_age BETWEEN 18 AND 29 THEN '18-29'
            WHEN u.current_age BETWEEN 30 AND 49 THEN '30-49'
            ELSE '50+'
        END AS age_group,
        SUM(t.amount) AS total_spent
    FROM Users u
    JOIN Cards c ON u.id = c.client_id
    JOIN Transactions_Sample t ON c.id = t.card_id
    GROUP BY u.id, u.gender, age_group
),
RankedUsers AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY gender, age_group 
            ORDER BY total_spent DESC
        ) AS spending_rank
    FROM UserSpending
)
SELECT *
FROM RankedUsers
WHERE spending_rank <= 10
ORDER BY gender, age_group, spending_rank;   


-- =====================
-- Jessica's Queries
-- =====================

-- Basic - Top 10 zipcode with the highest total Transaction amount in CA sorted from largest to smallest
SELECT z.merchant_city, z.zip, CONCAT('$', FORMAT(SUM(t.amount), 2)) as `Total Amount`
FROM ZipCodes z
LEFT JOIN Transactions_Sample t
ON t.zip = z.zip
WHERE z.merchant_state  = "CA"
GROUP BY z.merchant_state, z.merchant_city, z.zip
ORDER BY SUM(t.amount) DESC
LIMIT 10;

-- Basic 2 - Show Average transaction and Total transaction amount by age bracket in CA
SELECT 
    CASE 
        WHEN u.current_age BETWEEN 18 AND 24 THEN '18–24'
        WHEN u.current_age BETWEEN 25 AND 34 THEN '25–34'
        WHEN u.current_age BETWEEN 35 AND 44 THEN '35–44'
        WHEN u.current_age BETWEEN 45 AND 54 THEN '45–54'
        WHEN u.current_age BETWEEN 55 AND 64 THEN '55–64'
        ELSE '65+'
    END AS `Age Bracket`,
    CONCAT('$', FORMAT(SUM(amount), 2))  AS `Total Transaction Amount`,
    CONCAT('$', FORMAT(AVG(amount), 2)) AS `Average Transaction Amount`
FROM Users u
INNER JOIN Transactions_Sample t ON u.id = t.client_id
INNER JOIN (
    SELECT zip FROM ZipCodes WHERE merchant_state = 'CA'
) z ON z.zip = t.zip #filter first for faster performance
GROUP BY `Age Bracket`
ORDER BY `Age Bracket`;

-- Advanced - Flag cards with high # of transactions (outliers) within a short time window (1 week)
WITH weekly_counts AS (
    -- get transaction count per customer per week
    SELECT 
        t.client_id,
        DATE_FORMAT(DATE_SUB(t.date, INTERVAL WEEKDAY(t.date) DAY), '%Y-%m-%d') AS week_start,
        COUNT(t.id) AS weekly_transactions
    FROM Transactions_Sample t
    GROUP BY t.client_id, week_start
),
stats AS (
    -- outlier calculation
    SELECT 
        AVG(weekly_transactions) AS mean,
        STD(weekly_transactions) AS std_dev
    FROM weekly_counts
)
-- flag customers who exceed 2.5 standard deviations
SELECT 
    wc.client_id AS `Customer id`,
    wc.week_start,
    wc.weekly_transactions AS `Total Transactions`,
    ROUND(s.mean, 2) AS `Mean`,
    ROUND(s.std_dev, 2) AS `Standard Deviation`,
    ROUND(s.mean, 2) + (2.5 * ROUND(s.std_dev, 2)) as `Outlier`
FROM weekly_counts wc
CROSS JOIN stats s
WHERE wc.weekly_transactions > s.mean + (2.5 * s.std_dev)
ORDER BY wc.week_start DESC, wc.weekly_transactions DESC; 

--Customer Spending Summary
DELIMETER //
CREATE PROCEDURE GetCustomerSpendingSummary
	@ClientId INT,
	@StartDate DATE,
	@EndDate DATE
AS
BEGIN
	SELECT 
		COUNT(*) AS TotalTransaction,
		SUM(amount) AS TotalSpending,
		AVG(amount) AS AvgTransactionAmount,
		MAX(mcc) WITHIN GROUP (ORDER BY COUNT(*) DESC) AS TopMCC
	FROM Transactions
	WHERE client_id = @ClientId
		AND date BETWEEN @StartDate AND @EndDate;
END//
DELIMETER;

-- Customer Lifetime Spending Value
CREATE PROCEDURE GetCustomerLTV
    @ClientId INT
AS
BEGIN
    SELECT
        SUM(amount) AS TotalSpend,
        SUM(amount) / COUNT(DISTINCT FORMAT(date, 'yyyy-MM')) AS AvgMonthlySpend
    FROM transactions
    WHERE client_id = @ClientId;
END;

--Target Customer of > $1k spending View
CREATE VIEW vw_customer_spend AS
SELECT
    client_id,
    COUNT(*) AS total_transactions,
    SUM(amount) AS total_spend,
    AVG(amount) AS avg_transaction
FROM transactions
GROUP BY client_id;

SELECT *
FROM vw_customer_spend
WHERE total_spend > 1000
ORDER BY total_spend DESC;


-- =====================
-- Rachel's Queries
-- =====================

-- Average transaction amount by card brand 
SELECT 
    c.card_brand,
    COUNT(t.id) AS total_transactions,
    ROUND(AVG(t.amount), 2) AS avg_transaction_amount 
FROM Transactions_Sample t
JOIN Cards c
    ON t.card_id = c.id
GROUP BY c.card_brand
ORDER BY avg_transaction_amount DESC;

-- Total spending and transaction count by gender 
SELECT
    u.gender,
    COUNT(t.id) AS total_transactions,
    ROUND(SUM(t.amount), 2) AS total_spending,
    ROUND(AVG(t.amount), 2) AS avg_transaction_amount
FROM Users u
JOIN Cards c
    ON u.id = c.client_id
JOIN Transactions_Sample t
    ON c.id = t.card_id
GROUP BY u.gender
ORDER BY total_spending DESC;

# Advanced Queries 
-- Users whose spending is unusually high compared to their own average
WITH UserAvgSpend AS (
    SELECT
        c.client_id,
        AVG(t.amount) AS avg_user_amount
    FROM Transactions_Sample t
    JOIN Cards c
        ON t.card_id = c.id
    GROUP BY c.client_id
)
SELECT
    c.client_id,
    u.gender,
    COUNT(t.id) AS unusually_high_transactions,
    ROUND(AVG(t.amount), 2) AS avg_high_transaction,
    ROUND(ua.avg_user_amount, 2) AS user_normal_avg
FROM Transactions_Sample t
JOIN Cards c
    ON t.card_id = c.id
JOIN UserAvgSpend ua
    ON c.client_id = ua.client_id
JOIN Users u
    ON c.client_id = u.id
WHERE t.amount > ua.avg_user_amount * 2
GROUP BY
    c.client_id,
    u.gender,
    ua.avg_user_amount
ORDER BY
    unusually_high_transactions DESC,
    avg_high_transaction DESC
LIMIT 10;

-- Rank card brands by total spending 
SELECT 
    card_brand,
    total_transactions, 
    total_spending, 
    RANK() OVER (ORDER BY total_spending DESC) AS spending_rank
FROM (
    SELECT 
        c.card_brand, 
        COUNT(t.id) AS total_transactions,
        ROUND(SUM(t.amount), 2) AS total_spending
	FROM Transactions_Sample t 
    JOIN Cards c
        ON t.card_id = c.id
	GROUP BY c.card_brand
) brand_summary
ORDER BY spending_rank; 

-- Transaction size tier by card type 
SELECT 
    c.card_type, 
    CASE 
        WHEN t.amount >= 500 THEN 'High Value' 
        WHEN t.amount >= 100 THEN 'Medium Value' 
        ELSE 'Low Value'
	END AS transaction_tier,
    COUNT(t.id) AS total_transactions,
    ROUND(SUM(t.amount), 2) AS total_spending,
    ROUND(AVG(t.amount), 2) AS avg_transaction_amount
FROM Transactions_Sample t 
JOIN Cards c
    ON t.card_id = c.id
GROUP BY c.card_type, transaction_tier 
ORDER BY c.card_type, total_spending DESC; 

-- Top 3 merchant categories within each card brand 
SELECT
    card_brand,
    merchant_category,
    total_transactions,
    total_spending,
    category_rank
FROM (
    SELECT
        c.card_brand,
        mc.description AS merchant_category,
        COUNT(t.id) AS total_transactions,
        ROUND(SUM(t.amount), 2) AS total_spending,
        ROW_NUMBER() OVER (
            PARTITION BY c.card_brand
            ORDER BY SUM(t.amount) DESC
        ) AS category_rank
    FROM Transactions_Sample t
    JOIN Cards c
        ON t.card_id = c.id
    JOIN MerchantCategories mc
        ON t.mcc = mc.mcc_code
    GROUP BY
        c.card_brand,
        mc.description
) ranked_categories
WHERE category_rank <= 3
ORDER BY
    card_brand,
    category_rank;

-- Spending by card brand for transactions over $100 
SELECT
    c.card_brand,
    COUNT(t.id) AS total_transactions,
    ROUND(SUM(t.amount), 2) AS total_spending,
    ROUND(AVG(t.amount), 2) AS avg_transaction_amount
FROM Transactions_Sample t
JOIN Cards c
    ON t.card_id = c.id
WHERE t.amount >= 100
GROUP BY c.card_brand
ORDER BY total_spending DESC;

-- EXPLAIN before index 
EXPLAIN
SELECT
    c.card_brand,
    COUNT(t.id) AS total_transactions,
    ROUND(SUM(t.amount), 2) AS total_spending,
    ROUND(AVG(t.amount), 2) AS avg_transaction_amount
FROM Transactions_Sample t
JOIN Cards c
    ON t.card_id = c.id
WHERE t.amount >= 100
GROUP BY c.card_brand
ORDER BY total_spending DESC;

-- EXPLAIN ANALYZE before index 
EXPLAIN ANALYZE
SELECT
    c.card_brand,
    COUNT(t.id) AS total_transactions,
    ROUND(SUM(t.amount), 2) AS total_spending,
    ROUND(AVG(t.amount), 2) AS avg_transaction_amount
FROM Transactions_Sample t
JOIN Cards c
    ON t.card_id = c.id
WHERE t.amount >= 100
GROUP BY c.card_brand
ORDER BY total_spending DESC;

CREATE INDEX idx_sample_card_amount
ON Transactions_Sample(card_id, amount);

-- EXPLAIN ANALYZE after index 
EXPLAIN ANALYZE
SELECT
    c.card_brand,
    COUNT(t.id) AS total_transactions,
    ROUND(SUM(t.amount), 2) AS total_spending,
    ROUND(AVG(t.amount), 2) AS avg_transaction_amount
FROM Transactions_Sample t
JOIN Cards c
    ON t.card_id = c.id
WHERE t.amount >= 100
GROUP BY c.card_brand
ORDER BY total_spending DESC;

