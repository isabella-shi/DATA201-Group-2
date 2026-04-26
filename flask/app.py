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
    
    """

    sql8 = """
    
    """

    return render_template("dashboard.html",
                           data1 = query(sql1),
                           data2 = query(sql2)
                           )

if __name__ == "__main__":
    app.run(debug=True)
