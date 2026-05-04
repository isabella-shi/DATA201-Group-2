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

    sql5 = """
    
    """

    sql6 = """
    
    """

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
                           data7 = query(sql7),
                           data8 = query(sql8)
                           )

if __name__ == "__main__":
    app.run(debug=True)
