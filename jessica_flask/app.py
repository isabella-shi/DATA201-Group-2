from flask import Flask, render_template
from db import query
import functools

app = Flask(__name__)


# ── YoY TRANSACTION DATA - ALL YEARS ────────────────────────────────────────
@functools.lru_cache(maxsize=None)
def get_yoy_all_years_data():
    sql = """
        WITH monthly_totals AS (
            SELECT
                DATE_FORMAT(t.date, '%Y-%m')      AS month,
                YEAR(t.date)                       AS year,
                COUNT(t.id)                        AS total_transactions,
                COUNT(DISTINCT c.client_id)        AS active_customers,
                ROUND(SUM(t.amount), 2)            AS total_spend,
                ROUND(AVG(t.amount), 2)            AS avg_transaction_size
            FROM transactions_sample t
            JOIN cards c ON t.card_id = c.id
            GROUP BY month, year
        )
        SELECT
            month,
            year,
            total_transactions,
            active_customers,
            total_spend,
            avg_transaction_size,
            ROUND(total_spend - LAG(total_spend, 12) OVER (ORDER BY month), 2) AS yoy_spend_change,
            ROUND((total_spend - LAG(total_spend, 12) OVER (ORDER BY month))
                / LAG(total_spend, 12) OVER (ORDER BY month) * 100, 1)         AS yoy_pct_change
        FROM monthly_totals
        WHERE year >= 2014  -- Only show years with YoY comparison (2014 compares to 2013)
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
            FROM transactions_sample t
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
            FROM transactions_sample t
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

    # YoY dataset - all years
    yoy_all = get_yoy_all_years_data()
    
    # Extract available years for filter dropdown
    available_years = sorted(list(set([r['year'] for r in yoy_all])), reverse=True)
    
    # Default to most recent year for initial stats
    latest_year = max(available_years) if available_years else 2018
    yoy_latest = [r for r in yoy_all if r['year'] == latest_year]
    
    mom_peak_month = max(yoy_latest, key=lambda r: float(r['total_spend'] or 0))['month'] if yoy_latest else '—'
    
    # YoY stats for latest year
    valid_yoy_pct = [float(r['yoy_pct_change']) for r in yoy_latest if r['yoy_pct_change'] is not None]
    avg_yoy_pct = round(sum(valid_yoy_pct) / len(valid_yoy_pct), 1) if valid_yoy_pct else 0
    best_yoy_pct = round(max(valid_yoy_pct), 1) if valid_yoy_pct else 0
    
    total_volume_latest = sum(float(r['total_spend'] or 0) for r in yoy_latest)

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
    )[:10]  # Top 10

    return render_template(
        "dashboard.html",
        # YoY - all years
        yoy_all=yoy_all,
        available_years=available_years,
        latest_year=latest_year,
        cumulative=cumulative,
        mom_peak_month=mom_peak_month,
        avg_yoy_pct=avg_yoy_pct,
        best_yoy_pct=best_yoy_pct,
        total_volume=total_volume_latest,
        # Churn
        churn=churn,
        segments=segments,
        winback=winback,
        statuses=statuses,
    )


if __name__ == "__main__":
    app.run(debug=True)
