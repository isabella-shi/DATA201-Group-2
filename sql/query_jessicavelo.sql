/*CREATE TABLE Transactions_Sample AS
SELECT * FROM Transactions
LIMIT 100000;*/

USE FinancialTransactions;

#Basic - Top 10 zipcode with the highest total Transaction amount in CA sorted from largest to smallest
SELECT z.merchant_city, z.zipcode, CONCAT('$', FORMAT(SUM(t.amount), 2)) as `Total Amount`
FROM Zipcode z
LEFT JOIN Transactions_Sample t
ON t.zip = z.zipcode
WHERE z.merchant_state  = "CA"
GROUP BY z.merchant_state, z.merchant_city, z.zipcode
ORDER BY SUM(t.amount) DESC
LIMIT 10

#Basic 2 - Show Average transaction and Total transaction amount by age bracket in CA
SELECT 
    CASE 
        WHEN u.current_age BETWEEN 18 AND 24 THEN '18–24'
        WHEN u.current_age BETWEEN 25 AND 34 THEN '25–34'
        WHEN u.current_age BETWEEN 35 AND 44 THEN '35–44'
        WHEN u.current_age BETWEEN 45 AND 54 THEN '45–54'
        WHEN u.current_age BETWEEN 55 AND 64 THEN '55–64'
        ELSE '65+'
    END AS `Age Bracket`,
    CONCAT('$', FORMAT(SUM(amount), 2))  AS 'Total Transaction Amount',
    CONCAT('$', FORMAT(AVG(amount), 2)) AS 'Average Transaction Amount'
FROM Users u
INNER JOIN Transactions_Sample t ON u.id = t.client_id
INNER JOIN (
    SELECT zipcode FROM Zipcode WHERE merchant_state = 'CA'
) z ON z.zipcode = t.zip #filter first for faster performance
GROUP BY `Age Bracket`
ORDER BY `Age Bracket`;

#Advanced - Flag cards with high # of transactions (outliers) within a short time window (1 week)
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


/*WITH Customer_Transaction AS (
	SELECT COUNT(t.id) AS `Total Transaction`, u.id AS `Customer id`,
	DATE_FORMAT(DATE_SUB(t.date, INTERVAL WEEKDAY(t.date) DAY), '%Y-%m-%d') AS week_start
	FROM Transactions_Sample t
	JOIN Users u
	ON u.id = t.client_id
	group by u.id, week_start
	order by week_start DESC, COUNT(t.id) DESC)
SELECT `week_start`, STD(`Total Transaction`) AS `Standard Deviation`, AVG(`Total Transaction`)
FROM Customer_Transaction 
GROUP BY `week_start`
HAVING `Total Transaction` > 2.5 * `Standard Deviation`;

WITH Customer_Transaction AS (
	SELECT COUNT(t.id) AS `Total Transaction`, u.id AS `Customer id`,
	DATE_FORMAT(DATE_SUB(t.date, INTERVAL WEEKDAY(t.date) DAY), '%Y-%m-%d') AS week_start
	FROM Transactions_Sample t
	JOIN Users u
	ON u.id = t.client_id
	group by u.id, week_start
	order by week_start DESC, COUNT(t.id) DESC)
SELECT `week_start`, STD(`Total Transaction`) AS `Standard Deviation`, AVG(`Total Transaction`)
FROM Customer_Transaction 
GROUP BY `week_start`
HAVING `Total Transaction` > 2.5 * `Standard Deviation`;*/


