-- WK6

/*
Requirements

Reshape the data so we have 5 rows for each customer, with responses for the Mobile App and Online Interface being in separate fields on the same row
Clean the question categories so they don't have the platform in from of them
    e.g. Mobile App - Ease of Use should be simply Ease of Use
Exclude the Overall Ratings, these were incorrectly calculated by the system
Calculate the Average Ratings for each platform for each customer 
Calculate the difference in Average Rating between Mobile App and Online Interface for each customer
Catergorise customers as being:
    Mobile App Superfans if the difference is greater than or equal to 2 in the Mobile App's favour
    Mobile App Fans if difference >= 1
    Online Interface Fan
    Online Interface Superfan
    Neutral if difference is between 0 and 1
Calculate the Percent of Total customers in each category, rounded to 1 decimal place
*/


-- first unpivot the data

WITH unpivoted_data AS (
    SELECT 
      customer_id
      ,category
      ,rating
    FROM 
      WK6
    UNPIVOT (RATING FOR CATEGORY IN (mobile_app_ease_of_use, 
                                     mobile_app_ease_of_access, 
                                     mobile_app_navigation, 
                                     mobile_app_likelihood_to_recommend, 
                                     mobile_app_overall_rating, 
                                     online_interface_ease_of_use, 
                                     online_interface_ease_of_access, 
                                     online_interface_navigation, 
                                     online_interface_likelihood_to_recommend, 
                                     online_interface_overall_rating
                                     )
            )
),

-- then adjust the names of the categories. I use POSITION() to test whether a certain part exists in the category column. If so I rename it.

unpivoted_data_exp AS (
    SELECT 
      customer_id
      ,LOWER(REPLACE(REGEXP_REPLACE(category, 'ONLINE_INTERFACE_|MOBILE_APP_', ''), '_', ' ')) AS category
      ,CASE 
         WHEN POSITION('MOBILE_APP', category) > 0 THEN 'mobile_app' 
         WHEN POSITION('ONLINE_INTERFACE', category) > 0 THEN 'online_interface'
       END AS type
      ,rating
    FROM 
      unpivoted_data
),

-- now pivot the data again so its structured with a column for mobile_app and a column for online_interface with its own ratings

pivoted_data AS (
    SELECT *
    FROM 
      unpivoted_data_exp
    PIVOT(SUM(rating) FOR type IN ('mobile_app', 'online_interface'))
    AS p (customer_id, category, mobile_app, online_interface)
    WHERE 
      category != 'overall rating'
),

-- calc the avgs for both mobile_app and online_interface and assign each record to a bucket.

pivoted_data_exp AS (
    SELECT 
      customer_id
      ,AVG(mobile_app) AS avg_mobile_app
      ,AVG(online_interface) AS avg_online_interface
      ,CASE
         WHEN avg_online_interface - avg_mobile_app >= 2 THEN 'Online Interface Superfan'
         WHEN avg_mobile_app - avg_online_interface >= 2 THEN 'Mobile App Superfan'
         WHEN avg_online_interface - avg_mobile_app >= 1 THEN 'Online Interface Fan'
         WHEN avg_mobile_app - avg_online_interface >= 1 THEN 'Mobile App Fan'
         ELSE 'Neutral'
       END AS customer_category
    FROM 
      pivoted_data 
    GROUP BY 
      customer_id
),

-- calc total customers to use for calculating percentages hereafter.

total_customers AS (
SELECT COUNT(*) AS customer_count FROM pivoted_data_exp 
)

-- calc the percentages per customer_category

SELECT 
  customer_category
  ,ROUND(COUNT(*) / AVG(customer_count) * 100, 2) AS percentage
FROM 
  pivoted_data_exp
JOIN total_customers
GROUP BY 
  customer_category;