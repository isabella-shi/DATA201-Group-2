from flask import Flask, render_template
from db import query

app = Flask(__name__)

@app.route("/")
def index():
    sql3 = """
    WITH TransactionIntervals AS (
        SELECT 
            card_id, 
            date AS current_trans_time,
            LAG(date) OVER (PARTITION BY card_id ORDER BY date) AS prev_trans_time
        FROM Transactions_Sample
    )
    SELECT *
    FROM TransactionIntervals
    WHERE TIMESTAMPDIFF(MINUTE, prev_trans_time, current_trans_time) < 60
    LIMIT 20;
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

    return render_template("dashboard.html", 
                           data3 = query(sql3),
                           data4 = query(sql4),)

if __name__ == "__main__":
    app.run(debug=True)