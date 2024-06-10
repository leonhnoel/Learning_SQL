/*

Preppin' Data 2023 WK10

Data Source Bank's customers are thrilled with the developments from last week's challenge. However, they're not always the smartest... 
If a transaction isn't made on a particular day, how can the customer find out their balance? They filter the data and no values appear. 
Looks like we'll need to use a technique called scaffolding to ensure we have a row for each date in the dataset.

Requirements:

Aggregate the data so we have a single balance for each day already in the dataset, for each account
Scaffold the data so each account has a row between 31st Jan and 14th Feb
Make sure new rows have a null in the Transaction Value field
Create a parameter so a particular date can be selected
Filter to just this date

*/

-- First start with creating a variable that can be used later on for filtering 

SET selected_date = TO_DATE('2023-02-12');

-- First part is similar to solution of last week. 
-- Difference is that first only transactions are being unioned. 
-- Then they are summed on date level. 
-- After that the balance records are being unioned.

WITH from_and_to AS (

    SELECT 
        transaction_date
        ,account_to AS account
        ,value
    FROM 
        wk9_transaction_detail AS td 
    LEFT JOIN 
        wk9_transaction_path AS tp 
        ON td.transaction_id = tp.transaction_id
    LEFT JOIN
        wk9_account_information AS ai
        ON tp.account_to = ai.account_number
    WHERE 
        td.cancelled != 'Y'
    
    UNION ALL
    
    SELECT 
        transaction_date
        ,account_from AS account
        ,value * -1 
    FROM 
        wk9_transaction_detail AS td 
    LEFT JOIN 
        wk9_transaction_path AS tp 
        ON td.transaction_id = tp.transaction_id
    LEFT JOIN
        wk9_account_information AS ai
        ON tp.account_to = ai.account_number
    WHERE 
        td.cancelled != 'Y'
),

-- Now data needs to be summed on date level

from_and_to_summed AS (
    SELECT 
        account
        ,transaction_date
        ,SUM(value) AS transaction_value
    FROM 
        from_and_to
    GROUP BY
        account
        ,transaction_date
    ORDER BY 
        account
        ,transaction_date
),

-- Balance records need to be added

balance_added AS (

    SELECT
        account
        ,transaction_date
        ,transaction_value
        ,NULL AS balance
    FROM 
        from_and_to_summed

    UNION ALL

    SELECT
        account_number AS account
        ,balance_date AS transaction_date
        ,NULL AS transaction_value
        ,balance
    FROM wk9_account_information
),

-- To create a dataset with a record for each date between 2023-01-31 and 2023-02-14 we create a new dataset. 
-- Starting with a table with distinctive account number. 
-- Then we add the start date of 2023-01-31 and generate a series until 2023-02-14 with a recursive query.

distinct_accounts AS (
    SELECT DISTINCT
        account
    FROM 
        balance_added
),

accounts_and_dates AS (
    SELECT 
        account
        ,TO_DATE('2023-01-31') AS date
    FROM 
        distinct_accounts

    UNION ALL

    SELECT
        account
        ,DATEADD('day', 1, date)
    FROM
        accounts_and_dates
    WHERE 
        date < TO_DATE('2023-02-14')
)

-- Now a rolling sum per account can be calculated. 
-- Result is a dataset with record for each date in the timeframe 2023-01-31 - 2023-02-14 for each account.
-- QUALIFY is being used to filter the dataset on the variable that was created at the beginning of the query.
-- Create a parameter so a particular date can be selected.
-- Filter to just this date.

SELECT 
    ad.account
    ,ad.date
    ,COALESCE(transaction_value, 0) AS transaction_value
    ,SUM(COALESCE(transaction_value, 0) + COALESCE(balance, 0)) OVER (
        PARTITION BY ad.account
        ORDER BY date
        ) AS balance
FROM 
    accounts_and_dates AS ad
LEFT JOIN 
    balance_added AS ba
    ON ad.account = ba.account
    AND ad.date = ba.transaction_date
QUALIFY 
    ad.date = $selected_date
ORDER BY
    ad.account
    ,date;

