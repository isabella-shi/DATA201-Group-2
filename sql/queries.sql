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
    SELECT client_id, AVG(amount) * 5 AS threshold
    FROM Transactions
    GROUP BY client_id
)
SELECT t.id AS trans_id, t.client_id, t.amount, t.date, z.city, z.state
FROM Transactions t
INNER JOIN ZipCodes z ON t.zip = z.zip
INNER JOIN UserAvgSpending uas ON t.client_id = uas.client_id
WHERE t.amount > uas.threshold
ORDER BY t.amount DESC 
LIMIT 500;