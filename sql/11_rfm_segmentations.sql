SELECT
    MAX(order_purchase_timestamp)::date
        AS latest_dataset_purchase_date,

    MAX(order_purchase_timestamp) FILTER (
        WHERE order_status = 'delivered'
    )::date AS latest_delivered_purchase_date,

    MAX(order_purchase_timestamp)::date + 1
        AS proposed_rfm_snapshot_date,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_orders
FROM public.olist_orders;







WITH delivered_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp::date AS purchase_date
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
order_merchandise AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value
    FROM public.olist_order_items
    GROUP BY order_id
),
customer_rfm AS (
    SELECT
        d.customer_unique_id,

        DATE '2018-10-18' - MAX(d.purchase_date)
            AS recency_days,

        COUNT(DISTINCT d.order_id) AS frequency,

        ROUND(
            SUM(COALESCE(om.merchandise_value, 0)),
            2
        ) AS monetary_value_brl

    FROM delivered_orders AS d

    LEFT JOIN order_merchandise AS om
        ON d.order_id = om.order_id

    GROUP BY d.customer_unique_id
)
SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary_value_brl
FROM customer_rfm
ORDER BY monetary_value_brl DESC;







WITH delivered_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp::date AS purchase_date
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
order_merchandise AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value
    FROM public.olist_order_items
    GROUP BY order_id
),
customer_rfm AS (
    SELECT
        d.customer_unique_id,
        DATE '2018-10-18' - MAX(d.purchase_date) AS recency_days,
        COUNT(DISTINCT d.order_id) AS frequency,
        SUM(COALESCE(om.merchandise_value, 0))
            AS monetary_value_brl
    FROM delivered_orders AS d
    LEFT JOIN order_merchandise AS om
        ON d.order_id = om.order_id
    GROUP BY d.customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(frequency) AS total_delivered_orders,
    ROUND(SUM(monetary_value_brl), 2)
        AS total_delivered_gmv_brl,
    MIN(recency_days) AS minimum_recency_days,
    MAX(recency_days) AS maximum_recency_days,
    COUNT(*) FILTER (
        WHERE recency_days < 0
    ) AS negative_recency_customers,
    COUNT(*) FILTER (
        WHERE frequency < 1
    ) AS invalid_frequency_customers
FROM customer_rfm;






-- STEP 3: Inspect customer purchase frequency

WITH delivered_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

customer_frequency AS (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS frequency
    FROM delivered_orders
    GROUP BY customer_unique_id
)

SELECT
    frequency,
    COUNT(*) AS customer_count,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS customer_percentage

FROM customer_frequency
GROUP BY frequency
ORDER BY frequency;






-- STEP 4: Assign Frequency Scores

WITH delivered_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

customer_frequency AS (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS frequency
    FROM delivered_orders
    GROUP BY customer_unique_id
),

frequency_scored AS (
    SELECT
        customer_unique_id,
        frequency,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency = 4 THEN 4
            ELSE 5
        END AS f_score

    FROM customer_frequency
)

SELECT
    f_score,
    COUNT(*) AS customer_count,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS customer_percentage

FROM frequency_scored
GROUP BY f_score
ORDER BY f_score;



-- =====================================================
-- STEP 5: ASSIGN RECENCY SCORES
-- Method: CUME_DIST()
-- Higher score = more recent purchase
-- Identical recency values receive the same score.
-- RFM snapshot date: 2018-10-18
-- =====================================================

WITH delivered_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp::date AS purchase_date
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

customer_recency AS (
    SELECT
        customer_unique_id,
        DATE '2018-10-18' - MAX(purchase_date)
            AS recency_days
    FROM delivered_orders
    GROUP BY customer_unique_id
),

recency_percentile AS (
    SELECT
        customer_unique_id,
        recency_days,

        CUME_DIST() OVER (
            ORDER BY recency_days DESC
        ) AS recency_distribution

    FROM customer_recency
),

recency_scored AS (
    SELECT
        customer_unique_id,
        recency_days,

        CASE
            WHEN recency_distribution <= 0.20 THEN 1
            WHEN recency_distribution <= 0.40 THEN 2
            WHEN recency_distribution <= 0.60 THEN 3
            WHEN recency_distribution <= 0.80 THEN 4
            ELSE 5
        END AS r_score

    FROM recency_percentile
)

SELECT
    r_score,
    COUNT(*) AS customer_count,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS customer_percentage,

    MIN(recency_days) AS minimum_recency_days,
    MAX(recency_days) AS maximum_recency_days

FROM recency_scored
GROUP BY r_score
ORDER BY r_score;






-- STEP 6: Assign Monetary Scores
-- Higher merchandise spending receives a higher score.

WITH delivered_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

order_merchandise AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value
    FROM public.olist_order_items
    GROUP BY order_id
),

customer_monetary AS (
    SELECT
        d.customer_unique_id,

        ROUND(
            SUM(COALESCE(om.merchandise_value, 0)),
            2
        ) AS monetary_value_brl

    FROM delivered_orders AS d
    LEFT JOIN order_merchandise AS om
        ON d.order_id = om.order_id

    GROUP BY d.customer_unique_id
),

monetary_percentile AS (
    SELECT
        customer_unique_id,
        monetary_value_brl,

        CUME_DIST() OVER (
            ORDER BY monetary_value_brl ASC
        ) AS monetary_distribution

    FROM customer_monetary
),

monetary_scored AS (
    SELECT
        customer_unique_id,
        monetary_value_brl,

        CASE
            WHEN monetary_distribution <= 0.20 THEN 1
            WHEN monetary_distribution <= 0.40 THEN 2
            WHEN monetary_distribution <= 0.60 THEN 3
            WHEN monetary_distribution <= 0.80 THEN 4
            ELSE 5
        END AS m_score

    FROM monetary_percentile
)

SELECT
    m_score,
    COUNT(*) AS customer_count,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS customer_percentage,

    MIN(monetary_value_brl) AS minimum_monetary_value,
    MAX(monetary_value_brl) AS maximum_monetary_value

FROM monetary_scored
GROUP BY m_score
ORDER BY m_score;







-- STEP 7: Combine Recency, Frequency and Monetary Scores

WITH delivered_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp::date AS purchase_date
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

order_merchandise AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value
    FROM public.olist_order_items
    GROUP BY order_id
),

customer_rfm AS (
    SELECT
        d.customer_unique_id,

        DATE '2018-10-18' - MAX(d.purchase_date)
            AS recency_days,

        COUNT(DISTINCT d.order_id) AS frequency,

        ROUND(
            SUM(COALESCE(om.merchandise_value, 0)),
            2
        ) AS monetary_value_brl

    FROM delivered_orders AS d
    LEFT JOIN order_merchandise AS om
        ON d.order_id = om.order_id

    GROUP BY d.customer_unique_id
),

rfm_percentiles AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value_brl,

        CUME_DIST() OVER (
            ORDER BY recency_days DESC
        ) AS recency_distribution,

        CUME_DIST() OVER (
            ORDER BY monetary_value_brl ASC
        ) AS monetary_distribution

    FROM customer_rfm
),

rfm_scored AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value_brl,

        CASE
            WHEN recency_distribution <= 0.20 THEN 1
            WHEN recency_distribution <= 0.40 THEN 2
            WHEN recency_distribution <= 0.60 THEN 3
            WHEN recency_distribution <= 0.80 THEN 4
            ELSE 5
        END AS r_score,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency = 4 THEN 4
            ELSE 5
        END AS f_score,

        CASE
            WHEN monetary_distribution <= 0.20 THEN 1
            WHEN monetary_distribution <= 0.40 THEN 2
            WHEN monetary_distribution <= 0.60 THEN 3
            WHEN monetary_distribution <= 0.80 THEN 4
            ELSE 5
        END AS m_score

    FROM rfm_percentiles
)

SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary_value_brl,

    r_score,
    f_score,
    m_score,

    r_score::TEXT || '-' ||
    f_score::TEXT || '-' ||
    m_score::TEXT AS rfm_score,

    r_score + f_score + m_score AS rfm_total_score

FROM rfm_scored

ORDER BY
    rfm_total_score DESC,
    r_score DESC,
    f_score DESC,
    monetary_value_brl DESC

LIMIT 20;






-- STEP 8: Customer Segmentation Using RFM Scores

WITH delivered_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp::date AS purchase_date
    FROM public.olist_orders AS o
    INNER JOIN public.olist_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

order_merchandise AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value
    FROM public.olist_order_items
    GROUP BY order_id
),

customer_rfm AS (
    SELECT
        d.customer_unique_id,

        DATE '2018-10-18' - MAX(d.purchase_date)
            AS recency_days,

        COUNT(DISTINCT d.order_id) AS frequency,

        ROUND(
            SUM(COALESCE(om.merchandise_value, 0)),
            2
        ) AS monetary_value_brl

    FROM delivered_orders AS d
    LEFT JOIN order_merchandise AS om
        ON d.order_id = om.order_id

    GROUP BY d.customer_unique_id
),

rfm_percentiles AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value_brl,

        CUME_DIST() OVER (
            ORDER BY recency_days DESC
        ) AS recency_distribution,

        CUME_DIST() OVER (
            ORDER BY monetary_value_brl ASC
        ) AS monetary_distribution

    FROM customer_rfm
),

rfm_scored AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value_brl,

        CASE
            WHEN recency_distribution <= 0.20 THEN 1
            WHEN recency_distribution <= 0.40 THEN 2
            WHEN recency_distribution <= 0.60 THEN 3
            WHEN recency_distribution <= 0.80 THEN 4
            ELSE 5
        END AS r_score,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency = 4 THEN 4
            ELSE 5
        END AS f_score,

        CASE
            WHEN monetary_distribution <= 0.20 THEN 1
            WHEN monetary_distribution <= 0.40 THEN 2
            WHEN monetary_distribution <= 0.60 THEN 3
            WHEN monetary_distribution <= 0.80 THEN 4
            ELSE 5
        END AS m_score

    FROM rfm_percentiles
),

rfm_segmented AS (
    SELECT
        *,

        CASE
            WHEN r_score >= 4
                 AND f_score >= 4
                 AND m_score >= 4
                THEN 'Champions'

            WHEN r_score >= 4
                 AND f_score >= 4
                THEN 'Loyal Repeat Customers'

            WHEN r_score >= 4
                 AND f_score IN (2, 3)
                THEN 'Potential Loyalists'

            WHEN r_score >= 4
                 AND f_score = 1
                THEN 'Recent One-Time Buyers'

            WHEN r_score = 3
                 AND f_score >= 2
                THEN 'Repeat Customers Needing Attention'

            WHEN r_score = 3
                 AND f_score = 1
                THEN 'One-Time Customers Needing Attention'

            WHEN r_score <= 2
                 AND f_score >= 2
                THEN 'Lapsed Repeat Customers'

            ELSE 'Hibernating One-Time Buyers'

        END AS customer_segment

    FROM rfm_scored
)

SELECT
    customer_segment,

    COUNT(*) AS customer_count,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS customer_percentage,

    ROUND(AVG(recency_days), 2)
        AS average_recency_days,

    ROUND(AVG(frequency), 2)
        AS average_frequency,

    ROUND(AVG(monetary_value_brl), 2)
        AS average_monetary_value_brl,

    ROUND(SUM(monetary_value_brl), 2)
        AS total_monetary_value_brl,

    ROUND(
        100.0 * SUM(monetary_value_brl) /
        NULLIF(
            SUM(SUM(monetary_value_brl)) OVER (),
            0
        ),
        2
    ) AS monetary_contribution_percentage

FROM rfm_segmented

GROUP BY customer_segment

ORDER BY customer_count DESC;




