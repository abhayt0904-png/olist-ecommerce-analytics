WITH customer_order_counts AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS delivered_order_count
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_types AS (
    SELECT
        CASE
            WHEN delivered_order_count = 1
                THEN 'One delivered order'
            ELSE 'Repeat customer (2+ delivered orders)'
        END AS customer_type
    FROM customer_order_counts
)
SELECT
    customer_type,
    COUNT(*) AS customer_count,
    ROUND(
        100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS customer_percentage
FROM customer_types
GROUP BY customer_type
ORDER BY customer_type;




WITH delivered_customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        DATE_TRUNC(
            'month', o.order_purchase_timestamp
        )::date AS activity_month
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(activity_month) AS cohort_month
    FROM delivered_customer_orders
    GROUP BY customer_unique_id
),
customer_activity AS (
    SELECT
        d.customer_unique_id,
        f.cohort_month,
        d.activity_month,
        (
            (EXTRACT(YEAR FROM d.activity_month)
             - EXTRACT(YEAR FROM f.cohort_month)) * 12
            + EXTRACT(MONTH FROM d.activity_month)
            - EXTRACT(MONTH FROM f.cohort_month)
        )::integer AS months_since_first_purchase
    FROM delivered_customer_orders AS d
    INNER JOIN first_purchase AS f
        ON d.customer_unique_id = f.customer_unique_id
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_customers
    FROM first_purchase
    GROUP BY cohort_month
)
SELECT
    a.cohort_month,
    a.activity_month,
    a.months_since_first_purchase,
    COUNT(DISTINCT a.customer_unique_id) AS active_customers,
    s.cohort_customers,
    ROUND(
        100.0 * COUNT(DISTINCT a.customer_unique_id)
        / NULLIF(s.cohort_customers, 0),
        2
    ) AS retention_pct
FROM customer_activity AS a
INNER JOIN cohort_sizes AS s
    ON a.cohort_month = s.cohort_month
GROUP BY
    a.cohort_month,
    a.activity_month,
    a.months_since_first_purchase,
    s.cohort_customers
ORDER BY
    a.cohort_month,
    a.months_since_first_purchase;





WITH delivered_customer_orders AS (
    SELECT DISTINCT
        c.customer_unique_id,
        o.order_id,
        DATE_TRUNC(
            'month', o.order_purchase_timestamp
        )::date AS activity_month
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(activity_month) AS cohort_month
    FROM delivered_customer_orders
    GROUP BY customer_unique_id
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_customers
    FROM first_purchase
    GROUP BY cohort_month
),
cohort_activity AS (
    SELECT
        f.cohort_month,
        d.activity_month,
        COUNT(DISTINCT d.customer_unique_id) AS active_customers
    FROM delivered_customer_orders AS d
    INNER JOIN first_purchase AS f
        ON d.customer_unique_id = f.customer_unique_id
    GROUP BY f.cohort_month, d.activity_month
),
last_activity AS (
    SELECT MAX(activity_month) AS last_activity_month
    FROM delivered_customer_orders
),
cohort_calendar AS (
    SELECT
        cs.cohort_month,
        gs.activity_month::date AS activity_month,
        cs.cohort_customers
    FROM cohort_sizes AS cs
    CROSS JOIN last_activity AS la
    CROSS JOIN LATERAL generate_series(
        cs.cohort_month::timestamp,
        la.last_activity_month::timestamp,
        INTERVAL '1 month'
    ) AS gs(activity_month)
)
SELECT
    cc.cohort_month,
    cc.activity_month,
    (
        (EXTRACT(YEAR FROM cc.activity_month)
         - EXTRACT(YEAR FROM cc.cohort_month)) * 12
        + EXTRACT(MONTH FROM cc.activity_month)
        - EXTRACT(MONTH FROM cc.cohort_month)
    )::integer AS months_since_first_purchase,
    COALESCE(ca.active_customers, 0) AS active_customers,
    cc.cohort_customers,
    ROUND(
        100.0 * COALESCE(ca.active_customers, 0)
        / NULLIF(cc.cohort_customers, 0),
        2
    ) AS retention_pct
FROM cohort_calendar AS cc
LEFT JOIN cohort_activity AS ca
    ON cc.cohort_month = ca.cohort_month
   AND cc.activity_month = ca.activity_month
ORDER BY
    cc.cohort_month,
    months_since_first_purchase;






WITH delivered_customer_orders AS (
    SELECT DISTINCT
        c.customer_unique_id,
        o.order_id,
        DATE_TRUNC(
            'month', o.order_purchase_timestamp
        )::date AS activity_month
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(activity_month) AS cohort_month
    FROM delivered_customer_orders
    GROUP BY customer_unique_id
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_customers
    FROM first_purchase
    GROUP BY cohort_month
),
cohort_activity AS (
    SELECT
        f.cohort_month,
        d.activity_month,
        COUNT(DISTINCT d.customer_unique_id) AS active_customers
    FROM delivered_customer_orders AS d
    INNER JOIN first_purchase AS f
        ON d.customer_unique_id = f.customer_unique_id
    GROUP BY f.cohort_month, d.activity_month
),
last_activity AS (
    SELECT MAX(activity_month) AS last_activity_month
    FROM delivered_customer_orders
),
cohort_calendar AS (
    SELECT
        cs.cohort_month,
        gs.activity_month::date AS activity_month,
        cs.cohort_customers
    FROM cohort_sizes AS cs
    CROSS JOIN last_activity AS la
    CROSS JOIN LATERAL generate_series(
        cs.cohort_month::timestamp,
        la.last_activity_month::timestamp,
        INTERVAL '1 month'
    ) AS gs(activity_month)
),
cohort_retention AS (
    SELECT
        cc.cohort_month,
        cc.cohort_customers,
        (
            (EXTRACT(YEAR FROM cc.activity_month)
             - EXTRACT(YEAR FROM cc.cohort_month)) * 12
            + EXTRACT(MONTH FROM cc.activity_month)
            - EXTRACT(MONTH FROM cc.cohort_month)
        )::integer AS months_since_first_purchase,
        ROUND(
            100.0 * COALESCE(ca.active_customers, 0)
            / NULLIF(cc.cohort_customers, 0),
            2
        ) AS retention_pct
    FROM cohort_calendar AS cc
    LEFT JOIN cohort_activity AS ca
        ON cc.cohort_month = ca.cohort_month
       AND cc.activity_month = ca.activity_month
)
SELECT
    cohort_month,
    cohort_customers,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 0
    ) AS month_0,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 1
    ) AS month_1,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 2
    ) AS month_2,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 3
    ) AS month_3,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 4
    ) AS month_4,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 5
    ) AS month_5,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 6
    ) AS month_6,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 7
    ) AS month_7,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 8
    ) AS month_8,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 9
    ) AS month_9,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 10
    ) AS month_10,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 11
    ) AS month_11,
    MAX(retention_pct) FILTER (
        WHERE months_since_first_purchase = 12
    ) AS month_12
FROM cohort_retention
GROUP BY cohort_month, cohort_customers
ORDER BY cohort_month;






WITH delivered_customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
first_purchase AS (
    SELECT customer_unique_id
    FROM delivered_customer_orders
    GROUP BY customer_unique_id
)
SELECT COUNT(*) AS total_cohort_customers
FROM first_purchase;





