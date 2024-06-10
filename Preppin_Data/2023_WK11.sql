/*

Preppin' Data 2023 WK11

Data Source Bank want some quick and dirty analysis. 
They know where their customers are, they know where their branches are. 
But they don't know which customers are closest to which branches. 
Which customers should they be prioritising based on proximity to their branches?

Requirements:

Transform the latitude and longitudes from decimal degrees to radians by dividing them by 180/pi
The distance (in miles) can then be calculated as:  3963 * acos((sin(lat1) * sin(lat2)) + cos(lat1) * cos(lat2) * cos(long2 – long1))
Append the Branch information to the Customer information
Transform the latitude and longitude into radians
Find the closest Branch for each Customer
    Make sure Distance is rounded to 2 decimal places
For each Branch, assign a Customer Priority rating, the closest customer having a rating of 1

*/

--First I add all branches with its lats and longs to each customer. 
--Then I can calculate the distance from each branche to each customer.

WITH distance AS (

    SELECT 
        customer
        ,address_long / (180 / pi()) AS address_long_rad
        ,address_lat / (180 / pi()) AS address_lat_rad
        ,branch 
        ,branch_lat / (180 / pi()) AS branch_lat_rad
        ,branch_long / (180 / pi()) AS branch_long_rad
        ,ROUND(
            3963 * acos((sin(address_lat_rad) * sin(branch_lat_rad)) + cos(address_lat_rad) * 
            cos(branch_lat_rad) * cos(branch_long_rad - address_long_rad))
            , 2) AS distance
    FROM 
        wk11_customer_locations as cl 
    CROSS JOIN 
        wk11_branches AS b
),

--Then its time to find out which branch is closest to each customer. 
--I use qualify to use a window function as a filter on the dataset.
--I'm sorting each customer based on the distance, shortest first. 
--To do it for each customer I use PARTITION BY.

closest_branch AS (
    SELECT 
        customer
        ,branch
        ,distance
    FROM
        distance
    QUALIFY 
        ROW_NUMBER() OVER (
            PARTITION BY customer
            ORDER BY distance
        ) = 1
)

--Now I have for each customer the branch that is closest by.
--I want to order the customers for each branche on priority, closest customers having the highest priority.
--I again use ROW_NUMBER() but this time the data is PARTITIONed BY the branch.

SELECT 
    branch
    ,customer
    ,distance
    ,ROW_NUMBER () OVER (
        PARTITION BY branch
        ORDER BY distance
        ) AS customer_priority
FROM
    closest_branch;