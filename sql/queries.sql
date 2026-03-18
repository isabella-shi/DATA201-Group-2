USE FinancialTransactions;

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

-- Top 10 users ranked by their total debt relative to their yearly income.
SELECT id, gender, yearly_income, total_debt,(total_debt / yearly_income) AS debt_to_income_ratio
FROM Users
WHERE yearly_income > 0
ORDER BY debt_to_income_ratio DESC
LIMIT 10;

-- Average credit limit by card brand.
SELECT card_brand, COUNT(*) AS total_cards, AVG(credit_limit) AS avg_limit
FROM Cards
GROUP BY card_brand;

-- Detect potential fraud through geographical anomalies.
WITH UserAvgSpending AS (
    SELECT c.client_id, AVG(t.amount) * 5 AS threshold
    FROM Transactions t
    JOIN Cards c ON c.id = t.card_id
    GROUP BY c.client_id
)
SELECT t.id AS trans_id, c.client_id, t.amount, t.date, z.city, z.state
FROM Transactions t
JOIN Cards c ON c.id = t.card_id
JOIN ZipCodes z ON t.zip = z.zip
JOIN UserAvgSpending uas ON c.client_id = uas.client_id
WHERE t.amount > uas.threshold
ORDER BY t.amount DESC
LIMIT 500;


--Basic - Top 10 zipcode with the highest total Transaction amount in CA sorted from largest to smallest
CREATE TABLE Transactions_Sample AS
SELECT * FROM Transactions
LIMIT 100000;

SELECT z.merchant_city, z.zip, CONCAT('$', FORMAT(SUM(t.amount), 2)) as `Total Amount`
FROM ZipCodes z
LEFT JOIN Transactions_Sample t
ON t.zip = z.zip
WHERE z.merchant_state  = "CA"
GROUP BY z.merchant_state, z.merchant_city, z.zip
ORDER BY SUM(t.amount) DESC
LIMIT 10;

--Basic 2 - Show Average transaction and Total transaction amount by age bracket in CA
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

--Advanced - Flag cards with high # of transactions (outliers) within a short time window (1 week)
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

-- Average transaction amount by card brand 
SELECT
    c.card_brand,
    COUNT(t.id) AS total_transactions,
    ROUND(AVG(t.amount), 2) AS avg_transaction_amount
FROM Transactions t
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
JOIN Transactions t
    ON c.id = t.card_id
GROUP BY u.gender
ORDER BY total_spending DESC;

-- Users whose spending is unusually high compared to their own average
WITH UserAvgSpend AS (
    SELECT
        c.client_id,
        AVG(t.amount) AS avg_user_amount
    FROM Transactions t
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
FROM Transactions t
JOIN Cards c
    ON t.card_id = c.id
JOIN UserAvgSpend ua
    ON c.client_id = ua.client_id
JOIN Users u
    ON c.client_id = u.id
WHERE t.amount > ua.avg_user_amount * 2
GROUP BY c.client_id, u.gender, ua.avg_user_amount
ORDER BY unusually_high_transactions DESC, avg_high_transaction DESC
LIMIT 10;
