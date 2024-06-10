-- A. Customer Journey
-- Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.
-- Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!

SELECT 
  customer_id, 
  start_date, 
  plan_name
FROM 
  subscriptions AS s
JOIN plans AS p
  ON s.plan_id = p.plan_id
WHERE 
  customer_id IN (1, 2, 11, 13, 15, 16, 18, 19);

-- customer 1 changed into a basic monthly plan after the trial and is still a customer.
-- customer 2 changed into a pro annual plan after the trial and is still a customer.
-- customer 11 decided to leave after the trial and is no longer a customer.
-- customer 13 changed into a basic monthly plan after the trial. After some months the customer upgraded to a pro monthly plan.
-- customer 15 changed into a pro monthly plan after the trial. After a little more than a month the customer decided to cancel. 
-- customer 16 changed into a basic monthly plan after the trial. After some months the customer upgraded to a pro monthly plan.
-- customer 18 changed into a basic monthly plan after the trial and is still a customer
-- customer 19 changed into a pro monthly plan after the trial. After some months the customer upgraded to a pro annual plan.

------------------------------------------------------------------------------------------------------------------------------------------

-- B. Data Analysis Questions

-- 1. How many customers has Foodie-Fi ever had?

-- LH: if a customer is someone who has had at least a trial:

SELECT
  COUNT(DISTINCT customer_id) AS nr_of_customers
FROM 
  subscriptions;

-- LH: if a customer is someone who has been a paying customer at some point in time:

SELECT 
  COUNT(DISTINCT s.customer_id) AS nr_of_customers
FROM 
  subscriptions AS s
JOIN plans AS p
  ON s.plan_id = p.plan_id
WHERE 
  p.plan_name NOT IN ('trial', 'churn');

-- 2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value

SELECT 
  date_trunc(month, start_date) AS month,
  COUNT(*) AS trials_started
FROM 
  subscriptions AS s
JOIN plans AS p
  ON s.plan_id = p.plan_id
WHERE 
  p.plan_name = 'trial'
GROUP BY 
  month
ORDER BY 
  month;

-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name

SELECT 
  p.plan_name,
  COUNT(*) AS count_of_events
FROM 
  subscriptions AS s
JOIN plans AS p
  ON s.plan_id = p.plan_id
WHERE 
  YEAR(start_date) > 2020
GROUP BY 
  p.plan_name
ORDER BY 
  count_of_events DESC;

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

-- LH: have a subquery in place to calc the total amount of customers. 
-- This must be done in a subquery as I want to filter the subscription table on plan_name = 'churned' to find the churned customers.

SELECT 
  (SELECT 
     COUNT(DISTINCT customer_id)
   FROM 
     subscriptions) AS total_customers, 
  COUNT(*) AS nr_of_churned_customers,
  ROUND(nr_of_churned_customers / total_customers * 100, 1) AS percentage_churned_customers
FROM subscriptions AS s
JOIN plans AS p
  ON s.plan_id = p.plan_id
WHERE plan_name = 'churn';

-- 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?

-- LH: First add a rownumber to the original subscriptions table so I can later find out whether or not a customer churned right after the trial expired (the row number will be 2 in that case)

WITH CTE AS (
    SELECT 
    *, 
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS rownumber
    FROM 
    subscriptions
)

-- LH: Do the calculations on the expanded subscriptions table. 

SELECT
  (SELECT
    COUNT(DISTINCT s.customer_id)
   FROM 
    subscriptions) AS total_customers,
  COUNT(*) as churned_after_trial,
  ROUND(churned_after_trial / total_customers * 100, 2) AS churned_after_trial_perc
FROM 
  CTE AS s
JOIN plans AS p
  ON s.plan_id = p.plan_id
WHERE 
  p.plan_name = 'churn' AND
  s.rownumber = 2;

-- 6. What is the number and percentage of customer plans after their initial free trial?

-- LH: using a subquery to calculate the total number of customers (necessary to calc the percentage)
-- Start by creating adding a row number to the original subscriptions table, so we can filter out the records that represent the plan that follows the trial.

WITH subscriptions_exp AS (
SELECT 
  *, 
  ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS rownumber
FROM 
  subscriptions
)

-- LH: group by on plan_name and perform the calculations

SELECT
  p.plan_name,
  COUNT(*) AS number_of_times_chosen_after_trial,
  ROUND(COUNT(*) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions_exp) * 100, 2) AS percentage_chosen_after_trial
FROM 
  subscriptions_exp AS s
JOIN plans AS p
  ON s.plan_id = p.plan_id
WHERE 
  rownumber = 2
GROUP BY 
  rownumber, 
  p.plan_name;

-- LH: try without subqueries. Need more CTES though.

-- LH: create the expanded subscriptions table again (with rownumber added)
  
WITH subscriptions_exp AS (
    SELECT 
      *, 
      ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS rownumber
    FROM 
      subscriptions
),

-- LH: create a CTE that holds the total amount of subscriptions (to calc the percentage later on)

total_customers AS (
    SELECT 
      COUNT(DISTINCT customer_id) AS total_subscriptions
    FROM 
      subscriptions
),

-- LH: group by plan_name and calc the counts per plan_name

aggregated AS(
    SELECT
      plan_name,
      COUNT(*) AS number_of_subscriptions
    FROM 
      subscriptions_exp AS s
    JOIN plans AS p
      ON s.plan_id = p.plan_id
    WHERE 
      rownumber = 2
    GROUP BY 
      plan_name)

-- LH: add the total_subscriptions to the aggregated CTE to calc the percentages
      
SELECT 
  plan_name,
  number_of_subscriptions,
  ROUND(number_of_subscriptions / total_subscriptions * 100, 2) AS percentage
FROM 
  aggregated
JOIN total_customers;


-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

-- LH: find out what the latest plan is for each customer, where records after 2020-12-31 are excluded

WITH latest_plan AS (
    SELECT 
      *, 
      LAST_VALUE(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS plan_id_at_31_12 
    FROM 
      subscriptions 
    WHERE 
      start_date <= '2020-12-31'
),

-- LH: since the last plan value for each customer is repeated for each customer in all lines it needs to be deduplicated

distinct_table AS (

    SELECT DISTINCT 
      customer_id,
      plan_id_at_31_12  
    FROM 
      latest_plan
)

-- LH: do a group by on plan_name to calc the number of subscription per plan_name

SELECT 
  p.plan_name, 
  COUNT(*)
FROM 
  distinct_table dt
JOIN plans AS p
  ON dt.plan_id_at_31_12 = p.plan_id
GROUP BY p.plan_name;
  
-- 8. How many customers have upgraded to an annual plan in 2020?

SELECT 
  COUNT(*) as upgrades_to_pro_annual
FROM 
  subscriptions AS s
JOIN plans AS p
  ON s.plan_id = p.plan_id
WHERE 
  p.plan_name = 'pro annual'
  AND YEAR(s.start_date) = 2020;

-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?

-- LH: by accident I found out that you can pivot a column and only keep values your interested in as headers. 
-- Therefore I pivot and keep only 0 (trial) and 3 (pro annual). The where clause filters out any pro_annual that doesnt have a start date (an indication that the customer is not a pro annual customer. After that that average datediff can be calculated)

SELECT 
   AVG(datediff(day, trial, pro_annual)) AS avg_days_between_upgrade_to_pro_annual
FROM 
  subscriptions AS s  
PIVOT(MIN(start_date) FOR plan_id IN (0, 3)) AS piv (customer_id, trial, pro_annual)
WHERE 
  pro_annual IS NOT NULL;
  
-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

-- LH: first create the same table as in the last but without the AVG calculation. 
-- Then use that CTE to bin the results and add the counts for each bin.

WITH CTE AS (
    SELECT 
      customer_id,
      datediff(day, trial, pro_annual) AS days_between_upgrade_to_pro_annual,
      WIDTH_BUCKET(days_between_upgrade_to_pro_annual, 1, 360, 12) AS bin_setup,
      CONCAT((bin_setup-1) * 30 + 1,' - ', bin_setup * 30, ' days') AS bin
    FROM 
      subscriptions AS s  
    PIVOT(MIN(start_date) FOR plan_id IN (0, 3)) AS piv (customer_id, trial, pro_annual)
    WHERE 
      pro_annual IS NOT NULL
    ORDER BY days_between_upgrade_to_pro_annual
)

SELECT 
  bin,
  ROUND(AVG(days_between_upgrade_to_pro_annual)) AS avg_in_days,
  COUNT(*) AS nr_of_customers
FROM 
  CTE
GROUP BY
  bin;


-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

SELECT 
  customer_id,
  LAG(plan_name, 1) OVER (PARTITION BY customer_id ORDER BY start_date) AS old_plan,
  plan_name AS new_plan
FROM 
  subscriptions AS s
JOIN plans AS p
  ON s.plan_id = p.plan_id
WHERE 
  YEAR(start_date) = '2020'
QUALIFY 
  old_plan = 'pro monthly'
  AND new_plan = 'basic monthly';

--------------------------------------------------------------------------------------------------------------------

-- C. Challenge Payment Question

/* The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:

        monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
        upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
        upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
        once a customer churns they will no longer make payments

        Example outputs for this table might look like the following:

        customer_id	plan_id	plan_name	payment_date	amount	payment_order
        1	        1	basic monthly	2020-08-08	    9.90	1
        1	        1	basic monthly	2020-09-08	    9.90	2
        1	        1	basic monthly	2020-10-08	    9.90	3
        1	        1	basic monthly	2020-11-08	    9.90	4
        1	        1	basic monthly	2020-12-08	    9.90	5
        2	        3	pro annual	    2020-09-27	    199.00	1
        13	        1	basic monthly	2020-12-22	    9.90	1
        15	        2	pro monthly	    2020-03-24	    19.90	1
        15	        2	pro monthly	    2020-04-24	    19.90	2
        16	        1	basic monthly	2020-06-07	    9.90	1
        16	        1	basic monthly	2020-07-07	    9.90	2
        16        	1	basic monthly	2020-08-07	    9.90	3
        16        	1	basic monthly	2020-09-07	    9.90	4
        16	        1	basic monthly	2020-10-07	    9.90	5
        16	        3	pro annual	    2020-10-21	    189.10	6
        18	        2	pro monthly	    2020-07-13	    19.90	1
        18	        2	pro monthly	    2020-08-13	    19.90	2
        18	        2	pro monthly	    2020-09-13	    19.90	3
        18	        2	pro monthly	    2020-10-13	    19.90	4
        18	        2	pro monthly	    2020-11-13	    19.90	5
        18	        2	pro monthly	    2020-12-13	    19.90	6
        19	        2	pro monthly	    2020-06-29	    19.90	1
        19	        2	pro monthly	    2020-07-29	    19.90	2
        19	        3	pro annual	    2020-08-29	    199.00	3

*/

------------------------------------------------------------------------------------------------------------------------------------------

-- D. Outside The Box Questions
-- The following are open ended questions which might be asked during a technical interview for this case study - there are no right or wrong answers, but answers that make sense from both a technical and a business perspective make an amazing impression!

-- 1. How would you calculate the rate of growth for Foodie-Fi?
-- 2. What key metrics would you recommend Foodie-Fi management to track over time to assess performance of their overall business?
-- 3. What are some key customer journeys or experiences that you would analyse further to improve customer retention?
-- 4. If the Foodie-Fi team were to create an exit survey shown to customers who wish to cancel their subscription, what questions would you include in the survey?
-- 5. What business levers could the Foodie-Fi team use to reduce the customer churn rate? How would you validate the effectiveness of your ideas?
