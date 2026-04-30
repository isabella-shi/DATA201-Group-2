import pymysql

def get_connection():
    return pymysql.connect(
        host="localhost",
        port=3306,
        user="flaskuser",           
        password="flaskpass123!",   
        database="FinancialTransactions",
        cursorclass=pymysql.cursors.DictCursor
    )

def query(sql, params=None):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            if params is None:
                cur.execute(sql) 
            else:
                cur.execute(sql, params)
            return cur.fetchall()
    except Exception as e:
        print(f"Error: {e}")
        return []
    finally:
        conn.close()

