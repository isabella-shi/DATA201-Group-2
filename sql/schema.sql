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
latitude DECIMAL(9,6),
longitude DECIMAL(9,6),
per_capita_income DECIMAL(12,2),
yearly_income DECIMAL(12,2),
total_debt DECIMAL(12,2),
credit_score INT,
num_credit_cards INT
);

CREATE TABLE Cards (
id INT PRIMARY KEY,
client_id INT,
card_brand ENUM('Visa', 'Mastercard', 'Amex', 'Discover'),
card_type ENUM('Credit', 'Debit', 'Debit (Prepaid)'),
card_number INT,
expires CHAR(7),
cvv INT,
has_chip ENUM('YES', 'NO'),
num_cards_issued INT,
credit_limit INT,
acct_open_date CHAR(7),
year_pin_last_changed YEAR,
card_on_dark_web ENUM('YES', 'NO'), -- needs to be cleaned so data is all UPPERCASE
FOREIGN KEY (client_id) REFERENCES Users (id)
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
client_id INT,
card_id INT,
amount DECIMAL(12,2),
use_chip ENUM('Swipe Transaction', 'Online Transaction', 'Chip Transaction'),
merchant_id INT,
zip CHAR(5),
mcc INT,
errors VARCHAR(30), -- to be checked later for list of error values
FOREIGN KEY (client_id) REFERENCES Users (id),
FOREIGN KEY (card_id) REFERENCES Cards (id),
FOREIGN KEY (mcc) REFERENCES MerchantCategories (mcc_code),
FOREIGN KEY (zip) REFERENCES ZipCodes (zip)
);

