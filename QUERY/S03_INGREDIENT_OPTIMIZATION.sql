-- SECTION C : INGREDIENT OPTIMIZATION
;

-- 01 WHAT ARE THE STANDARD INGREDIENTS FOR EACH PIZZA?
-- COMMON INGREDIENTS
SELECT
    PR.PIZZA_ID,
    PR.TOPPINGS,
    PR.PIZZA_ID AS SEQ,
    ROW_NUMBER() OVER (PARTITION BY PR.PIZZA_ID) AS 'INDEX',
    T.TOPPING AS VALUE
FROM
    PIZZA_RECIPES PR,
    JSON_TABLE(
        CONCAT('["', REPLACE(PR.TOPPINGS, ', ', '","'), '"]'),
        '$[*]' COLUMNS (TOPPING VARCHAR(255) PATH '$')
    ) AS T;

--
SELECT
    PR.PIZZA_ID,
    T.TOPPING AS TOPPING_ID
FROM
    PIZZA_RECIPES PR,
    JSON_TABLE(
        CONCAT('["', REPLACE(PR.TOPPINGS, ', ', '","'), '"]'),
        '$[*]' COLUMNS (TOPPING VARCHAR(255) PATH '$')
    ) AS T;

-- 
WITH CTE AS (
    SELECT
        PR.PIZZA_ID,
        T.TOPPING AS TOPPING_ID
    FROM
        PIZZA_RECIPES PR,
        JSON_TABLE(
            CONCAT('["', REPLACE(PR.TOPPINGS, ', ', '","'), '"]'),
            '$[*]' COLUMNS (TOPPING VARCHAR(255) PATH '$')
        ) AS T
)
SELECT
    CTE.PIZZA_ID,
    PT.TOPPING_NAME
FROM
    CTE
    INNER JOIN PIZZA_TOPPINGS AS PT ON PT.TOPPING_ID = CTE.TOPPING_ID;

-- 
WITH CTE AS (
    SELECT
        PR.PIZZA_ID,
        T.TOPPING AS TOPPING_ID
    FROM
        PIZZA_RECIPES PR,
        JSON_TABLE(
            CONCAT('["', REPLACE(PR.TOPPINGS, ', ', '","'), '"]'),
            '$[*]' COLUMNS (TOPPING VARCHAR(255) PATH '$')
        ) AS T
)
SELECT
    PT.TOPPING_NAME,
    COUNT(DISTINCT CTE.PIZZA_ID) AS CNT_ING
FROM
    CTE
    INNER JOIN PIZZA_TOPPINGS AS PT ON PT.TOPPING_ID = CTE.TOPPING_ID
GROUP BY
    PT.TOPPING_NAME
HAVING
    CNT_ING = 2;

-- 02 WHAT WAS THE MOST COMMONLY ADDED EXTRA?
SELECT
    E.TOPPING,
    COUNT(CO.PIZZA_ID) AS 'PIZZA_ID'
FROM
    CUSTOMER_ORDERS AS CO,
    JSON_TABLE(
        CONCAT('["', REPLACE(CO.EXTRAS, ', ', '","'), '"]'),
        '$[*]' COLUMNS (TOPPING VARCHAR(255) PATH '$')
    ) AS E
WHERE
    LENGTH(EXTRAS) > 0
    AND EXTRAS IS NOT NULL
    AND EXTRAS <> 'NULL'
GROUP BY
    E.TOPPING;

--
WITH CTE AS(
    SELECT
        E.TOPPING,
        COUNT(CO.PIZZA_ID) AS 'PIZZA_ID'
    FROM
        CUSTOMER_ORDERS AS CO,
        JSON_TABLE(
            CONCAT('["', REPLACE(CO.EXTRAS, ', ', '","'), '"]'),
            '$[*]' COLUMNS (TOPPING VARCHAR(255) PATH '$')
        ) AS E
    WHERE
        LENGTH(EXTRAS) > 0
        AND EXTRAS IS NOT NULL
        AND EXTRAS <> 'NULL'
    GROUP BY
        E.TOPPING
)
SELECT
    PT.TOPPING_NAME
FROM
    CTE
    INNER JOIN PIZZA_TOPPINGS AS PT ON PT.TOPPING_ID = TOPPING
LIMIT
    1;

-- 03 WHAT WAS THE MOST COMMON EXCLUSION?
WITH CTE AS(
    SELECT
        E.TOPPING,
        COUNT(CO.PIZZA_ID) AS 'PIZZA_ID'
    FROM
        CUSTOMER_ORDERS AS CO,
        JSON_TABLE(
            CONCAT('["', REPLACE(CO.EXCLUSIONS, ', ', '","'), '"]'),
            '$[*]' COLUMNS (TOPPING VARCHAR(255) PATH '$')
        ) AS E
    WHERE
        LENGTH(EXTRAS) > 0
        AND EXTRAS IS NOT NULL
        AND EXTRAS <> 'NULL'
    GROUP BY
        E.TOPPING
)
SELECT
    PT.TOPPING_NAME
FROM
    CTE
    INNER JOIN PIZZA_TOPPINGS AS PT ON PT.TOPPING_ID = TOPPING
LIMIT
    1;

-- 04 GENERATE AN ORDER ITEM FOR EACH RECORD IN THE CUSTOMERS_ORDERS TABLE IN THE FORMAT OF ONE OF THE FOLLOWING:
-- - MEAT LOVERS
-- - MEAT LOVERS - EXCLUDE BEEF
-- - MEAT LOVERS - EXTRA BACON
-- - MEAT LOVERS - EXCLUDE CHEESE, BACON - EXTRA MUSHROOM, PEPPERS
;

WITH EXTRAS AS (
    SELECT
        CO.ORDER_ID,
        CO.PIZZA_ID,
        CO.EXTRAS,
        GROUP_CONCAT(
            DISTINCT PT.TOPPING_NAME
            ORDER BY
                PT.TOPPING_NAME ASC SEPARATOR ', '
        ) AS ADDED_EXTRAS
    FROM
        CUSTOMER_ORDERS AS CO,
        JSON_TABLE(
            CONCAT('["', REPLACE(CO.EXTRAS, ', ', '","'), '"]'),
            '$[*]' COLUMNS (TOPPING VARCHAR(255) PATH '$')
        ) AS S
        INNER JOIN PIZZA_TOPPINGS AS PT ON PT.TOPPING_ID = S.TOPPING
    WHERE
        LENGTH(S.TOPPING) > 0
        AND S.TOPPING IS NOT NULL
        AND S.TOPPING <> 'NULL'
    GROUP BY
        CO.ORDER_ID,
        CO.PIZZA_ID,
        CO.EXTRAS
),
EXCLUSIONS AS (
    SELECT
        CO.ORDER_ID,
        CO.PIZZA_ID,
        CO.EXCLUSIONS,
        GROUP_CONCAT(
            DISTINCT PT.TOPPING_NAME
            ORDER BY
                PT.TOPPING_NAME ASC SEPARATOR ', '
        ) AS EXCLUDED
    FROM
        CUSTOMER_ORDERS AS CO,
        JSON_TABLE(
            CONCAT('["', REPLACE(CO.EXCLUSIONS, ', ', '","'), '"]'),
            '$[*]' COLUMNS (TOPPING VARCHAR(255) PATH '$')
        ) AS S
        INNER JOIN PIZZA_TOPPINGS AS PT ON PT.TOPPING_ID = S.TOPPING
    WHERE
        LENGTH(S.TOPPING) > 0
        AND S.TOPPING IS NOT NULL
        AND S.TOPPING <> 'NULL'
    GROUP BY
        CO.ORDER_ID,
        CO.PIZZA_ID,
        CO.EXCLUSIONS
)
SELECT
    CO.ORDER_ID,
    CONCAT(
        CASE
            WHEN PN.PIZZA_NAME = 'Meatlovers' THEN 'MEAT LOVERS'
            WHEN PN.PIZZA_NAME = 'Vegetarian' THEN 'VEGETARIAN'
            ELSE PN.PIZZA_NAME
        END,
        IFNULL(CONCAT(' - EXTRA ', EXT.ADDED_EXTRAS), ''),
        IFNULL(CONCAT(' - EXCLUDED ', EXC.EXCLUDED), '')
    ) AS ORDER_DETAILS
FROM
    CUSTOMER_ORDERS AS CO
    LEFT JOIN EXTRAS AS EXT ON EXT.ORDER_ID = CO.ORDER_ID
    AND EXT.PIZZA_ID = CO.PIZZA_ID
    LEFT JOIN EXCLUSIONS AS EXC ON EXC.ORDER_ID = CO.ORDER_ID
    AND EXC.PIZZA_ID = CO.PIZZA_ID
    INNER JOIN PIZZA_NAMES AS PN ON PN.PIZZA_ID = CO.PIZZA_ID;

-- 05 GENERATE AN ALPHABETICALLY ORDERED COMMA SEPARATED INGREDIENT LIST FOR EACH PIZZA ORDER FROM THE CUSTOMER_ORDERS TABLE AND ADD A 2X IN FRONT OF ANY RELEVANT INGREDIENTS
-- - FOR EXAMPLE: "MEAT LOVERS: 2XBACON, BEEF, ... , SALAMI"
WITH EXCLUSIONS AS (
    SELECT
        CO.order_id,
        CO.pizza_id,
        S.topping_id
    FROM
        customer_orders AS CO
        JOIN JSON_TABLE(
            CONCAT('["', REPLACE(CO.exclusions, ', ', '","'), '"]'),
            '$[*]' COLUMNS (topping_id VARCHAR(255) PATH '$')
        ) AS S
    WHERE
        LENGTH(S.topping_id) > 0
        AND S.topping_id <> 'null'
),
EXTRAS AS (
    SELECT
        CO.order_id,
        CO.pizza_id,
        S.topping_id,
        T.topping_name
    FROM
        customer_orders AS CO
        JOIN JSON_TABLE(
            CONCAT('["', REPLACE(CO.extras, ', ', '","'), '"]'),
            '$[*]' COLUMNS (topping_id VARCHAR(255) PATH '$')
        ) AS S
        INNER JOIN pizza_toppings AS T ON T.topping_id = S.topping_id
    WHERE
        LENGTH(S.topping_id) > 0
        AND S.topping_id <> 'null'
),
ORDERS AS (
    SELECT
        DISTINCT CO.order_id,
        CO.pizza_id,
        S.topping_id,
        T.topping_name
    FROM
        customer_orders AS CO
        INNER JOIN pizza_recipes AS PR ON CO.pizza_id = PR.pizza_id
        JOIN JSON_TABLE(
            CONCAT('["', REPLACE(PR.toppings, ', ', '","'), '"]'),
            '$[*]' COLUMNS (topping_id VARCHAR(255) PATH '$')
        ) AS S
        INNER JOIN pizza_toppings AS T ON T.topping_id = S.topping_id
),
ORDERS_WITH_EXTRAS_AND_EXCLUSIONS AS (
    SELECT
        O.order_id,
        O.pizza_id,
        O.topping_id,
        O.topping_name
    FROM
        ORDERS AS O
        LEFT JOIN EXCLUSIONS AS EXC ON EXC.order_id = O.order_id
        AND EXC.pizza_id = O.pizza_id
        AND EXC.topping_id = O.topping_id
    WHERE
        EXC.topping_id IS NULL
    UNION
    ALL
    SELECT
        E.order_id,
        E.pizza_id,
        E.topping_id,
        E.topping_name
    FROM
        EXTRAS AS E
),
TOPPING_COUNT AS (
    SELECT
        O.order_id,
        O.pizza_id,
        O.topping_name,
        COUNT(*) AS n
    FROM
        ORDERS_WITH_EXTRAS_AND_EXCLUSIONS AS O
    GROUP BY
        O.order_id,
        O.pizza_id,
        O.topping_name
)
SELECT
    order_id,
    pizza_id,
    GROUP_CONCAT(
        CASE
            WHEN n > 1 THEN CONCAT(n, 'x', topping_name)
            ELSE topping_name
        END
        ORDER BY
            topping_name SEPARATOR ', '
    ) AS ingredient
FROM
    TOPPING_COUNT
GROUP BY
    order_id,
    pizza_id;

-- 06 WHAT IS THE TOTAL QUANTITY OF EACH INGREDIENT USED IN ALL DELIVERED PIZZAS SORTED BY MOST FREQUENT FIRST?
WITH EXCLUSIONS AS (
    SELECT
        CO.order_id,
        CO.pizza_id,
        S.topping_id
    FROM
        customer_orders AS CO
        JOIN JSON_TABLE(
            CONCAT('["', REPLACE(CO.exclusions, ', ', '","'), '"]'),
            '$[*]' COLUMNS (topping_id VARCHAR(255) PATH '$')
        ) AS S
    WHERE
        LENGTH(S.topping_id) > 0
        AND S.topping_id <> 'null'
),
EXTRAS AS (
    SELECT
        CO.order_id,
        CO.pizza_id,
        S.topping_id,
        T.topping_name
    FROM
        customer_orders AS CO
        JOIN JSON_TABLE(
            CONCAT('["', REPLACE(CO.extras, ', ', '","'), '"]'),
            '$[*]' COLUMNS (topping_id VARCHAR(255) PATH '$')
        ) AS S
        INNER JOIN pizza_toppings AS T ON T.topping_id = S.topping_id
    WHERE
        LENGTH(S.topping_id) > 0
        AND S.topping_id <> 'null'
),
ORDERS AS (
    SELECT
        DISTINCT CO.order_id,
        CO.pizza_id,
        S.topping_id,
        T.topping_name
    FROM
        customer_orders AS CO
        INNER JOIN pizza_recipes AS PR ON CO.pizza_id = PR.pizza_id
        JOIN JSON_TABLE(
            CONCAT('["', REPLACE(PR.toppings, ', ', '","'), '"]'),
            '$[*]' COLUMNS (topping_id VARCHAR(255) PATH '$')
        ) AS S
        INNER JOIN pizza_toppings AS T ON T.topping_id = S.topping_id
),
ORDERS_WITH_EXTRAS_AND_EXCLUSIONS AS (
    SELECT
        O.order_id,
        O.pizza_id,
        CAST(O.topping_id AS SIGNED) AS topping_id,
        O.topping_name
    FROM
        ORDERS AS O
        LEFT JOIN EXCLUSIONS AS EXC ON EXC.order_id = O.order_id
        AND EXC.pizza_id = O.pizza_id
        AND EXC.topping_id = O.topping_id
    WHERE
        EXC.topping_id IS NULL
    UNION
    ALL
    SELECT
        E.order_id,
        E.pizza_id,
        CAST(E.topping_id AS SIGNED) AS topping_id,
        E.topping_name
    FROM
        EXTRAS AS E
    WHERE
        E.topping_id <> ''
)
SELECT
    O.topping_name,
    COUNT(O.pizza_id) AS ingredient_count
FROM
    ORDERS_WITH_EXTRAS_AND_EXCLUSIONS AS O
    INNER JOIN runner_orders AS RO ON O.order_id = RO.order_id
WHERE
    RO.pickup_time <> 'null'
GROUP BY
    O.topping_name
ORDER BY
    COUNT(O.pizza_id) DESC;