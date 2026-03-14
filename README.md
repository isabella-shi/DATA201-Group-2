# DATA201-Group-2

Dataset: Financial Transactions

Source: https://www.kaggle.com/datasets/computingvictor/transactions-fraud-datasets


Normalization:

Already in 2NF, just need to eliminate transitive dependency in Transactions
transaction_id -> zip -> city, state


Schema:

Users (id PK, current_age, retirement_age, birth_year, birth_month, gender, address, latitude, longitude, per_capita_income, yearly_income, total_debt, credit_score, num_credit_cards)

Cards (id PK, client_id FK REFERENCES Users, card_brand, card_type, card_number, expires, cvv, has_chip, num_cards_issued, credit_limit, acct_open_date, year_pin_last_changed, card_on_dark_web)

MerchantCategories (mcc_code PK, description)

ZipCodes (zip PK, merchant_city, merchant_state)

Transactions (id PK, client_id FK REFERENCES Users, card_id FK REFERENCES Cards, mcc_code FK REFERENCES MerchantCategories, zip FK REFERENCES ZipCodes, date, amount, use_chip, merchant_id, errors)


Presentation:
[View our slides here](https://docs.google.com/presentation/d/1fy2kNmybKKRx6gloo6buD9DIAK-zP9y2sEfNjviY1_0/edit?usp=sharing)


