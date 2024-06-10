-- WK8

/*
Requirements

Create a 'file date' using the month found in the file name
    The Null value should be replaced as 1
Clean the Market Cap value to ensure it is the true value as 'Market Capitalisation'
    Remove any rows with 'n/a'
Categorise the Purchase Price into groupings
    0 to 24,999.99 as 'Low'
    25,000 to 49,999.99 as 'Medium'
    50,000 to 74,999.99 as 'High'
    75,000 to 100,000 as 'Very High'
Categorise the Market Cap into groupings
    Below $100M as 'Small'
    Between $100M and below $1B as 'Medium'
    Between $1B and below $100B as 'Large' 
    $100B and above as 'Huge'
Rank the highest 5 purchases per combination of: file date, Purchase Price Categorisation and Market Capitalisation Categorisation.
Output only records with a rank of 1 to 5
*/

-- first create unioned dataset and store in CTE

WITH unioned_data AS (

    SELECT 1 as file, * FROM WK8_1
    UNION ALL 
    SELECT 2 as file, * FROM WK8_2
    UNION ALL 
    SELECT 3 as file, * FROM WK8_3
    UNION ALL 
    SELECT 4 as file, * FROM WK8_4
    UNION ALL 
    SELECT 5 as file, * FROM WK8_5
    UNION ALL 
    SELECT 6 as file, * FROM WK8_6
    UNION ALL 
    SELECT 7 as file, * FROM WK8_7
    UNION ALL 
    SELECT 8 as file, * FROM WK8_8
    UNION ALL 
    SELECT 9 as file, * FROM WK8_9
    UNION ALL 
    SELECT 10 as file, * FROM WK8_10
    UNION ALL 
    SELECT 11 as file, * FROM WK8_11
    UNION ALL 
    SELECT 12 as file, * FROM WK8_12
),

-- then start cleaning. 
-- add the file_date column
-- clean market_cap by looking for either 'B' or 'M' and make necessary multiplications
-- clean purchase price by removing '$'

cleaned_data AS (
    SELECT 
      TO_DATE('2023-' || lpad(file, 2, '0') || '-01') AS file_date
      ,CASE 
         WHEN contains(market_cap, 'B') THEN TO_DOUBLE(TRANSLATE(market_cap, '$B', '')) * 1000000000 
         ELSE TO_DOUBLE(TRANSLATE(market_cap, '$M', '')) * 1000000 
       END AS market_cap 
      ,TO_DOUBLE(REPLACE(purchase_price, '$', '')) AS purchase_price
      ,ticker
      ,sector
      ,market
      ,stock_name
    FROM 
      unioned_data
    WHERE 
      market_cap != 'n/a'
),

-- categorize both market_cap and purchase_price

categorized_data AS (

  SELECT
    file_date
    ,CASE 
       WHEN market_cap < 100000000 THEN 'Small'
       WHEN market_cap < 1000000000 THEN 'Medium'
       WHEN market_cap < 100000000000 THEN 'Large'
       ELSE 'Huge'
     END as market_cap_categorization
    ,CASE 
       WHEN purchase_price < 25000 THEN 'Low'
       WHEN purchase_price < 50000 THEN 'Medium'
       WHEN purchase_price < 75000 THEN 'High'
       WHEN purchase_price <= 100000 THEN 'Very High'
     END as purchase_price_categorization
    ,market_cap
    ,purchase_price
    ,ticker
    ,sector
    ,market
    ,stock_name
  FROM 
    cleaned_data
)

-- add the rank with RANK() and filter to keep only ranks 1-5 with QUALIFY 

SELECT 
  *
  ,RANK() OVER (PARTITION BY file_date, market_cap_categorization, purchase_price_categorization ORDER BY purchase_price DESC) AS rank
FROM 
  categorized_data
QUALIFY 
  rank < 6
ORDER BY 
  file_date
  ,purchase_price_categorization
  ,market_cap_categorization;




