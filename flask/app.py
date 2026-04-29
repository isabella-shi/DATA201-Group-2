# app.py
from flask import Flask, render_template
from db import query

app = Flask(__name__)

@app.route("/")
def index():

    ###################################
    #                                 #
    #    Isabella's visualizations    #
    #                                 #
    ###################################

    sql1 = """
        SELECT gender, ROUND(AVG(yearly_income),2) AS avg_income, ROUND(AVG(total_debt),2) AS avg_debt
        FROM Users
        GROUP BY gender;
    """

    sql2 = """
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

    ###################################
    #                                 #
    #      Rene's visualizations      #
    #                                 #
    ###################################

    sql3 = """
    
    """

    sql4 = """
    
    """

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
                           data7 = query(sql7),
                           data8 = query(sql8)
                           )

if __name__ == "__main__":
    app.run(debug=True)
