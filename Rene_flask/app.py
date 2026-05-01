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

    return render_template("dashboard.html", 
                           data3=data3, 
                           data4=data4, 
                           spending_groups=spending_groups, 
                           chart_max=chart_max)

if __name__ == "__main__":
    app.run(debug=True)