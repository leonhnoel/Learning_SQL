-- WK5 

/*
Requirements

Create the bank code by splitting out off the letters from the Transaction code, call this field 'Bank'
Change transaction date to the just be the month of the transaction
Total up the transaction values so you have one row for each bank and month combination
Rank each bank for their value of transactions each month against the other banks. 1st is the highest value of transactions, 3rd the lowest. 
Without losing all of the other data fields, find:
   The average rank a bank has across all of the months, call this field 'Avg Rank per Bank'
   The average transaction value per rank, call this field 'Avg Transaction Value per Rank'
*/

WITH summary AS (
    SELECT 
      TO_CHAR(transaction_date, 'MMMM') AS transaction_month
      ,MONTH(transaction_date) AS sortmonth
      ,LEFT(transaction_code, POSITION('-', transaction_code) - 1) AS bank
      ,SUM(value) AS value
    FROM 
      WK5
    GROUP BY 
      bank
      ,transaction_month
      ,sortmonth
    ORDER BY 
      bank,
      sortmonth
),

transaction_ranks AS (
    SELECT *
    ,RANK() OVER (PARTITION BY transaction_month ORDER BY value DESC) AS transaction_rank 
    FROM 
      summary
),

transaction_rank_avg AS (
    SELECT 
      transaction_rank, 
      ROUND(AVG(value),2) AS transaction_rank_avg
    FROM 
      transaction_ranks 
    GROUP BY 
      transaction_rank
),

bank_avg AS(
    SELECT
      bank
      ,ROUND(AVG(transaction_rank), 2) AS bank_rank_avg
    FROM 
      transaction_ranks
    GROUP BY
      bank
)

SELECT 
  tr.transaction_month
  ,tr.bank
  ,tr.transaction_rank
  ,tr.value
  ,tra.transaction_rank_avg
  ,ba.bank_rank_avg
FROM
  transaction_ranks AS tr
JOIN transaction_rank_avg AS tra
  ON tr.transaction_rank = tra.transaction_rank
JOIN bank_avg AS ba
  ON tr.bank = ba.bank
ORDER BY
  sortmonth
  ,tr.transaction_rank;