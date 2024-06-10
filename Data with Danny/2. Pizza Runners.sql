-- clean runner_orders table

ALTER TABLE RUNNER_ORDERS ADD COLUMN date_temp DATE;

UPDATE RUNNER_ORDERS SET date_temp = 
  CASE
    WHEN pickup_time = 'null' THEN null
    ELSE TO_DATE(pickup_time)
  END;
  
ALTER TABLE RUNNER_ORDERS DROP COLUMN pickup_time;

ALTER TABLE RUNNER_ORDERS RENAME COLUMN date_temp to pickup_time;

UPDATE RUNNER_ORDERS SET distance = 
  CASE
    WHEN distance = 'null' THEN null
    ELSE distance
  END;

UPDATE RUNNER_ORDERS SET duration = 
  CASE
    WHEN duration = 'null' THEN null
    ELSE duration
  END;

UPDATE RUNNER_ORDERS SET cancellation = 
  CASE
    WHEN cancellation = 'null' THEN null
    WHEN LENGTH(cancellation) = 0 THEN null
    ELSE cancellation
  END;

-- clean customer_orders table

UPDATE customer_orders SET exclusions = 
  CASE
    WHEN exclusions = 'null' THEN null
    WHEN LENGTH(exclusions) = 0 THEN null
    ELSE exclusions
  END;

UPDATE customer_orders SET extras = 
  CASE
    WHEN extras = 'null' THEN null
    WHEN LENGTH(extras) = 0 THEN null
    ELSE extras
  END;

---------------------------------------------------------------------------
-- A. Pizza Metrics

-- 1. How many pizzas were ordered?

SELECT
  COUNT(*) AS pizzas_ordered
FROM
  customer_orders;

-- 2. How many unique customer orders were made?

SELECT
  COUNT(DISTINCT (order_id)) AS number_of_orders
FROM
  customer_orders;

-- 3. How many successful orders were delivered by each runner?

-- LH: a delivery is succesful when 'cancellation is NULL'

SELECT
  runner_id,
  COUNT(*)
FROM
  runner_orders
WHERE
  cancellation IS NULL
GROUP BY
  runner_id;

-- 4. How many of each type of pizza was delivered?

SELECT
  co.pizza_id,
  COUNT(*) AS nr_delivered
FROM
  runner_orders AS ro
JOIN customer_orders AS co 
  ON co.order_id = ro.order_id
WHERE
  ro.cancellation IS NULL
GROUP BY
  co.pizza_id;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?

SELECT
  co.customer_id,
  pn.pizza_name,
  COUNT(*) AS nr_delivered
FROM
  runner_orders AS ro
JOIN customer_orders AS co 
  ON co.order_id = ro.order_id
JOIN pizza_names AS pn 
  ON co.pizza_id = pn.pizza_id
WHERE
  ro.cancellation IS NULL
GROUP BY
  co.customer_id,
  pn.pizza_name;

-- 6. What was the maximum number of pizzas delivered in a single order?

SELECT
  order_id,
  COUNT(*) AS pizzas_ordered
FROM
  customer_orders
GROUP BY
  order_id
ORDER BY
  pizzas_ordered DESC
LIMIT 1;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

-- LH: use CASE to determine whether a record has changes.

SELECT
  co.customer_id,
  SUM(
    CASE
      WHEN extras IS NOT NULL 
      THEN 1
      ELSE 0
    END
  ) AS changed,
  SUM(
    CASE
      WHEN extras IS NULL
      THEN 1
      ELSE 0
    END
  ) AS not_changed
FROM
  customer_orders AS co
JOIN runner_orders AS ro 
  ON co.order_id = ro.order_id
WHERE
  ro.cancellation IS NULL
GROUP BY
  co.customer_id;

-- 8. How many pizzas were delivered that had both exclusions and extras?

-- LH: expand on the earlier used CASE statement

SELECT
  SUM(
    CASE
      WHEN exclusions IS NOT NULL
      AND extras IS NOT NULL THEN 1
      ELSE 0
    END
  ) AS exclusions_and_extras
FROM
  customer_orders AS co
JOIN runner_orders AS ro 
  ON co.order_id = ro.order_id
WHERE
  ro.cancellation IS NULL;

-- 9. What was the total volume of pizzas ordered for each hour of the day?

-- LH: use HOUR function to retrieve hour of the day and group by this value as well.

SELECT
  HOUR(order_time) AS hour,
  COUNT(*) AS pizzas_ordered
FROM
  customer_orders
GROUP BY
  hour
ORDER BY
  hour;

-- 10. What was the volume of orders for each day of the week?

-- LH: similar, but with DAYOFWEEK and DAYNAME functions

SELECT
  DAYOFWEEK(order_time) AS dow,
  DAYNAME(order_time) AS day,
  COUNT(*) AS pizzas_ordered
FROM
  customer_orders
GROUP BY
  dow,
  day
ORDER BY
  dow;

---------------------------------------------------------------------------
-- B. Runner and Customer Experience

-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

-- LH: use DATE_TRUNC to go to beginning of week and add 4 to make sure 2021-01-01 is recognized as the actual beginning of the week.

SELECT
  DATE_TRUNC('week', registration_date) + 4 AS start_of_week,
  COUNT(*) AS runner_signups
FROM
  runners
GROUP BY
  start_of_week;

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

SELECT
  runner_id,
  ROUND(AVG(TIMEDIFF(minute, order_time, pickup_time)), 2) AS avg_pick_up_time
FROM
  customer_orders AS co
JOIN runner_orders ro 
  ON co.order_id = ro.order_id
WHERE
  cancellation IS NULL
GROUP BY
  runner_id;

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

-- LH: avg_preparation_time goes up when the amount of pizzas to prepare increases, as is to be expected.
-- first calc a CTE where the amount of pizzas and preparation time per order is calculated. 
-- Use the results from this CTE table to calc avg preparation per group of number of pizzas in an order. 
    
WITH CTE AS (
    SELECT
      co.order_id,
      COUNT(*) AS pizzas_ordered,
      AVG(TIMEDIFF(minute, co.order_time, ro.pickup_time)) AS preparation_time
    FROM
      customer_orders AS co
    JOIN runner_orders AS ro 
      ON co.order_id = ro.order_id
    WHERE
      cancellation IS NULL
    GROUP BY
      co.order_id
)

SELECT
  pizzas_ordered,
  ROUND(AVG(preparation_time), 2) AS avg_preparation_time
FROM
  CTE
GROUP BY
  pizzas_ordered;

-- 4. What was the average distance travelled for each customer?

-- LH: First calculate the distance for each customer_id + order_id combination and store in a CTE.
-- Afterwards query the CTE and calculate the average distance.

WITH CTE AS (
    SELECT
      DISTINCT customer_id,
      co.order_id,
      REGEXP_REPLACE(distance, '[\\sa-z]', '') AS distance_cleaned
    FROM
      runner_orders AS ro
    LEFT JOIN customer_orders AS co 
      ON ro.order_id = co.order_id
)

SELECT
  customer_id,
  AVG(distance_cleaned) AS avg_distance_travelled
FROM
  CTE
GROUP BY
  customer_id;

-- 5. What was the difference between the longest and shortest delivery times for all orders?

-- LH: use REGEXP_REPLACE to replace word character or space in the duration field. Then do the calculations

WITH CTE AS (
    SELECT
      REGEXP_REPLACE(duration, '[\\sa-z]', '') AS duration_cleaned
    FROM
      runner_orders
    WHERE
      duration IS NOT NULL
)

SELECT
  MIN(duration_cleaned) AS shortest_delivery,
  MAX(duration_cleaned) AS longest_delivery,
  longest_delivery - shortest_delivery AS diff
FROM
  CTE;

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?

-- LH: realized you do not need to do a CTE as I did in last question to calc these things.

SELECT
  runner_id,
  order_id,
  REGEXP_REPLACE(duration, '[\\sa-z]', '') AS duration_cleaned,
  REGEXP_REPLACE(distance, '[\\sa-z]', '') AS distance_cleaned,
  ROUND(60 / duration_cleaned * distance_cleaned, 2) AS speed_in_kmh
FROM
  runner_orders
WHERE
  duration IS NOT NULL;

-- 7. What is the successful delivery percentage for each runner?

SELECT
  runner_id,
  COUNT(*) AS orders_received,
  COUNT(duration) AS orders_delivered,
  ROUND(orders_delivered / orders_received * 100, 2) || '%' AS succesful_delivery_percentage
FROM
  runner_orders
GROUP BY
  runner_id;
  
---------------------------------------------------------------------------
-- C. Ingredient Optimisation

-- 1. What are the standard ingredients for each pizza?

-- LH: use SPLIT_TO_TABLE to split the toppings into rows. Then join the topping names.

WITH 
  toppings_splitted AS (
SELECT 
  pizza_id, TRIM(VALUE) AS toppings
FROM 
  pizza_recipes, 
  LATERAL SPLIT_TO_TABLE(toppings, ',')
)

SELECT 
  pn.pizza_name, 
  pt.topping_name 
FROM 
  toppings_splitted AS ts
JOIN pizza_names AS pn
  ON ts.pizza_id = pn.pizza_id
JOIN pizza_toppings AS pt
  ON ts.toppings = pt.topping_id
ORDER BY 
  ts.pizza_id;

-- 2. What was the most commonly added extra?

-- LH: use same technique to split the extras.

SELECT 
  pt.topping_name, 
  COUNT(*) AS times_ordered 
FROM 
  customer_orders, 
  LATERAL SPLIT_TO_TABLE(extras, ',') AS es
JOIN pizza_toppings AS pt
  ON TRIM(es.value) = pt.topping_id
WHERE 
  extras IS NOT NULL
GROUP BY 
  pt.topping_name
ORDER BY 
  times_ordered DESC
LIMIT 1;

-- 3. What was the most common exclusion?

SELECT 
  pt.topping_name, 
  COUNT(*) AS times_excluded 
FROM 
  customer_orders, 
LATERAL SPLIT_TO_TABLE(exclusions, ',') AS es
JOIN pizza_toppings AS pt 
  ON TRIM(es.value) = pt.topping_id
WHERE 
  exclusions IS NOT NULL
GROUP BY 
  pt.topping_name
ORDER BY 
  times_excluded DESC
LIMIT 1;

/*
   4. Generate an order item for each record in the customers_orders table in the format of one of the following:
      Meat Lovers
      Meat Lovers - Exclude Beef
      Meat Lovers - Extra Bacon
      Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
*/

-- LH: start by adding a pizza_number_within_order field as order_id + pizza_id is not an unique identifier for this table.

WITH customer_orders_expanded AS (
    SELECT 
      order_id, 
      customer_id, 
      pizza_id, 
      exclusions, 
      extras, 
      order_time, 
      ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY customer_id) AS pizza_number_within_order 
    FROM 
      customer_orders
),

-- LH: create the extras CTE. First split the extras column and join the topping names. Then use LISTAGG to create a list again from the extra topping names.

extras AS (
    SELECT 
      coe.order_id, 
      coe.pizza_id, 
      coe.pizza_number_within_order, 
      LISTAGG(pt.topping_name, ', ') AS extras 
    FROM 
      customer_orders_expanded AS coe, 
    LATERAL SPLIT_TO_TABLE(extras, ',') AS es
    JOIN pizza_toppings AS pt
      ON TRIM(es.value) = pt.topping_id
    WHERE 
      extras IS NOT NULL
    GROUP BY 
      coe.order_id, 
      coe.pizza_id, 
      coe.pizza_number_within_order
),

-- LH: do the same for the exclusions.

exclusions AS (
    SELECT 
      coe.order_id, 
      coe.pizza_id, 
      coe.pizza_number_within_order, 
      LISTAGG(pt.topping_name, ', ') AS exclusions 
    FROM 
      customer_orders_expanded AS coe, 
    LATERAL SPLIT_TO_TABLE(exclusions, ',') AS es
    JOIN pizza_toppings AS pt 
      ON TRIM(es.value) = pt.topping_id
    WHERE 
      exclusions IS NOT NULL
    GROUP BY 
      coe.order_id, 
      coe.pizza_id, 
      coe.pizza_number_within_order
)

-- LH: Join both the extras and the exclusions CTEs to the firstly created customer_orders_expanded CTE. 
-- Now the added field pizza_number_within_order can be used to avoid creating duplicates with the join 
-- (if you would join to the normal customer_orders table you would get an "Extra Cheese, Cheese" as result which is in fact two separate pizza's with both Cheese as an extra)
-- Then use a CASE statement to recognize whether or not the word 'Exclude'/'Extra' must be used in the end result.

SELECT 
  coe.order_id, 
  coe.customer_id, 
  pn.pizza_name, 
  CASE 
    WHEN exc.exclusions IS NULL AND ext.extras IS NULL 
    THEN pn.pizza_name 
    WHEN ext.extras IS NULL 
    THEN pn.pizza_name || ' - Exclude ' || exc.exclusions 
    WHEN exc.exclusions IS NULL 
    THEN pn.pizza_name || ' - Extra ' || ext.extras 
    ELSE pn.pizza_name || ' - Exclude ' || exc.exclusions  || ' - Extra ' || ext.extras 
  END AS concat
FROM 
  customer_orders_expanded AS coe
LEFT JOIN extras AS ext
   ON coe.order_id = ext.order_id 
  AND coe.pizza_number_within_order = ext.pizza_number_within_order
LEFT JOIN exclusions AS exc
   ON coe.order_id = exc.order_id 
  AND coe.pizza_number_within_order = exc.pizza_number_within_order
LEFT JOIN pizza_names AS pn 
   ON coe.pizza_id = pn.pizza_id
ORDER BY 
  coe.order_id, 
  coe.pizza_number_within_order;


/*
    5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders 
       table and add a 2x in front of any relevant ingredients
       For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"    
*/

-- LH: start again by creating the customer_orders_expanded.

WITH customer_orders_expanded AS (
    SELECT 
      order_id, 
      customer_id, 
      pizza_id, 
      exclusions, 
      extras, 
      order_time, 
      ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY customer_id) AS pizza_number_within_order 
    FROM 
      customer_orders
),

-- LH: generate a table with all the toppings that are regularly on the pizzas.

regular_toppings AS (
    SELECT
      pr.pizza_id,
      pt.topping_name 
    FROM 
      pizza_recipes AS pr, 
    LATERAL SPLIT_TO_TABLE(pr.toppings, ', ') AS es
    JOIN pizza_toppings AS pt
      ON es.value = pt.topping_id
    ORDER BY 
      pr.pizza_id,
      pt.topping_name
),

-- LH: join the previous CTE to customer_orders_expaned to get a table with all regular toppings ordered. Add a column 'count' with value 1 to sum later on.

regular_toppings_ordered AS (
    SELECT 
      coe.order_id,
      coe.customer_id,
      coe.pizza_id,
      coe.pizza_number_within_order,
      rt.topping_name,
      'regular' AS type,
      1 AS count

    FROM customer_orders_expanded AS coe
    JOIN regular_toppings AS rt
      ON coe.pizza_id = rt.pizza_id
),

-- LH: create a table with all extras ordered. Again add a value of 1 for each row to sum later on.

extras AS (
    SELECT 
      coe.order_id, 
      coe.customer_id,
      coe.pizza_id, 
      coe.pizza_number_within_order, 
      pt.topping_name,
      'extras' AS type,
      1 AS count
    FROM 
      customer_orders_expanded AS coe, 
    LATERAL SPLIT_TO_TABLE(extras, ',') AS es
    JOIN pizza_toppings AS pt
      ON TRIM(es.value) = pt.topping_id
    WHERE 
      extras IS NOT NULL
),

-- LH: create a table with all exclusions within the pizza orders. Now add a value of -1 as we want these deducted from the total toppings ordered.

exclusions AS (
    SELECT 
      coe.order_id, 
      coe.customer_id,
      coe.pizza_id, 
      coe.pizza_number_within_order, 
      pt.topping_name,
      'exclusions' AS type,
      -1 AS count
    FROM 
      customer_orders_expanded AS coe, 
    LATERAL SPLIT_TO_TABLE(exclusions, ',') AS es
    JOIN pizza_toppings AS pt 
      ON TRIM(es.value) = pt.topping_id
    WHERE 
      exclusions IS NOT NULL
),

-- LH: Union all three CTES

toppings_ordered AS (
    SELECT * FROM regular_toppings_ordered
    UNION ALL 
    SELECT * FROM extras
    UNION ALL 
    SELECT * FROM exclusions
),

-- LH: sum the field count and remove all records where the sum = 0

toppings_summed AS (
    SELECT 
      order_id,
      customer_id,
      pizza_id,
      pizza_number_within_order,
      topping_name, 
      SUM(count) AS topping_amount
    FROM
      toppings_ordered
    GROUP BY 
      order_id,
      customer_id,
      pizza_id,
      pizza_number_within_order,
      topping_name
    HAVING 
      topping_amount != 0
)

-- LH: create a list of topping names per pizza_within_order by using LISTAGG. 
-- Within LISTAGG use CASE to make sure to add a multiplier sign in case the value is bigger than 1.
-- use the WITHIN GROUP (ORDER BY) to make sure the ingredients are ordered alfabetically.


SELECT 
  order_id, 
  customer_id, 
  pizza_id, 
  pizza_number_within_order, 
  LISTAGG( CASE 
             WHEN topping_amount > 1 
             THEN topping_amount || 'x ' || topping_name 
             ELSE topping_name 
           END, ', ') 
  WITHIN GROUP (ORDER BY topping_name) AS ingredient_list
FROM 
  toppings_summed
GROUP BY 
  order_id, 
  customer_id, 
  pizza_id, 
  pizza_number_within_order;

-- 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

-- LH: very similar beginning as the previous question. Only now do not group per order pizza_within_order_number but sum all ingredients over all delivered pizzas.

WITH customer_orders_expanded AS (
    SELECT 
      order_id, 
      customer_id, 
      pizza_id, 
      exclusions, 
      extras, 
      order_time, 
      ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY customer_id) AS pizza_number_within_order 
    FROM 
      customer_orders
),

regular_toppings AS (
    SELECT
      pr.pizza_id,
      pt.topping_name 
    FROM 
      pizza_recipes AS pr, 
    LATERAL SPLIT_TO_TABLE(pr.toppings, ', ') AS es
    JOIN pizza_toppings AS pt
      ON es.value = pt.topping_id
    ORDER BY 
      pr.pizza_id,
      pt.topping_name
),

regular_toppings_ordered AS (
    SELECT 
      coe.order_id,
      coe.customer_id,
      coe.pizza_id,
      coe.pizza_number_within_order,
      rt.topping_name,
      'regular' AS type,
      1 AS count

    FROM customer_orders_expanded AS coe
    JOIN regular_toppings AS rt
      ON coe.pizza_id = rt.pizza_id
),

extras AS (
    SELECT 
      coe.order_id, 
      coe.customer_id,
      coe.pizza_id, 
      coe.pizza_number_within_order, 
      pt.topping_name,
      'extras' AS type,
      1 AS count
    FROM 
      customer_orders_expanded AS coe, 
    LATERAL SPLIT_TO_TABLE(extras, ',') AS es
    JOIN pizza_toppings AS pt
      ON TRIM(es.value) = pt.topping_id
    WHERE 
      extras IS NOT NULL
),

exclusions AS (
    SELECT 
      coe.order_id, 
      coe.customer_id,
      coe.pizza_id, 
      coe.pizza_number_within_order, 
      pt.topping_name,
      'exclusions' AS type,
      -1 AS count
    FROM 
      customer_orders_expanded AS coe, 
    LATERAL SPLIT_TO_TABLE(exclusions, ',') AS es
    JOIN pizza_toppings AS pt 
      ON TRIM(es.value) = pt.topping_id
    WHERE 
      exclusions IS NOT NULL
),

toppings_ordered AS (
    SELECT * FROM regular_toppings_ordered
    UNION ALL 
    SELECT * FROM extras
    UNION ALL 
    SELECT * FROM exclusions
),

toppings_summed AS (
    SELECT 
      order_id,
      customer_id,
      pizza_id,
      pizza_number_within_order,
      topping_name, 
      SUM(count) AS topping_amount
    FROM
      toppings_ordered
    GROUP BY 
      order_id,
      customer_id,
      pizza_id,
      pizza_number_within_order,
      topping_name
    HAVING 
      topping_amount != 0
)

-- LH: sum all topping amounts and group per topping name

SELECT
  ts.topping_name,
  SUM(ts.topping_amount) AS topping_amount FROM 
  toppings_summed AS ts
JOIN pizza_names AS pn
  ON ts.pizza_id = pn.pizza_id
LEFT JOIN runner_orders AS ro
  ON ts.order_id = ro.order_id
WHERE 
  ro.cancellation IS NULL
GROUP BY 
  ts.topping_name
ORDER BY 
  topping_amount DESC;

---------------------------------------------------------------------------
-- D. Pricing and Ratings

-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?

-- LH: use CASE to add cost to each pizza name and sum.

SELECT 
  SUM(
    CASE 
      WHEN pn.pizza_name = 'Meatlovers' 
      THEN 12 
      WHEN pn.pizza_name = 'Vegetarian' 
      THEN 10 
      ELSE 'Error' 
    END
  )::int AS revenue
FROM 
  customer_orders AS co
JOIN runner_orders AS ro
  ON co.order_id = ro.order_id
JOIN pizza_names AS pn
  ON co.pizza_id = pn.pizza_id
WHERE 
  ro.cancellation IS NULL; 

-- 2. What if there was an additional $1 charge for any pizza extras?

-- LH: add customer_orders_expanded to identify unique pizzas within orders.

WITH customer_orders_expanded AS (
    SELECT 
      order_id, 
      customer_id, 
      pizza_id, 
      exclusions, 
      extras, 
      order_time, 
      ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY customer_id) AS pizza_number_within_order 
    FROM 
      customer_orders
),

-- LH: get the number of extras for each pizza.

extras AS (
    SELECT 
      coe.order_id, 
      coe.customer_id,
      coe.pizza_number_within_order, 
      count(*) nr_of_extras
    FROM 
      customer_orders_expanded AS coe, 
    LATERAL SPLIT_TO_TABLE(extras, ',') AS es
    JOIN pizza_toppings AS pt
      ON TRIM(es.value) = pt.topping_id
    WHERE 
      extras IS NOT NULL
    GROUP BY 
      coe.order_id, 
      coe.customer_id,
      coe.pizza_number_within_order
)

-- LH: identify the pizza name to add the related cost and sum the number of extras to get the revenue related to extras.

SELECT 
  SUM(
    CASE 
      WHEN pn.pizza_name = 'Meatlovers' 
      THEN 12 
      WHEN pn.pizza_name = 'Vegetarian' 
      THEN 10 
      ELSE 'Error' 
      END
  )::int AS pizza_revenue,
  SUM(nr_of_extras * 1) AS extras_revenue,
  pizza_revenue + extras_revenue AS total_revenue
FROM 
  customer_orders_expanded as coe
LEFT JOIN extras AS ex
  ON coe.order_id = ex.order_id 
  AND coe.pizza_number_within_order = ex.pizza_number_within_order
JOIN pizza_names AS pn
  ON coe.pizza_id = pn.pizza_id
JOIN runner_orders AS ro
  ON coe.order_id = ro.order_id
WHERE ro.cancellation IS NULL;

-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.

-- LH: create table that can hold the order_id and the rating given

DROP TABLE IF EXISTS ratings; 
CREATE TABLE ratings 
(
    order_id INT,
    rating INT
);

INSERT INTO ratings (order_id, rating)
VALUES 
  (1,2),
  (2,1),
  (3,4),
  (4,3),
  (5,5),
  (7,2),
  (8,4),
  (10,1);

/*
   4. Using your newly generated table - can you join all of the information together to form a table which has the   
      following information for successful deliveries?
        customer_id
        order_id
        runner_id
        rating
        order_time
        pickup_time
        Time between order and pickup
        Delivery duration
        Average speed
        Total number of pizzas
*/

-- LH: calc the number of pizza's per order

WITH customer_orders_aggregated AS (
    SELECT 
      order_id, 
      customer_id, 
      order_time, 
      count(*) AS total_number_of_pizzas 
    FROM 
      customer_orders
    GROUP BY 
      order_id, 
      customer_id, 
      order_time
)

-- LH join the customer_orders_aggregated table to the runner_orders table and do some time-math.

SELECT 
  coa.customer_id,
  ro.order_id, 
  ro.runner_id, 
  r.rating,
  TIME(coa.order_time) AS order_time,
  TIME(ro.pickup_time) AS pickup_time,
  TIMEDIFF(minute, order_time, pickup_time) AS time_between_order_and_pickup,
  REGEXP_REPLACE(duration, '[\\sa-z]', '') AS delivery_duration,
  ROUND(60 / delivery_duration * REGEXP_REPLACE(distance, '[\\sa-z]', ''), 2) AS speed_in_kmh,
  coa.total_number_of_pizzas
FROM 
  runner_orders AS ro
JOIN ratings AS r
  ON ro.runner_id = r.order_id
LEFT JOIN customer_orders_aggregated AS coa
  ON ro.order_id = coa.order_id
WHERE 
  cancellation IS NULL;
    
-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid
--    $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?    

-- LH: first calc the revenue per customer order.

WITH customer_order_revenue AS (
    SELECT 
      order_id, 
      SUM(
        CASE 
          WHEN pn.pizza_name = 'Meatlovers' 
          THEN 12 
          WHEN pn.pizza_name = 'Vegetarian' 
          THEN 10 
          ELSE 'Error' 
        END):: INT AS order_revenue 
    FROM 
      customer_orders AS co
    JOIN pizza_names AS pn
      ON co.pizza_id = pn.pizza_id
    GROUP BY 
      order_id)

-- LH: Join to the succesful deliveries by the runners and calc the runner_costs and profit
  
SELECT 
  SUM(cor.order_revenue) AS revenue,
  SUM(REGEXP_REPLACE(distance, '[\\sa-z]', '') * 0.30) AS runner_costs,
  SUM(cor.order_revenue) - runner_costs AS profit
FROM
  runner_orders AS ro
LEFT JOIN customer_order_revenue AS cor
  ON ro.order_id = cor.order_id
WHERE 
  ro.cancellation IS NULL; 

