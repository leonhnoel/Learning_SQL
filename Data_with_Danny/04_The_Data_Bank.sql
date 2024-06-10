-- DATA WITH DANNY THE DATA BANK CHALLENGE

/*

PART A. Customer Nodes Exploration

1. How many unique nodes are there on the Data Bank system?
2. What is the number of nodes per region?
3. How many customers are allocated to each region?
4. How many days on average are customers reallocated to a different node?
5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?

*/

-- 1. How many unique nodes are there on the Data Bank system?

-- Simply use a COUNT(DISTINCT()) for this question. 
-- I've worked with the assumption that if a node_id appears in multiple regions these are all different nodes.

SELECT 
    COUNT(DISTINCT region_id, node_id) AS nr_of_unique_nodes
FROM 
    customer_nodes;

-- 2. What is the number of nodes per region?

-- Group by region, join customer_nodes table to region table to add region_name and COUNT(DISTINCT()) node_id records

SELECT 
    region_id
    ,COUNT(DISTINCT(node_id)) number_of_distinct_nodes
FROM 
    customer_nodes
GROUP BY
    region_id;

-- 3. How many customers are allocated to each region?

-- I will work with the assumption that being allocated means actively allocated. 
-- Therefore I'm looking for customer_nodes records where the end date starts with '9999' as this means the customer is currently allocated to that specific node.

SELECT 
    region_name
    ,COUNT(customer_id) AS customers_actively_allocated
FROM 
    customer_nodes AS cn
    JOIN regions AS r
    ON cn.region_id = r.region_id
WHERE 
    STARTSWITH(end_date, '9999') 
GROUP BY 
    region_name;


-- To me its much more logical that a record's end_date is NULL if its still active. So I will update the table below.

UPDATE 
    customer_nodes
SET 
    end_date = NULL
WHERE 
    STARTSWITH(end_date, '9999');

-- 4. How many days on average are customers reallocated to a different node?

-- I've interpreted the question as follows: calculate the averagea amount of days that a customer is allocated to a node before being reallocated to a new node. 

-- With below query you can see that both start_date and end_date should be included as the start_date of the second record is a day after the end_date of the first record. 
-- Therefore I use a DATEDIFF and add 1 to the result.

SELECT 
    *
    ,DATEDIFF(day, start_date, end_date) AS days
FROM
    customer_nodes
WHERE 
    end_date IS NOT NULL 
    AND customer_id = 1;

-- First create a CTE which calcs the amount of days between each start_date and end_date.
  
WITH CTE AS (
    SELECT
        customer_id
        ,start_date
        ,end_date
        ,DATEDIFF(day, start_date, end_date) +1 AS days
    FROM
        customer_nodes
    WHERE 
        end_date IS NOT NULL
)

-- Now we have the CTE in place simply calculate the average over the days column.

SELECT 
    ROUND(AVG(days), 1) AS avg_days_before_reallocation
FROM 
    CTE;

-- 5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?

-- First create a CTE containing the days between each start_date and end_date

WITH CTE AS (
    SELECT
        region_id
         ,customer_id
        ,start_date
        ,end_date
        ,DATEDIFF(day, start_date, end_date) +1 AS days
    FROM
        customer_nodes
    WHERE 
        end_date IS NOT NULL
    ORDER BY 
        days
    )

-- Then do a group by on region_name (after joining to region table). 
-- Calc Median and 80th and 90th percentile with standard Snowflake functions.
    
SELECT 
    region_name
    ,MEDIAN(days) AS median_days
    ,PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY days) AS "80TH_PERCENTILE"
    ,PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY days) AS "95TH_PERCENTILE"
FROM 
    CTE
    JOIN regions AS r
    ON CTE.region_id = r.region_id
GROUP BY 
    region_name;

/*

PART B. Customer Transactions

1. What is the unique count and total amount for each transaction type?
2. What is the average total historical deposit counts and amounts for all customers?
3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
4. What is the closing balance for each customer at the end of the month?
5. What is the percentage of customers who increase their closing balance by more than 5%?

*/

-- 1. What is the unique count and total amount for each transaction type?

SELECT 
    txn_type
    ,COUNT(txn_type) AS number_of_transactions
    ,SUM(txn_amount) AS transction_amount 
FROM 
    customer_transactions 
GROUP BY 
    txn_type;

-- 2. What is the average total historical deposit counts and amounts for all customers?

-- First calculate the total deposited amount and number of deposits per customer

WITH CTE AS (
    SELECT 
        customer_id
        ,SUM(txn_amount) AS total_deposited
        ,COUNT(txn_amount) AS deposits
    FROM 
        customer_transactions
    WHERE 
        txn_type = 'deposit'
    GROUP BY
        customer_id
)

-- Then calculate average over values that are now in CTE

SELECT
    AVG(total_deposited) AS avg_total_deposited
    ,AVG(deposits) AS avg_deposits
FROM 
    CTE;

-- 3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?

-- First create a CTE where all transactions are summed per customer_id, yearmonth and transaction type

WITH unpivoted_data AS (
    SELECT 
        customer_id
        ,YEAR(txn_date) || LPAD(MONTH(txn_date), 2, '0') AS yearmonth
        ,txn_type
        ,COUNT(*) AS transactions
    FROM 
        customer_transactions
    GROUP BY 
        customer_id
        ,yearmonth
        ,txn_type
)

-- Pivot the data from the CTE. Sum the transactions column. Then apply appropriate filters in the WHERE statement. 
-- Apparently there are no customers that have made multiple deposits and only one withdrawal or purchase in one month.

SELECT 
    * 
FROM
    unpivoted_data
PIVOT 
    (SUM(transactions) FOR txn_type IN ('deposit', 'withdrawal', 'purchase' )) 
    AS p (customer_id, yearmonth, deposits, withdrawals, purchases)
WHERE 
    deposits IS NOT NULL
    AND (withdrawals = 1 OR purchases = 1);

-- 4. What is the closing balance for each customer at the end of the month?

-- Add a row number to the original customer_transactions table so I can use window functions later on. 
-- As there are multiple records for some customers with the same date its important to create a unique id for each record. 
-- That way I can guarantee that all window_functions order in the same way and thus deliver the right results.

-- Also add the yearmonth bucket and calc new_amount. If its a deposit money is added to the balance, else it should be substracted.

-- Calc the last day of the month with LAST_DAY() and use a SUM window function. 
-- It should sum for each customer and this uses the rn from the previous table. 
-- Lastly filter the results with a new ROW_NUMBER window function in the QUALIFY statement. 
-- Give each customer_id and yearmonth its own ROW_NUMBER sequence using the rn from the enriched customer_transactions_with_rn table. 
-- Then only keep where rn = 1, as this is the last record of each month.

SELECT 
    customer_id
    ,TO_CHAR(txn_date, 'YYYYMM') AS yearmonth
    ,txn_date
    ,LAST_DAY(txn_date) AS end_of_month
    ,SUM(
        CASE 
            WHEN txn_type = 'deposit' THEN txn_amount 
            ELSE txn_amount * -1 
        END
    ) OVER (
        PARTITION BY customer_id 
        ORDER BY customer_id, txn_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS balance
FROM 
    customer_transactions
QUALIFY ROW_NUMBER() OVER (
            PARTITION BY customer_id, yearmonth 
            ORDER BY txn_date DESC
        ) = 1
ORDER BY 
    customer_id
    ,txn_date;



-- 5. What is the percentage of customers who increase their closing balance by more than 5%?

-- start with storing the results of the last question into a CTE 

WITH end_of_month_balance AS (
    SELECT 
        customer_id
        ,TO_CHAR(txn_date, 'YYYYMM') AS yearmonth
        ,SUM(
            CASE 
                WHEN txn_type = 'deposit' THEN txn_amount 
                ELSE txn_amount * -1 
            END
        ) OVER (
            PARTITION BY customer_id 
            ORDER BY customer_id, txn_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS balance
    FROM 
        customer_transactions
    QUALIFY ROW_NUMBER() OVER (
                PARTITION BY customer_id, yearmonth 
                ORDER BY txn_date DESC
            ) = 1
    ORDER BY 
        customer_id
        ,txn_date
),

-- I want to make sure that all customers have end of month balances for the first three months of the year. 
-- I'm creating a cross joined table of customer_id and yearmonths that I can later join to the CTE with the balances.

customers AS (
SELECT DISTINCT 
    customer_id 
FROM 
    customer_transactions
),

yearmonths AS (
    SELECT
         TO_CHAR(DATE '2020-01-01', 'YYYYMM') AS yearmonth
    UNION ALL
    SELECT 
         TO_CHAR(DATEADD(MONTH, 1, TO_DATE(yearmonth||01, 'YYYYMMDD')), 'YYYYMM') AS yearmonth
    FROM yearmonths
  WHERE TO_DATE(yearmonth||01, 'YYYYMMDD') < '2020-03-01'
),

customer_yearmonths AS (
SELECT customer_id, yearmonth
FROM customers
CROSS JOIN yearmonths
),

-- Join the customer_yearmonths table to the end_of_month_balances table. 
-- Make sure that null values for balance are replaced by the balance of the previous month.

end_of_month_balances_enriched AS (
    SELECT 
        cy.customer_id
        ,cy.yearmonth
        ,CASE 
            WHEN eomb.balance IS NULL THEN LAG(eomb.balance) OVER (
                PARTITION BY cy.customer_id 
                ORDER BY cy.customer_id, cy.yearmonth
                ) 
            ELSE balance 
        END AS balance
    FROM 
        end_of_month_balance AS eomb 
        RIGHT JOIN customer_yearmonths AS cy 
        ON eomb.customer_id = cy.customer_id 
        AND eomb.yearmonth = cy.yearmonth
),

-- Pivot the data and only keep 202001 and 202003 for each customer. 
-- Then calc the percentage difference and give a value of 1 if the increase is > 5%

percentage_increase AS (
    SELECT *, 
    CASE 
        WHEN ROUND((bal_202003 - bal_202001) / ABS(bal_202001) * 100, 2) > 5 THEN 1 
        ELSE 0 
    END AS percentage_difference_flag
    FROM 
        end_of_month_balances_enriched
    PIVOT (SUM(balance) FOR yearmonth IN (202001, 202003)) 
    AS p (customer_id, bal_202001, bal_202003)
)

-- Simply divide the sum of flags by the count of flags to get the percentage of customers that meet the >5% increase condition.

SELECT 
    ROUND(SUM(percentage_difference_flag) / COUNT(percentage_difference_flag),2)||'%' AS percentage_of_customers_with_increase_over_5_percent
FROM 
    percentage_increase;