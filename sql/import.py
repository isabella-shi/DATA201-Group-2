import pandas as pd
from sqlalchemy import create_engine
import getpass
import json  

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
                    df[col] = (df[col]
    .str.strip()                              # remove trailing spaces
    .replace(r'[\$,\s]', '', regex=True)      # remove $, commas, spaces
    .replace(r'^\((.+)\)$', r'-\1', regex=True)  # convert (77.00) to -77.00
    .astype(float))
        
        df.to_sql(table_name, con=engine, if_exists='append', index=False)
        print(f"Success! Appended {len(df)} rows to '{table_name}'.")
    except Exception as e:
        print(f"An error occurred: {e}")

#to upload Transactions data in chunks of 50,000 at a time
def import_csv_chunked(engine, file_path, table_name, money_cols=None, chunksize=50000):
    try:
        chunks = pd.read_csv(file_path, encoding='utf-8', chunksize=chunksize)
        
        total_rows = 0
        for i, df in enumerate(chunks):
            
            if money_cols:
                for col in money_cols:
                    if col in df.columns:
                        df[col] = (df[col]
                            .str.strip()
                            .replace(r'[\$,\s]', '', regex=True)
                            .replace(r'^\((.+)\)$', r'-\1', regex=True)
                            .astype(float))

            df.to_sql(table_name, con=engine, if_exists='append', index=False)
            total_rows += len(df)
            print(f"Chunk {i+1} done — {total_rows} rows inserted so far...")

        print(f"Done! Total {total_rows} rows imported into '{table_name}'.")
    except Exception as e:
        import traceback
        traceback.print_exc()

def import_json_to_table(engine, file_path, table_name):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        df = pd.DataFrame(list(data.items()), columns=['mcc_code', 'description'])
        
        df.to_sql(table_name, con=engine, if_exists='append', index=False)
        print(f"Success! Imported {len(df)} categories into '{table_name}'.")
    except Exception as e:
        print(f"JSON Import Error: {e}")

#derive zip, merchant_city, merchant_state from Transaction to populate Zipcode tables
def create_zipcode_table(engine):
    try:
        # Read only the needed columns from Transactions
        df = pd.read_sql("SELECT DISTINCT zip, merchant_city, merchant_state FROM Transactions", con=engine)

        # Drop any rows where zip is null since it's the PK
        df = df.dropna(subset=['zip'])

        # Rename to match your new table's column names
        df = df.rename(columns={'zip': 'zipcode'})

        # Remove duplicates keeping first occurrence
        df = df.drop_duplicates(subset=['zipcode'])

        df.to_sql('Zipcode', con=engine, if_exists='replace', index=False)
        print(f"Done! {len(df)} zipcodes imported into 'Zipcode' table.")

    except Exception as e:
        import traceback
        traceback.print_exc()



if __name__ == "__main__":
    # These settings may differ depending on your local 
    db_config = {
        "user": 'root',
        "host": 'localhost',
        "port": '3306',
        "db_name": 'FinancialTransactions'
    }

    engine = login_db(**db_config)

    Import Users table(NOTE: Update file_path before running)
    import_csv_to_table(engine, filepath, 'Users', ['per_capita_income', 'yearly_income', 'total_debt'])

    #Import Cards table(NOTE: Update file_path before running)
    #import_csv_to_table(engine, filepath, 'Cards', ['credit_limit'])

    #Import Merchant table(NOTE: Update file_path before running)
    #import_json_to_table(engine, filepath, 'MerchantCategories')

    #Import Transactions table(NOTE: Update file_path before running)
    #import_csv_chunked(engine, filepath, 'Transactions', ['amount'])

    #to create new Zipcode table derived Transactions columns
    create_zipcode_table(engine)
