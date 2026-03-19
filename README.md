# DATA201-Group-2

Dataset: Financial Transactions

Source: https://www.kaggle.com/datasets/computingvictor/transactions-fraud-datasets

**Project Overview**

This project uses a dataset of real-world financial transactions to build a normalized relational database for analysis. The goal is to turn the raw dataset into a structured schema with clear primary and foreign keys, normalize the data to 3NF, and make it possible to run useful SQL queries for transaction, card, user, merchant category, and geographic analysis.

**Normalization**

For 1NF, the main issue was the errors column in the Transactions table. Some transactions had multiple comma-separated error values in a single cell (e.g., Bad Card Number, Bad CVV), which violates the requirement that every column hold only atomic values. To fix this, the errors column was removed from Transactions and we created a separate TransactionErrors table, where each error gets its own row. The composite primary key (transaction_id, error) ensures no duplicate errors are recorded for the same transaction.

For 2NF, all non-key attributes in every table are fully dependent on the primary key. Since all tables use single-column primary keys, partial dependencies cannot exist.

For 3NF, we identified two transitive dependencies. In Transactions, zip determined city and state, creating the dependency transaction_id -> zip -> city, state. City and state were moved to a separate ZipCodes table with PK on zip. A Merchants table was also considered but ultimately rejected. After looking over the data, merchant_id does not consistently determine the same location, so it was kept as an attribute in Transactions rather than extracted into its own table.

**Final 3NF Schema**

Users (id PK, current_age, retirement_age, birth_year, birth_month, gender, address, latitude, longitude, per_capita_income, yearly_income, total_debt, credit_score, num_credit_cards)

Cards (id PK, client_id FK REFERENCES Users, card_brand, card_type, card_number, expires, cvv, has_chip, num_cards_issued, credit_limit, acct_open_date, year_pin_last_changed, card_on_dark_web)

MerchantCategories (mcc_code PK, description)

ZipCodes (zip PK, merchant_city, merchant_state)

Transactions (id PK, client_id FK REFERENCES Users, card_id FK REFERENCES Cards, mcc_code FK REFERENCES MerchantCategories, zip FK REFERENCES ZipCodes, date, amount, use_chip, merchant_id,)

TransactionErrors ((transaction_id, error) PK)


**Presentation**

[View our slides here](https://docs.google.com/presentation/d/1fy2kNmybKKRx6gloo6buD9DIAK-zP9y2sEfNjviY1_0/edit?usp=sharing)


