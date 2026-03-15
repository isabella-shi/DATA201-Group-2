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