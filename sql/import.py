import pandas as pd
from sqlalchemy import create_engine
import getpass  

# These settings may differ depending on your local MySQL configuration
db_host = 'localhost'
db_port = '3306'
db_name = 'FinancialTransactions'

# Construct the database connection string
print("Please enter your MySQL database password:")
db_password = getpass.getpass("Password: ")

# Construct the database connection string
db_url = f'mysql+pymysql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}'
engine = create_engine(db_url)

# --- Connection Test & Data Import ---
try:
    with engine.connect() as connection:
        print("Connection successful! You can now proceed to import the data.")
except Exception as e:
    print(f"Connection failed. Please check your password in the .env file. Error: {e}")