# DATA201-Group-2

Dataset: Financial Transactions

Source: https://www.kaggle.com/datasets/computingvictor/transactions-fraud-datasets

**Project Overview**

This project uses a dataset of real-world financial transactions to build a normalized relational database for analysis. The goal is to turn the raw dataset into a structured schema with clear primary and foreign keys, normalize the data to 3NF, and make it possible to run useful SQL queries for transaction, card, user, merchant category, and geographic analysis.

**Normalization**

For 1NF, the main issue was the errors column in the Transactions table. Some transactions had multiple comma-separated error values in a single cell (e.g., Bad Card Number, Bad CVV), which violates the requirement that every column hold only atomic values. To fix this, the errors column was removed from Transactions and we created a separate TransactionErrors table, where each error gets its own row. The composite primary key (transaction_id, error) ensures no duplicate errors are recorded for the same transaction.

For 2NF, we need to ensure that all non-key attributes are fully dependent on the entire primary key, not just part of it. For tables with single-column primary keys (Users, Cards, MerchantCategories, ZipCodes, Transactions), partial dependencies cannot exist by definition. For TransactionErrors, the table only has attributes transaction_id and error, both of which form the composite primary key, so there are no non-key attributes for a partial dependency to occur. UserLocations has latitude and longitude as the composite primary key, and address as the only non-key attribute. address depends on the full coordinate pair together, not on either coordinate alone, so it is fully dependent on the entire key and 2NF is satisfied.

For 3NF, we identified three transitive dependencies. In Transactions, zip determined city and state, creating the dependency transaction_id -> zip -> city, state. City and state were moved to a separate ZipCodes table with PK on zip. Additionally, card_id determined client_id, creating the dependency id -> card_id -> client_id. Since client_id is already accessible through the Cards table via card_id, it was excluded from Transactions to eliminate the transitive dependency. In Users, latitude and longitude determine address, creating the dependency id -> latitude, longitude -> address. Address was moved to a separate UserLocations table with PK on (latitude, longitude), and Users retains latitude and longitude as a composite foreign key referencing it. A Merchants table was also considered but ultimately rejected. After looking over the data, merchant_id does not consistently determine the same location, so it was kept as an attribute in Transactions rather than extracted into its own table.

**Final 3NF Schema**

UserLocations ((latitude, longitude) PK, address)

Users (id PK, current_age, retirement_age, birth_year, birth_month, gender, address, address FK REFERENCES UserLocations, latitude, longitude, per_capita_income, yearly_income, total_debt, credit_score, num_credit_cards)

Cards (id PK, client_id FK REFERENCES Users, card_brand, card_type, card_number, expires, cvv, has_chip, num_cards_issued, credit_limit, acct_open_date, year_pin_last_changed, card_on_dark_web)

MerchantCategories (mcc_code PK, description)

ZipCodes (zip PK, merchant_city, merchant_state)

Transactions (id PK, client_id FK REFERENCES Users, card_id FK REFERENCES Cards, mcc_code FK REFERENCES MerchantCategories, zip FK REFERENCES ZipCodes, date, amount, use_chip, merchant_id)

TransactionErrors ((transaction_id, error) PK)


**Presentation**

[View our slides here](https://docs.google.com/presentation/d/1fy2kNmybKKRx6gloo6buD9DIAK-zP9y2sEfNjviY1_0/edit?usp=sharing)


