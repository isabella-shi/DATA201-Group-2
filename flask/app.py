# app.py
from flask import Flask, render_template
from db import query
from decimal import Decimal

app = Flask(__name__)

def decimal_default(obj):
    if isinstance(obj, list):
        return [decimal_default(i) for i in obj]
    if isinstance(obj, dict):
        return {k: decimal_default(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        return float(obj)
    return obj

@app.route("/")
def index():

    ###################################
    #                                 #
    #    Isabella's visualizations    #
    #                                 #
    ###################################

    sql1 = """
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
    """

    sql2 = """
        SELECT
            CASE
                WHEN current_age BETWEEN 18 AND 25 THEN '18-25'
                WHEN current_age BETWEEN 26 AND 39 THEN '26-39'
                WHEN current_age BETWEEN 40 AND 59 THEN '40-59'
                ELSE '60+'
            END AS age_group,
            CASE
                WHEN credit_score < 580 THEN 'Poor (<580)'
                WHEN credit_score BETWEEN 580 AND 669 THEN 'Fair (580-669)'
                WHEN credit_score BETWEEN 670 AND 739 THEN 'Good (670-739)'
                WHEN credit_score BETWEEN 740 AND 799 THEN 'Very Good (740-799)'
                ELSE 'Excellent (800+)'
            END AS credit_tier,
            COUNT(*) AS num_users
        FROM Users
        GROUP BY age_group, credit_tier
        ORDER BY MIN(current_age), credit_tier;
    """

    ###################################
    #                                 #
    #      Rene's visualizations      #
    #                                 #
    ###################################

    sql3 = """
        SELECT card_brand, COUNT(*) AS total_cards
        FROM Cards
        GROUP BY card_brand;
    
    """

    sql4 = """
    WITH UserSpending AS (
            SELECT 
                u.id AS user_id,
                u.gender,
                CASE 
                    WHEN u.current_age BETWEEN 18 AND 29 THEN '18-29'
                    WHEN u.current_age BETWEEN 30 AND 49 THEN '30-49'
                    ELSE '50+'
                END AS age_group,
                SUM(CAST(REPLACE(REPLACE(t.amount, '$', ''), ',', '') AS DECIMAL(10,2))) AS total_spent
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
    
    """
    res3 = query(sql3)
    res4 = query(sql4)

    data3 = decimal_default(res3)
    data4 = decimal_default(res4)

    spending_groups = {
        'Male': {'18-29': [], '30-49': [], '50+': []},
        'Female': {'18-29': [], '30-49': [], '50+': []}
    }
    for row in data4:
        g, a = row['gender'], row['age_group']
        if g in spending_groups and a in spending_groups[g]:
            spending_groups[g][a].append(row)

    chart_max = max([row['total_spent'] for row in data4]) * 1.1 if data4 else 1000
    
    ###################################
    #                                 #
    #    Jessica's visualizations     #
    #                                 #
    ###################################

    # YoY Transaction Analysis
    sql5 = """
        WITH monthly_totals AS (
            SELECT
                DATE_FORMAT(t.date, '%%Y-%%m') AS month,
                COUNT(t.id) AS total_transactions,
                COUNT(DISTINCT c.client_id) AS active_customers,
                ROUND(SUM(t.amount), 2) AS total_spend,
                ROUND(AVG(t.amount), 2) AS avg_transaction_size
            FROM Transactions t
            JOIN Cards c ON t.card_id = c.id
            WHERE YEAR(t.date) IN (2017, 2018)
            GROUP BY month
        )
        SELECT
            month,
            total_transactions,
            active_customers,
            total_spend,
            avg_transaction_size,
            ROUND(total_spend - LAG(total_spend, 12) OVER (ORDER BY month), 2) AS yoy_spend_change,
            ROUND((total_spend - LAG(total_spend, 12) OVER (ORDER BY month))
                / LAG(total_spend, 12) OVER (ORDER BY month) * 100, 1) AS yoy_pct_change
        FROM monthly_totals
        WHERE month LIKE '2018-%%'
        ORDER BY month
    """

    # Customer Churn Analysis
    sql6 = """
        WITH last_tx AS (
            SELECT
                c.client_id,
                MAX(t.date) AS last_transaction_date,
                COUNT(t.id) AS lifetime_transactions,
                ROUND(SUM(t.amount)) AS lifetime_spend
            FROM Transactions t
            JOIN Cards c ON t.card_id = c.id
            GROUP BY c.client_id
        )
        SELECT
            CASE
                WHEN DATEDIFF('2019-12-31', l.last_transaction_date) > 365 THEN 'Churned'
                WHEN DATEDIFF('2019-12-31', l.last_transaction_date) > 90  THEN 'At Risk'
                ELSE 'Active'
            END AS activity_status,
            COUNT(*) AS customer_count,
            ROUND(AVG(u.credit_score)) AS avg_credit_score,
            ROUND(SUM(l.lifetime_spend)) AS total_spend
        FROM last_tx l
        JOIN Users u ON l.client_id = u.id
        GROUP BY activity_status
        ORDER BY FIELD(activity_status, 'Active', 'At Risk', 'Churned')
    """

    res5 = query(sql5)
    res6 = query(sql6)
    
    data5 = decimal_default(res5)
    data6 = decimal_default(res6)
    
    # Process churn data into segments
    churn_segments = {}
    for row in data6:
        churn_segments[row['activity_status']] = {
            'count': row['customer_count'],
            'avg_credit': row['avg_credit_score'],
            'total_spend': row['total_spend']
        }
    
    # Calculate YoY stats
    yoy_stats = {
        'peak_month': 'Dec 2018',
        'avg_yoy': 0,
        'best_yoy': 0
    }
    
    if data5:
        valid_yoy = [r['yoy_pct_change'] for r in data5 if r['yoy_pct_change'] is not None]
        if valid_yoy:
            yoy_stats['avg_yoy'] = round(sum(valid_yoy) / len(valid_yoy), 1)
            yoy_stats['best_yoy'] = round(max(valid_yoy), 1)
            max_spend_row = max(data5, key=lambda x: x['total_spend'])
            yoy_stats['peak_month'] = max_spend_row['month']


    ###################################
    #                                 #
    #     Rachel's visualizations     #
    #                                 #
    ###################################

    sql7 = """
            SELECT 
            DATE_FORMAT(`date`, '%%Y-%%m') AS month,
            ROUND(SUM(ABS(CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS DECIMAL(10,2)))), 2) AS total_spending
            FROM Transactions_Sample
            WHERE amount IS NOT NULL
              AND amount != ''
              AND `date` IS NOT NULL
            GROUP BY DATE_FORMAT(`date`, '%%Y-%%m')
            ORDER BY month;
    """

    sql8 = """
        SELECT 
            mc.description AS category,
            ROUND(SUM(ABS(CAST(REPLACE(REPLACE(t.amount, '$', ''), ',', '') AS DECIMAL(10,2)))), 2) AS total_spending
        FROM Transactions_Sample t
        JOIN MerchantCategories mc
            ON t.mcc = mc.mcc_code
        WHERE t.amount IS NOT NULL
          AND t.amount != ''
        GROUP BY mc.description
        ORDER BY total_spending DESC
        LIMIT 10;
    """
    return render_template("dashboard.html",
                           data1 = query(sql1),
                           data2 = query(sql2),
                           data3=data3, 
                           data4=data4, 
                           spending_groups=spending_groups, 
                           chart_max=chart_max,
                           data5=data5,
                           data6=data6,
                           churn_segments=churn_segments,
                           yoy_stats=yoy_stats,
                           data7 = query(sql7),
                           data8 = query(sql8)
                           )

if __name__ == "__main__":
    app.run(debug=True)
