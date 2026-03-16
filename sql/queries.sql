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