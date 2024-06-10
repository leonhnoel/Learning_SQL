/*

The challenge this week is heavily inspired by a real life scenario and I'm sure many organisations will be able to relate to the quirky rules they have to follow when doing regulatory reporting. Often with the reasoning behind it being "because that's the way it's always been done!" 

Data Source Bank must assign new customers to the next working day, even if they join at the weekend, or online on a public holiday. What's more, they need to report their total new customers for the month on the last working day of the month. This means any customers joining on that last working day will actually be counted in the following month. For example, 31st December 2021 was a Friday. The total number of customers for December would be reported on this day. Any customers joining on the day of 31st December 2021 itself will be counted in January's count of new customers. 

What makes this even more confusing is trying to align with branches in Ireland. Ireland will of course have different Bank Holidays and so the definition of a working day becomes harder to define. For DSB, the UK reporting day supersedes the ROI reporting day. If the UK has a bank holiday where ROI does not, these customers will be reported on the next working day in the UK. If ROI has a bank holiday where the UK does not, the customer count will be 0 for ROI, but it will still be treated as a working day when assigning the reporting month start/end.

Fill down the years and create a date field for the UK bank holidays
Combine with the UK New Customer dataset
Create a Reporting Day flag
    UK bank holidays are not reporting days
    Weekends are not reporting days
For non-reporting days, assign the customers to the next reporting day
Calculate the reporting month, as per the definition above
Filter out January 2024 dates
Calculate the reporting day, defined as the order of days in the reporting month
    You'll notice reporting months often have different numbers of days!
Now let's focus on ROI data. This has already been through a similar process to the above, but using the ROI bank holidays. We'll have to align it with the UK reporting schedule
Rename fields so it's clear which fields are ROI and which are UK
Combine with UK data
For days which do not align, find the next UK reporting day and assign new customers to that day (for more detail, refer to the above description of the challenge)
Make sure null customer values are replaced with 0's
Create a flag to find which dates have differing reporting months when using the ROI/UK systems

*/

-----------------------------------------------------------

-- SELECT * FROM wk12_uk_holidays;

-- add a rownumber, so the year can be filled down later on

WITH add_rn AS (
    SELECT 
        *
        ,ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS rn
    FROM 
        wk12_uk_holidays
)

-- SELECT * FROM add_rn;

-- use the added rn to fill down the year
-- records without a date can be filtered out. 
-- I have to use qualify as we can only filter them out after the MAX window function has calculated the max year per record

,year_filled_down AS (
    SELECT 
        MAX(year) OVER(ORDER BY rn) AS year
        ,date
        ,bank_holiday
    FROM 
        add_rn
    QUALIFY 
        date != ''
)

-- SELECT * FROM year_filled_down;

-- now concatenate the year and day-month columns and convert to date datatype

,bank_holidays AS (
    SELECT
        TRY_TO_DATE(year||date, 'YYYYDD-MON') AS new_date
        ,bank_holiday
    FROM
        year_filled_down
)

-- SELECT * FROM bank_holidays;

-- SELECT * FROM wk12_uk_new_customers;

-- now that I have a CTE with all bankholidays with corresponding dates I can calculate whether a join_date in the wk12_uk_new_customers table is a reporting date or not.
-- based on whether a join_date is a reporting day I can then calculate what the next reporting date is. 
-- I do this by using a window function. 
-- I only look at the current and following records and want to see the first join date ( MIN(join_date) ) where the reporting_flag is indeed a reporting day.

,new_customers_joined AS ( 
    SELECT
        TO_DATE(unc.date, 'MM/DD/YY') AS join_date
        ,dayname(date) AS day_name
        ,bank_holiday
        ,CASE 
            WHEN day_name IN ('Sat', 'Sun') OR bank_holiday IS NOT NULL THEN 'non-reporting day'
            ELSE 'reporting day'
        END AS reporting_flag
        ,MIN(
            CASE 
                WHEN reporting_flag = 'reporting day' THEN join_date
            END
        ) OVER (
            ORDER BY join_date
            ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
        ) AS next_reporting_date
        ,new_customers
    FROM
        wk12_uk_new_customers AS unc
    LEFT JOIN
        bank_holidays AS bh
        ON TO_DATE(unc.date, 'MM/DD/YY') = bh.new_date
)

-- SELECT * FROM new_customers_joined ORDER BY join_date;

-- The following CTE sums the amount of new customers per reporting_day. 
-- This is done by grouping on next_reporting_date ( which was calculated in previous CTE )

,uk_grouped AS (
    SELECT
        next_reporting_date AS uk_reporting_date
        ,SUM(new_customers) AS uk_new_customers
    FROM
        new_customers_joined
    GROUP BY
        uk_reporting_date
    HAVING
        uk_reporting_date IS NOT NULL
    ORDER BY
        uk_reporting_date
)

-- SELECT * FROM uk_grouped ORDER BY uk_reporting_date;

-- The following CTE only does renaming of columns and converts the reporting_date column to date data type.

,roi_renamed AS (
    SELECT
        reporting_month AS roi_reporting_month
        ,reporting_day AS roi_reporting_day
        ,new_customers AS roi_new_customers
        ,TO_DATE(reporting_date, 'MM/DD/YY') AS roi_reporting_date
    FROM
        wk12_roi_new_customers
)

-- SELECT * FROM roi_renamed;

-- I want to see which dates from the roi_renamed table do not match with the uk_grouped table. 
-- Therefore I perform a left join and only keep the rows where the uk_grouped table returns a null value.
-- This ensures that I only have non-matching rows left. 
-- Then I want to see what the first uk_report_date is for each non-matching roi_reporting_date.
-- I use the ASOF join. This allows me to only keep the closest match on therefore the next reporting date.

,roi_not_matched AS (
    SELECT 
        roi_reporting_month
        ,roi_new_customers
        ,MIN(uk2.uk_reporting_date) AS roi_reporting_date
    FROM
        roi_renamed AS roi
    LEFT JOIN
        uk_grouped AS uk
        ON roi.roi_reporting_date = uk.uk_reporting_date
    ASOF JOIN
        uk_grouped AS uk2
        MATCH_CONDITION (roi.roi_reporting_date < uk2.uk_reporting_date)
    WHERE
        uk.uk_reporting_date IS NULL
    GROUP BY
        roi_reporting_month
        ,roi_new_customers
        ,roi_reporting_date        
)

-- SELECT * FROM roi_not_matched; 

-- Now I group the table with non-matching dates in case there are multiple rows with the same reporting_date.

,roi_not_matched_grouped AS (
    SELECT
         roi_reporting_month
        ,SUM(roi_new_customers) AS roi_new_customers
        ,roi_reporting_date
    FROM
        roi_not_matched
    GROUP BY
        roi_reporting_month
        ,roi_reporting_date
)   

-- SELECT * FROM roi_not_matched_grouped;

-- Now I can union both the non-matching as matching roi records.

,roi_combined AS (
    SELECT 
        roi_reporting_month
        ,roi_new_customers
        ,roi_reporting_date
    FROM 
        roi_not_matched_grouped
    
    UNION ALL 
    
    SELECT 
        roi_reporting_month
        ,roi_new_customers
        ,roi_reporting_date
    FROM 
        roi_renamed AS roi
    INNER JOIN 
        uk_grouped AS uk
        ON uk.UK_reporting_date = roi.roi_reporting_date
)

-- SELECT * FROM roi_combined;

-- Once again I group all records as it could be that there are duplicates in terms of reporting_date.

,roi_final_grouped AS (
    SELECT 
        roi_reporting_month
        ,SUM(roi_new_customers) AS roi_new_customers
        ,roi_reporting_date
    FROM
        roi_combined
    GROUP BY
        roi_reporting_month
        ,roi_reporting_date
)

-- SELECT * FROM roi_final_grouped;

-- Now the roi has only records that match with the uk_grouped table its time to join both the tables.
-- I also calculate the reporting_month for the uk_reportin_date.
-- The last reporting_date of the month actually belongs to the next reporting_month.
-- So I use a MAX() window function to see for each record whether the uk_reporting_date of that record is the same as the max uk_reporting_date. 
-- If that is the case I add a month to the uk_reporting_date and format it as Mon-YY. If not I just format it as Mon-YY.
-- Finally I check whether the uk reporting_month is the same as the roi_reporting_month. If not the column misalignment flag populates an 'X'

,uk_roi_joined AS (
        SELECT   
            CASE 
                WHEN MAX(uk_reporting_date) OVER(
                                                PARTITION BY EXTRACT(YEAR FROM uk_reporting_date)
                                                             ,EXTRACT(MONTH FROM uk_reporting_date) 
                                                ORDER BY uk_reporting_date 
                                                ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
                                                ) = uk_reporting_date 
                THEN TO_CHAR(dateadd(month, 1, uk_reporting_date), 'Mon-YY')
                ELSE TO_CHAR(uk_reporting_date, 'MON-YY')
            END AS reporting_month
        ,CASE
            WHEN roi_reporting_month != reporting_month THEN 'x'
            WHEN roi_reporting_month IS NULL THEN 'x'
        END AS misalignment_flag
        ,uk_reporting_date AS reporting_date
        ,uk_new_customers
        ,roi_new_customers
        ,roi_reporting_month
    FROM 
        uk_grouped AS uk 
    LEFT JOIN 
        roi_final_grouped AS roi 
        ON uk.uk_reporting_date = roi.roi_reporting_date
    ORDER BY 
        uk_reporting_date
)

-- SELECT * FROM uk_roi_joined;

-- Lastly I add a reporting_day number to the table and the challenge is finished!

SELECT 
    reporting_month
    ,ROW_NUMBER() OVER (PARTITION BY reporting_month
                        ORDER BY reporting_date
                       ) AS reporting_day
    ,reporting_date as dates
    ,uk_new_customers
    ,roi_new_customers
    ,roi_reporting_month
    ,misalignment_flag
FROM
    uk_roi_joined
ORDER BY
    dates;