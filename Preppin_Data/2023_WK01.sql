/* 

Preppin' date 2023 WK1

Requirements
Input the data (help)
Split the Transaction Code to extract the letters at the start of the transaction code. These identify the bank who processes the transaction (help)
Rename the new field with the Bank code 'Bank'. 
Rename the values in the Online or In-person field, Online of the 1 values and In-Person for the 2 values. 
Change the date to be the day of the week (help)
Different levels of detail are required in the outputs. You will need to sum up the values of the transactions in three ways (help):
1. Total Values of Transactions by each bank
2. Total Values by Bank, Day of the Week and Type of Transaction (Online or In-Person)
3. Total Values by Bank and Customer Code

*/

-- create transaction table to use for aggregating on different levels of detail

WITH transactions AS (
SELECT 
SPLIT_PART(transaction_code, '-', 1) AS bank,
CASE online_or_in_person
WHEN 1 THEN 'online'
WHEN 2 THEN 'in-person'
END AS online_or_in_person,
DAYNAME( TO_DATE( LEFT( transaction_date, 10 ), 'DD/MM/YYYY' ) ) AS weekday,
value,
customer_code
FROM WK1_DATA_SOURCE_BANK
)

-- 1. Total Values of Transactions by each bank

SELECT bank, SUM(value) AS value
FROM transactions
GROUP BY bank

-- 2. Total Values by Bank, Day of the Week and Type of Transaction (Online or In-Person)

SELECT bank, online_or_in_person, weekday, SUM(value) AS value
FROM transactions
GROUP BY bank, online_or_in_person, weekday

-- 3. Total Values by Bank and Customer Code

SELECT bank, customer_code, SUM(value) AS value
FROM transactions
GROUP BY bank, customer_code
