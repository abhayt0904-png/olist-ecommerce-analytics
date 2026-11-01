
-- STEP 1: Inspect delivery dates and data quality

WITH delivered_orders AS (
    SELECT
        order_id,
        order_purchase_timestamp,
        order_delivered_customer_date,
        order_estimated_delivery_date

    FROM public.olist_orders

    WHERE order_status = 'delivered'
)

SELECT
    COUNT(*) AS total_delivered_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS missing_actual_delivery_dates,

    COUNT(*) FILTER (
        WHERE order_estimated_delivery_date IS NULL
    ) AS missing_estimated_delivery_dates,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              < order_purchase_timestamp
    ) AS invalid_delivery_dates,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
          AND order_estimated_delivery_date IS NOT NULL
          AND order_delivered_customer_date::date
              <= order_estimated_delivery_date::date
    ) AS on_time_or_early_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
          AND order_estimated_delivery_date IS NOT NULL
          AND order_delivered_customer_date::date
              > order_estimated_delivery_date::date
    ) AS late_delivered_orders

FROM delivered_orders;






-- STEP 2: Calculate Delivery Duration and Delay

WITH delivery_metrics AS (
    SELECT
        order_id,

        -- Actual delivery duration in days
        EXTRACT(
            EPOCH FROM (
                order_delivered_customer_date
                - order_purchase_timestamp
            )
        ) / 86400.0 AS actual_delivery_days,

        -- Estimated delivery duration in days
        EXTRACT(
            EPOCH FROM (
                order_estimated_delivery_date
                - order_purchase_timestamp
            )
        ) / 86400.0 AS estimated_delivery_days,

        -- Difference between actual and estimated
        -- delivery dates, using calendar days
        order_delivered_customer_date::date
        - order_estimated_delivery_date::date
            AS delivery_variance_days

    FROM public.olist_orders

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    COUNT(*) AS eligible_delivered_orders,

    ROUND(
        AVG(actual_delivery_days)::numeric,
        2
    ) AS average_actual_delivery_days,

    ROUND(
        (PERCENTILE_CONT(0.50)
            WITHIN GROUP (
                ORDER BY actual_delivery_days
            ))::numeric,
        2
    ) AS median_actual_delivery_days,

    ROUND(
        MIN(actual_delivery_days)::numeric,
        2
    ) AS minimum_actual_delivery_days,

    ROUND(
        MAX(actual_delivery_days)::numeric,
        2
    ) AS maximum_actual_delivery_days,

    ROUND(
        AVG(estimated_delivery_days)::numeric,
        2
    ) AS average_estimated_delivery_days,

    ROUND(
        AVG(delivery_variance_days),
        2
    ) AS average_delivery_variance_days,

    ROUND(
        AVG(delivery_variance_days)
            FILTER (WHERE delivery_variance_days > 0),
        2
    ) AS average_days_late

FROM delivery_metrics;







-- STEP 3: Investigate the 15 Longest Delivery Durations

SELECT
    order_id,

    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    ROUND(
        (
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_purchase_timestamp
                )
            ) / 86400.0
        )::numeric,
        2
    ) AS actual_delivery_days,

    (
        order_delivered_customer_date::date
        - order_estimated_delivery_date::date
    ) AS delivery_variance_days

FROM public.olist_orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL

ORDER BY actual_delivery_days DESC

LIMIT 15;






-- STEP 4: Investigate Longest Deliveries by Delivery Stage

WITH delivery_durations AS (
    SELECT
        order_id,
        order_purchase_timestamp,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date,

        EXTRACT(
            EPOCH FROM (
                order_delivered_customer_date
                - order_purchase_timestamp
            )
        ) / 86400.0 AS actual_delivery_days

    FROM public.olist_orders

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),

longest_deliveries AS (
    SELECT *
    FROM delivery_durations
    ORDER BY actual_delivery_days DESC
    LIMIT 15
)

SELECT
    order_id,

    order_purchase_timestamp,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    ROUND(
        (
            EXTRACT(
                EPOCH FROM (
                    order_delivered_carrier_date
                    - order_purchase_timestamp
                )
            ) / 86400.0
        )::numeric,
        2
    ) AS purchase_to_carrier_days,

    ROUND(
        (
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_delivered_carrier_date
                )
            ) / 86400.0
        )::numeric,
        2
    ) AS carrier_to_customer_days,

    ROUND(
        actual_delivery_days::numeric,
        2
    ) AS actual_delivery_days,

    (
        order_delivered_customer_date::date
        - order_estimated_delivery_date::date
    ) AS delivery_variance_days,

    CASE
        WHEN order_delivered_carrier_date IS NULL
            THEN 'Missing carrier date'

        WHEN order_delivered_carrier_date
             < order_purchase_timestamp
            THEN 'Carrier date before purchase'

        WHEN order_delivered_carrier_date
             > order_delivered_customer_date
            THEN 'Carrier date after customer delivery'

        ELSE 'Chronologically valid'
    END AS carrier_date_check

FROM longest_deliveries

ORDER BY actual_delivery_days DESC;








-- STEP 5: Analyse Customer Review Score Distribution

SELECT
    review_score,

    COUNT(*) AS review_records,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS review_percentage,

    (
        SELECT
            ROUND(AVG(review_score)::numeric, 2)
        FROM public.olist_order_reviews
    ) AS overall_average_review_score

FROM public.olist_order_reviews

GROUP BY review_score

ORDER BY review_score;







-- STEP 6: Compare Delivery Performance with Customer Reviews

WITH delivery_classification AS (
    SELECT
        order_id,

        CASE
            WHEN order_delivered_customer_date::date
                 <= order_estimated_delivery_date::date
                THEN 'On time or early'

            ELSE 'Late'
        END AS delivery_category

    FROM public.olist_orders

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),

order_review_scores AS (
    SELECT
        order_id,

        AVG(review_score::numeric)
            AS average_order_review_score,

        COUNT(*) AS review_record_count

    FROM public.olist_order_reviews

    WHERE order_id IS NOT NULL
      AND review_score IS NOT NULL

    GROUP BY order_id
)

SELECT
    d.delivery_category,

    COUNT(*) AS eligible_delivered_orders,

    COUNT(r.order_id) AS orders_with_reviews,

    COUNT(*) - COUNT(r.order_id)
        AS orders_without_reviews,

    ROUND(
        100.0 * COUNT(r.order_id) /
        NULLIF(COUNT(*), 0),
        2
    ) AS review_coverage_percentage,

    SUM(COALESCE(r.review_record_count, 0))
        AS total_review_records,

    ROUND(
        AVG(r.average_order_review_score),
        2
    ) AS average_review_score,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (
            ORDER BY r.average_order_review_score
        )::numeric,
        2
    ) AS median_review_score

FROM delivery_classification AS d

LEFT JOIN order_review_scores AS r
    ON d.order_id = r.order_id

GROUP BY d.delivery_category

ORDER BY
    CASE
        WHEN d.delivery_category = 'On time or early'
            THEN 1
        ELSE 2
    END;






-- STEP 7: Review Score Distribution by Delivery Category

WITH delivery_classification AS (
    SELECT
        order_id,

        CASE
            WHEN order_delivered_customer_date::date
                 <= order_estimated_delivery_date::date
                THEN 'On time or early'
            ELSE 'Late'
        END AS delivery_category

    FROM public.olist_orders

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),

review_distribution AS (
    SELECT
        d.delivery_category,
        r.review_score

    FROM delivery_classification AS d

    INNER JOIN public.olist_order_reviews AS r
        ON d.order_id = r.order_id

    WHERE r.review_score IS NOT NULL
)

SELECT
    delivery_category,

    review_score,

    COUNT(*) AS review_records,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (
            PARTITION BY delivery_category
        ),
        2
    ) AS review_percentage

FROM review_distribution

GROUP BY
    delivery_category,
    review_score

ORDER BY
    CASE
        WHEN delivery_category = 'On time or early'
            THEN 1
        ELSE 2
    END,
    review_score;






-- STEP 8: Order-Level Review Categories by Delivery Performance

WITH delivery_classification AS (
    SELECT
        order_id,

        CASE
            WHEN order_delivered_customer_date::date
                 <= order_estimated_delivery_date::date
                THEN 'On time or early'
            ELSE 'Late'
        END AS delivery_category

    FROM public.olist_orders

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),

order_review_scores AS (
    SELECT
        order_id,

        AVG(review_score::numeric)
            AS average_order_review_score

    FROM public.olist_order_reviews

    WHERE order_id IS NOT NULL
      AND review_score IS NOT NULL

    GROUP BY order_id
),

order_satisfaction AS (
    SELECT
        d.delivery_category,
        r.order_id,
        r.average_order_review_score,

        CASE
            WHEN r.average_order_review_score <= 2
                THEN 'Low-rated orders'

            WHEN r.average_order_review_score < 4
                THEN 'Moderate-rated orders'

            ELSE 'Positive-rated orders'
        END AS satisfaction_category

    FROM delivery_classification AS d

    INNER JOIN order_review_scores AS r
        ON d.order_id = r.order_id
)

SELECT
    delivery_category,
    satisfaction_category,

    COUNT(*) AS order_count,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (
            PARTITION BY delivery_category
        ),
        2
    ) AS order_percentage,

    ROUND(
        AVG(average_order_review_score),
        2
    ) AS average_order_review_score

FROM order_satisfaction

GROUP BY
    delivery_category,
    satisfaction_category

ORDER BY
    CASE
        WHEN delivery_category = 'On time or early'
            THEN 1
        ELSE 2
    END,

    CASE
        WHEN satisfaction_category = 'Low-rated orders'
            THEN 1
        WHEN satisfaction_category = 'Moderate-rated orders'
            THEN 2
        ELSE 3
    END;






-- STEP 9: Analyse Review Scores by Delivery Delay Severity

WITH delivery_performance AS (
    SELECT
        order_id,

        (
            order_delivered_customer_date::date
            - order_estimated_delivery_date::date
        ) AS delivery_variance_days

    FROM public.olist_orders

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),

delivery_categories AS (
    SELECT
        order_id,
        delivery_variance_days,

        CASE
            WHEN delivery_variance_days <= 0
                THEN 'On time or early'

            WHEN delivery_variance_days <= 3
                THEN '1-3 days late'

            WHEN delivery_variance_days <= 7
                THEN '4-7 days late'

            WHEN delivery_variance_days <= 14
                THEN '8-14 days late'

            ELSE 'More than 14 days late'
        END AS delivery_category

    FROM delivery_performance
),

order_review_scores AS (
    SELECT
        order_id,

        AVG(review_score::numeric)
            AS average_order_review_score

    FROM public.olist_order_reviews

    WHERE order_id IS NOT NULL
      AND review_score IS NOT NULL

    GROUP BY order_id
),

combined_data AS (
    SELECT
        d.order_id,
        d.delivery_variance_days,
        d.delivery_category,
        r.average_order_review_score

    FROM delivery_categories AS d

    INNER JOIN order_review_scores AS r
        ON d.order_id = r.order_id
)

SELECT
    delivery_category,

    COUNT(*) AS reviewed_orders,

    ROUND(
        AVG(delivery_variance_days),
        2
    ) AS  average_delivery_variance_days,

    ROUND(
        AVG(average_order_review_score),
        2
    ) AS average_review_score,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (
            ORDER BY average_order_review_score
        )::numeric,
        2
    ) AS median_review_score,

    COUNT(*) FILTER (
        WHERE average_order_review_score <= 2
    ) AS low_rated_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE average_order_review_score <= 2
        ) / COUNT(*),
        2
    ) AS low_rated_percentage,

    COUNT(*) FILTER (
        WHERE average_order_review_score >= 4
    ) AS positive_rated_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE average_order_review_score >= 4
        ) / COUNT(*),
        2
    ) AS positive_rated_percentage

FROM combined_data

GROUP BY delivery_category

ORDER BY
    CASE delivery_category
        WHEN 'On time or early' THEN 1
        WHEN '1-3 days late' THEN 2
        WHEN '4-7 days late' THEN 3
        WHEN '8-14 days late' THEN 4
        WHEN 'More than 14 days late' THEN 5
    END;






-- STEP 10: Monthly Delivery Performance Analysis

WITH delivery_metrics AS (
    SELECT
        order_id,

        DATE_TRUNC(
            'month',
            order_purchase_timestamp
        )::date AS purchase_month,

        EXTRACT(
            EPOCH FROM (
                order_delivered_customer_date
                - order_purchase_timestamp
            )
        ) / 86400.0 AS actual_delivery_days,

        (
            order_delivered_customer_date::date
            - order_estimated_delivery_date::date
        ) AS delivery_variance_days

    FROM public.olist_orders

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    purchase_month,

    COUNT(*) AS total_delivered_orders,

    COUNT(*) FILTER (
        WHERE delivery_variance_days <= 0
    ) AS on_time_or_early_orders,

    COUNT(*) FILTER (
        WHERE delivery_variance_days > 0
    ) AS late_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delivery_variance_days > 0
        ) / COUNT(*),
        2
    ) AS late_delivery_percentage,

    ROUND(
        AVG(actual_delivery_days)::numeric,
        2
    ) AS average_actual_delivery_days,

    ROUND(
        AVG(delivery_variance_days)::numeric,
        2
    ) AS average_delivery_variance_days,

    ROUND(
        AVG(delivery_variance_days) FILTER (
            WHERE delivery_variance_days > 0
        )::numeric,
        2
    ) AS average_days_late

FROM delivery_metrics

GROUP BY purchase_month

ORDER BY purchase_month;




