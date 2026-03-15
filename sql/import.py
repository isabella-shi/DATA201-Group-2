import pandas as pd
from sqlalchemy import create_engine
import getpass  

def login_db(user, host, port, db_name):
    print(f"Please enter the password for {user}@{host}:")
    password = getpass.getpass("Password: ")

    db_url = f'mysql+pymysql://{user}:{password}@{host}:{port}/{db_name}'
    return create_engine(db_url)

def import_csv_to_table(engine, file_path, table_name, money_cols=None):
    try:
        df = pd.read_csv(file_path, encoding='utf-8')
        
        # Data cleaning
        if money_cols:
            for col in money_cols:
                if col in df.columns:
                    df[col] = df[col].replace(r'[\$,]', '', regex=True).astype(float)
        
        df.to_sql(table_name, con=engine, if_exists='append', index=False)
        print(f"Success! Appended {len(df)} rows to '{table_name}'.")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    # These settings may differ depending on your local 
    db_config = {
        "user": 'root',
        "host": 'localhost',
        "port": '3306',
        "db_name": 'FinancialTransactions'
    }

    engine = login_db(**db_config)

    #Import Users table(NOTE: Update file_path before running)#
    import_csv_to_table(engine, 'file_path', 'Users', ['per_capita_income', 'yearly_income', 'total_debt'])
    #Import Cards table(NOTE: Update file_path before running)#
    import_csv_to_table(engine, 'file_path', 'Cards', ['credit_limit'])