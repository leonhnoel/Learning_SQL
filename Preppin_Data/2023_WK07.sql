-- WK7

/*
Requirements


For the Account Information table:
    Make sure there are no null values in the Account Holder ID
Ensure there is one row per Account Holder ID
Joint accounts will have 2 Account Holders, we want a row for each of them
For the Account Holders table:
    Make sure the phone numbers start with 07
Bring the tables together
Filter out cancelled transactions 
Filter to transactions greater than £1,000 in value 
Filter out Platinum accounts
*/

-- create a CTE where the column account_holder_id is splitted with LATERAL SPLIT_TO_TABLE. 

WITH CTE AS (

    SELECT 
      ai.account_number
      ,account_type
      ,ais.value AS account_holder_id
      ,balance_date
      ,balance
    FROM 
      WK7_ACCOUNT_INFORMATION as ai, 
    LATERAL SPLIT_TO_TABLE(account_holder_id, ', ') AS ais
    WHERE 
      account_holder_id IS NOT NULL
    )

-- retrieve all necessary columns and add JOINS and WHERE conditions
    
SELECT 
  tp.transaction_id
  ,account_to
  ,transaction_date
  ,value
  ,account_number
  ,account_type
  ,balance_date
  ,balance
  ,name
  ,dob AS day_of_birth
  ,0 || contact_number as contact_number
  ,first_line_of_address
FROM 
  CTE 
INNER JOIN WK7_ACCOUNT_HOLDERS AS ah
  ON CTE.account_holder_id = ah.account_holder_id
INNER JOIN WK7_TRANSACTION_PATH AS tp
  ON CTE.account_number = tp.account_from
INNER JOIN WK7_TRANSACTION_DETAIL AS td
  ON tp.transaction_id = td.transaction_id
WHERE 
  account_type != 'Platinum' 
  AND td.value > 1000
  AND td.cancelled = 'N';
