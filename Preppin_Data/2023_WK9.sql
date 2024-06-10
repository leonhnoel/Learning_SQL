/*

Preppin' Data 2023 WK9

Data Source Bank usually waits until the end of the month to let customers know their bank account balance. 
Customers want more control and the ability to see how their balance changes after each transaction. 
Let's create bank statements for them!

Requirements:

Filter out the cancelled transactions
Split the flow into incoming and outgoing transactions 
Bring the data together with the Balance as of 31st Jan 
Work out the order that transactions occur for each account
    Hint: where multiple transactions happen on the same day, assume the highest value transactions happen first
Use a running sum to calculate the Balance for each account on each day (hint)
The Transaction Value should be NULL for 31st Jan, as this is the starting balance

*/

-- First create a CTE that is unioning the joined tables of transaction_path and transaction_detail twice. 
-- First with the account_to as account and second with account_from as account. 
-- Since account_from means its an outgoing transaction the value is multiplied with -1. 
-- Lastly the balance for each account number are added.

WITH CTE AS (

    SELECT 
        transaction_date
        ,account_to AS account
        ,value
        ,NULL AS balance
       
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
        ,NULL AS balance
        
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
        balance_date AS transaction_date
        ,account_number AS account
        ,0 AS value
        ,balance
    FROM wk9_account_information
)

-- Now we have transaction values for each account + the balance at the start on 2023-01-31. These need to be summed per accountnumber.
-- Since balance only has a value for the first record per account I use COALESCE to give this field a value of 0 instead of NULL. 
-- This way it can be added to the transaction_value and therefore also be summed. 

SELECT 
    account
    ,transaction_date
    ,value AS transaction_value
    ,SUM(value + COALESCE(balance, 0)) OVER (
        PARTITION BY account 
        ORDER BY transaction_date, value
        ) AS balance
FROM 
    CTE 
ORDER BY 
    account
    ,transaction_date
    ,value;
