-- Financial Transactions Database
-- Group 2

CREATE DATABASE FinancialTransactions;
USE FinancialTransactions;

CREATE TABLE Users (
    id INT PRIMARY KEY,
    current_age INT,
    retirement_age INT,
    birth_year INT,
    birth_month INT,
    gender VARCHAR(10),
    address VARCHAR(300),
    latitude DECIMAL(9 , 6 ),
    longitude DECIMAL(9 , 6 ),
    per_capita_income DECIMAL(12 , 2 ),
    yearly_income DECIMAL(12 , 2 ),
    total_debt DECIMAL(12 , 2 ),
    credit_score INT,
    num_credit_cards INT
);

CREATE TABLE Cards (
    id INT PRIMARY KEY,
    client_id INT,
    card_brand ENUM('Visa', 'Mastercard', 'Amex', 'Discover'),
    card_type ENUM('Credit', 'Debit', 'Debit (Prepaid)'),
    card_number BIGINT,
    expires CHAR(7),
    cvv INT,
    has_chip ENUM('YES', 'NO'),
    num_cards_issued INT,
    credit_limit INT,
    acct_open_date CHAR(7),
    year_pin_last_changed YEAR,
    card_on_dark_web ENUM('Yes', 'No'),
    FOREIGN KEY (client_id)
        REFERENCES Users (id)
);

CREATE TABLE MerchantCategories (
    mcc_code INT PRIMARY KEY,
    description VARCHAR(100)
);

CREATE TABLE ZipCodes (
    zip CHAR(5) PRIMARY KEY,
    city VARCHAR(100),
    state CHAR(2)
);

CREATE TABLE Transactions (
    id INT PRIMARY KEY,
    date DATETIME,
    card_id INT,
    amount DECIMAL(12 , 2 ),
    use_chip ENUM('Swipe Transaction', 'Online Transaction', 'Chip Transaction'),
    merchant_id INT,
    zip CHAR(5),
    mcc INT,
    FOREIGN KEY (card_id)
        REFERENCES Cards (id),
    FOREIGN KEY (mcc)
        REFERENCES MerchantCategories (mcc_code),
    FOREIGN KEY (zip)
        REFERENCES ZipCodes (zip)
);

CREATE TABLE TransactionErrors (
    transaction_id INT,
    error ENUM('Bad Card Number', 'Bad CVV', 'Bad Expiration', 
               'Bad PIN', 'Bad Zipcode', 'Insufficient Balance', 
               'Technical Glitch'),
    PRIMARY KEY (transaction_id, error),
    FOREIGN KEY (transaction_id) REFERENCES Transactions (id)
);

SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE './users_data.csv'
INTO TABLE Users
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(id, current_age, retirement_age, birth_year, birth_month, gender, address, latitude, longitude,
 @per_capita_income, @yearly_income, @total_debt, credit_score, num_credit_cards)
SET
    per_capita_income = REPLACE(@per_capita_income, '$', ''),
    yearly_income = REPLACE(@yearly_income, '$', ''),
    total_debt = REPLACE(@total_debt, '$', '');

LOAD DATA LOCAL INFILE './cards_data.csv'
INTO TABLE Cards
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(id, client_id, card_brand, card_type, card_number, expires, cvv, has_chip, num_cards_issued,
@credit_limit, acct_open_date, year_pin_last_changed, card_on_dark_web)
SET
    credit_limit = REPLACE(@credit_limit, '$', '');
    
LOAD DATA LOCAL INFILE './mcc_codes.csv'
INTO TABLE MerchantCategories
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(mcc_code, description);

CREATE TEMPORARY TABLE TempZips (
zip VARCHAR(5),
city VARCHAR(100),
state CHAR(2)
);

LOAD DATA LOCAL INFILE './transactions_data.csv'
INTO TABLE TempZips
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@id, @date, @card_id, @amount, @use_chip,
 @merchant_id, city, state, @zip, @mcc, @errors)
SET
    zip = CASE
              WHEN @zip LIKE '%-%'
              THEN LEFT(TRIM(@zip), 5)
              WHEN @zip LIKE '%.'
              THEN LPAD(REPLACE(TRIM(@zip), '.', ''), 5, '0')
              ELSE TRIM(@zip)
          END;

-- Insert only distinct, valid zip rows
INSERT IGNORE INTO ZipCodes (zip, city, state)
SELECT DISTINCT zip, city, state
FROM TempZips
WHERE zip IS NOT NULL 
  AND TRIM(zip) != '';

DROP TEMPORARY TABLE TempZips;

SET FOREIGN_KEY_CHECKS = 0;

LOAD DATA LOCAL INFILE './transactions_data.csv'
INTO TABLE Transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(id, date, @client_id, card_id, @amount, use_chip,
 merchant_id, @merchant_city, @merchant_state, @zip, mcc, @errors)
SET
    amount = CASE
                 WHEN TRIM(@amount) LIKE '($%)'
                 THEN -CAST(REPLACE(REPLACE(REPLACE(TRIM(@amount), '($', ''), ')', ''), '$', '') AS DECIMAL(12,2))
                 ELSE CAST(REPLACE(TRIM(@amount), '$', '') AS DECIMAL(12,2))
             END,
    zip    = CASE
                 WHEN @zip LIKE '%-%'
                 THEN LEFT(TRIM(@zip), 5)
                 WHEN @zip LIKE '%.'
                 THEN LPAD(REPLACE(TRIM(@zip), '.', ''), 5, '0')
                 ELSE TRIM(@zip)
             END;

CREATE TEMPORARY TABLE TempErrors (
    transaction_id INT,
    raw_errors     VARCHAR(60)
);

LOAD DATA LOCAL INFILE './transactions_data.csv'
INTO TABLE TempErrors
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@id, @date, @client_id, @card_id, @amount, @use_chip,
 @merchant_id, @merchant_city, @merchant_state, @zip, @mcc, raw_errors)
SET transaction_id = @id;

INSERT IGNORE INTO TransactionErrors (transaction_id, error)
SELECT transaction_id, TRIM(SUBSTRING_INDEX(raw_errors, ',', 1))
FROM TempErrors
WHERE raw_errors IS NOT NULL AND TRIM(raw_errors) != '';

INSERT IGNORE INTO TransactionErrors (transaction_id, error)
SELECT transaction_id, TRIM(SUBSTRING_INDEX(raw_errors, ',', -1))
FROM TempErrors
WHERE raw_errors LIKE '%,%';

DROP TEMPORARY TABLE TempErrors;

SET FOREIGN_KEY_CHECKS = 1;