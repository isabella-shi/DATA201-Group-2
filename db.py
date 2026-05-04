import pymysql

DB_CONFIG = {
    "host":        "localhost",
    "user":        "flaskuser",
    "password":    "flaskpass123!",
    "database":    "financialtransactions",  
    "cursorclass": pymysql.cursors.DictCursor,
}

def query(sql: str) -> list[dict]:
    """Execute a SELECT and return all rows as a list of dicts."""
    conn = pymysql.connect(**DB_CONFIG)
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
            return cur.fetchall()
    finally:
        conn.close()
