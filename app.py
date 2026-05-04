from flask import Flask, render_template
from db import query
import functools

app = Flask(__name__)


# ── MoM TRANSACTION DATA - 2018 ONLY ────────────────────────────────────────
@functools.lru_cache(maxsize=None)
def get_mom_2018_data():
    sql = """
        WITH monthly_totals AS (
            SELECT
                DATE_FORMAT(t.date, '%Y-%m')      AS month,
                COUNT(t.id)                        AS total_transactions,
                COUNT(DISTINCT c.client_id)        AS active_customers,
                ROUND(SUM(t.amount), 2)            AS total_spend,
                ROUND(AVG(t.amount), 2)            AS avg_transaction_size
            FROM transactions t
            JOIN cards c ON t.card_id = c.id
            WHERE YEAR(t.date) = 2018
            GROUP BY month
        )
        SELECT
            month,
            total_transactions,
            active_customers,
            total_spend,
            avg_transaction_size,
            ROUND(total_spend - LAG(total_spend) OVER (ORDER BY month), 2) AS mom_spend_change,
            ROUND((total_spend - LAG(total_spend) OVER (ORDER BY month))
                / LAG(total_spend) OVER (ORDER BY month) * 100, 1)         AS mom_pct_change
        FROM monthly_totals
        ORDER BY month;
    """
    return query(sql)


# ── CUMULATIVE DATA - ALL TIME ──────────────────────────────────────────────
@functools.lru_cache(maxsize=None)
def get_cumulative_data():
    sql = """
        WITH monthly_totals AS (
            SELECT
                DATE_FORMAT(t.date, '%Y-%m')      AS month,
                ROUND(SUM(t.amount), 2)            AS total_spend
            FROM transactions t
            JOIN cards c ON t.card_id = c.id
            GROUP BY month
        )
        SELECT
            month,
            total_spend,
            ROUND(AVG(total_spend) OVER (
                ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ), 2)                                  AS rolling_3mo_avg,
            ROUND(SUM(total_spend) OVER (ORDER BY month), 2) AS cumulative_spend
        FROM monthly_totals
        ORDER BY month;
    """
    return query(sql)


# ── CHURN DATA ───────────────────────────────────────────────────────────────
@functools.lru_cache(maxsize=None)
def get_churn_data():
    sql = """
        WITH last_tx AS (
            SELECT
                c.client_id,
                MAX(t.date)               AS last_transaction_date,
                COUNT(t.id)               AS lifetime_transactions,
                ROUND(SUM(t.amount))      AS lifetime_spend,
                COUNT(DISTINCT t.card_id) AS cards_used
            FROM transactions t
            JOIN cards c ON t.card_id = c.id
            GROUP BY c.client_id
        )
        SELECT
            l.client_id,
            u.gender,
            u.current_age,
            u.credit_score,
            u.yearly_income,
            u.total_debt,
            l.last_transaction_date,
            DATEDIFF('2019-12-31', l.last_transaction_date) AS days_inactive,
            l.lifetime_transactions,
            l.lifetime_spend,
            l.cards_used,
            CASE
                WHEN DATEDIFF('2019-12-31', l.last_transaction_date) > 365 THEN 'Churned'
                WHEN DATEDIFF('2019-12-31', l.last_transaction_date) > 90  THEN 'At Risk'
                ELSE 'Active'
            END AS activity_status
        FROM last_tx l
        JOIN users u ON l.client_id = u.id
        ORDER BY days_inactive DESC;
    """
    return query(sql)


# ── ROUTE ────────────────────────────────────────────────────────────────────
@app.route("/")
def insights():

    # MoM dataset - 2018 only
    mom_2018 = get_mom_2018_data()
    mom_peak_month = max(mom_2018, key=lambda r: float(r['total_spend'] or 0))['month'] if mom_2018 else '—'
    valid_pct      = [float(r['mom_pct_change']) for r in mom_2018 if r['mom_pct_change'] is not None]
    avg_mom_pct    = round(sum(valid_pct) / len(valid_pct), 1) if valid_pct else 0
    best_mom_pct   = round(max(valid_pct), 1) if valid_pct else 0
    total_volume_2018 = sum(float(r['total_spend'] or 0) for r in mom_2018)

    # Cumulative dataset - all time
    cumulative = get_cumulative_data()

    # Churn dataset
    churn = get_churn_data()
    statuses = ['Churned', 'At Risk', 'Active']
    segments = {}
    for s in statuses:
        group = [r for r in churn if r['activity_status'] == s]
        total_spend = sum(float(r['lifetime_spend'] or 0) for r in group)
        segments[s] = {
            'count':       len(group),
            'total_spend': total_spend,
            'avg_spend':   round(total_spend / len(group)) if group else 0,
            'avg_credit':  round(sum(float(r['credit_score'] or 0) for r in group) / len(group)) if group else 0,
        }

    # Win-back list: All At Risk customers sorted by lifetime spend desc
    winback = sorted(
        [r for r in churn if r['activity_status'] == 'At Risk'],
        key=lambda r: float(r['lifetime_spend'] or 0),
        reverse=True
    )[:10]  # Top 10 instead of 6

    return render_template(
        "dashboard.html",
        # MoM
        mom_2018=mom_2018,
        cumulative=cumulative,
        mom_peak_month=mom_peak_month,
        avg_mom_pct=avg_mom_pct,
        best_mom_pct=best_mom_pct,
        total_volume=total_volume_2018,
        # Churn
        churn=churn,
        segments=segments,
        winback=winback,
        statuses=statuses,
    )


if __name__ == "__main__":
    app.run(debug=True)
