/*
For the transactions file:
Filter the transactions to just look at DSB . These will be transactions that contain DSB in the Transaction Code field
Rename the values in the Online or In-person field, Online of the 1 values and In-Person for the 2 values.
Change the date to be the quarter.
Sum the transaction values for each quarter and for each Type of Transaction (Online or In-Person).

For the targets file:
Pivot the quarterly targets so we have a row for each Type of Transaction and each Quarter.
Rename the fields.
Remove the 'Q' from the quarter field and make the data type numeric.

Join the two datasets together.
Remove unnecessary fields
Calculate the Variance to Target for each row
Output the data
*/

WITH CTE AS (
SELECT online_or_inperson, REPLACE(quarter, 'Q', '') as quarter, target 
FROM wk3_targets
UNPIVOT(target FOR quarter IN (Q1, Q2, Q3, Q4)))

SELECT CTE.online_or_inperson as "Online or in Person", CTE.quarter as "Quarter", SUM(VALUE) AS "Value", CTE.target as "Quarterly Targets", SUM(Value) - CTE.target AS "Variance"
FROM WK1_DATA_SOURCE_BANK AS w
INNER JOIN CTE on CTE.quarter = QUARTER(TO_DATE(TRANSACTION_DATE, 'DD/MM/YYYY HH:MI:SS')) 
AND CTE.online_or_inperson = 
	CASE online_or_in_person 
	WHEN 1 THEN 'Online' 
	WHEN 2 THEN 'In-Person' 
	END 
WHERE CONTAINS(transaction_code,'DSB')
GROUP BY CTE.quarter, CTE.online_or_inperson, CTE.target;