/*
Input the data
We want to stack the tables on top of one another, since they have the same fields in each sheet. 
Drag each table into the canvas and use a union step to stack them on top of one another
Use a wildcard union in the input step of one of the tables
Some of the fields aren't matching up as we'd expect, due to differences in spelling. Merge these fields together
Make a Joining Date field based on the Joining Day, Table Names and the year 2023
Now we want to reshape our data so we have a field for each demographic, for each new customer
Make sure all the data types are correct for each field
Remove duplicates
If a customer appears multiple times take their earliest joining date
Output the data
*/

WITH unioned_table AS (
	SELECT *, 'Jan' as "tablename" FROM WK4_JANUARY
	UNION ALL
	SELECT *, 'Feb' as "tablename" FROM WK4_FEBRUARY
	UNION ALL
	SELECT *, 'Mar' as "tablename" FROM WK4_MARCH
	UNION ALL
	SELECT *, 'Apr' as "tablename" FROM WK4_APRIL
	UNION ALL
	SELECT *, 'May' as "tablename" FROM WK4_MAY
	UNION ALL
	SELECT *, 'Jun' as "tablename" FROM WK4_JUNE
	UNION ALL
	SELECT *, 'Jul' as "tablename" FROM WK4_JULY
	UNION ALL
	SELECT *, 'Aug' as "tablename" FROM WK4_AUGUST
	UNION ALL
	SELECT *, 'Sep' as "tablename" FROM WK4_SEPTEMBER
	UNION ALL
	SELECT *, 'Oct' as "tablename" FROM WK4_OCTOBER
	UNION ALL
	SELECT *, 'Nov' as "tablename" FROM WK4_NOVEMBER
	UNION ALL
	SELECT *, 'Dec' as "tablename" FROM WK4_DECEMBER
),

pre_pivot AS (
	SELECT 
	id,
	"Demographic",
	"Value", 
	date_from_parts(2023, date_part('Month',DATE("tablename", 'Mon')), "JoiningDay") AS joined_date 

	FROM unioned_table
), 

post_pivot AS (
	SELECT 
	id,
	joined_date,
	ethnicity,
	account_type,
	date_of_birth,
	ROW_NUMBER() OVER(PARTITION BY id ORDER BY joined_date ASC) AS rn

	FROM pre_pivot

	PIVOT(MAX("Value") FOR "Demographic" IN ('Ethnicity','Account Type','Date of Birth')) AS P
	(id,
	joined_date,
	ethnicity,
	account_type,
	date_of_birth)
)

SELECT 
id,
joined_date,
ethnicity,
account_type,
date_of_birth 

FROM post_pivot

WHERE RN = 1;