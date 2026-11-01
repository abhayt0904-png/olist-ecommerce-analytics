

WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value
    FROM public.olist_order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM public.olist_order_payments
    GROUP BY order_id
),
order_comparison AS (
    SELECT
        COALESCE(i.order_id, p.order_id) AS order_id,
        i.merchandise_value,
        i.freight_value,
        p.payment_value
    FROM item_totals AS i
    FULL OUTER JOIN payment_totals AS p
        ON i.order_id = p.order_id
)
SELECT
    COUNT(*) AS orders_in_either_table,
    COUNT(*) FILTER (
        WHERE merchandise_value IS NOT NULL
    ) AS orders_with_items,
    COUNT(*) FILTER (
        WHERE payment_value IS NOT NULL
    ) AS orders_with_payments,
    COUNT(*) FILTER (
        WHERE merchandise_value IS NOT NULL
          AND payment_value IS NOT NULL
    ) AS orders_with_both,
    COUNT(*) FILTER (
        WHERE merchandise_value IS NOT NULL
          AND payment_value IS NULL
    ) AS orders_with_items_but_no_payment,
    COUNT(*) FILTER (
        WHERE merchandise_value IS NULL
          AND payment_value IS NOT NULL
    ) AS orders_with_payment_but_no_items,
    ROUND(SUM(merchandise_value), 2)
        AS merchandise_total_brl,
    ROUND(SUM(freight_value), 2)
        AS freight_total_brl,
    ROUND(SUM(payment_value), 2)
        AS payment_total_brl,
    ROUND(
        SUM(
            COALESCE(merchandise_value, 0)
            + COALESCE(freight_value, 0)
        ), 2
    ) AS merchandise_plus_freight_total_brl,
    ROUND(
        SUM(payment_value - (merchandise_value + freight_value))
        FILTER (
            WHERE merchandise_value IS NOT NULL
              AND payment_value IS NOT NULL
        ), 2
    ) AS net_difference_for_orders_with_both_brl
FROM order_comparison;





SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)::date
        AS purchase_month,
    COUNT(DISTINCT oi.order_id) AS delivered_orders_with_items,
    ROUND(SUM(oi.price), 2) AS delivered_gmv_brl
FROM public.olist_order_items AS oi
INNER JOIN public.olist_orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= TIMESTAMP '2018-08-01'
  AND o.order_purchase_timestamp < TIMESTAMP '2018-11-01'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)::date
ORDER BY purchase_month;




SELECT
    DATE_TRUNC('month', order_purchase_timestamp)::date
        AS purchase_month,
    order_status,
    COUNT(*) AS total_orders
FROM public.olist_orders
WHERE order_purchase_timestamp >= TIMESTAMP '2018-08-01'
  AND order_purchase_timestamp < TIMESTAMP '2018-11-01'
GROUP BY
    DATE_TRUNC('month', order_purchase_timestamp)::date,
    order_status
ORDER BY purchase_month, total_orders DESC;






WITH item_totals AS (
    SELECT order_id
    FROM public.olist_order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM public.olist_order_payments
    GROUP BY order_id
)
SELECT
    o.order_status,
    COUNT(*) AS payment_only_orders,
    ROUND(SUM(p.payment_value), 2) AS payment_value_brl
FROM payment_totals AS p
LEFT JOIN item_totals AS i
    ON p.order_id = i.order_id
INNER JOIN public.olist_orders AS o
    ON p.order_id = o.order_id
WHERE i.order_id IS NULL
GROUP BY o.order_status
ORDER BY payment_only_orders DESC;






WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value
    FROM public.olist_order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id
    FROM public.olist_order_payments
    GROUP BY order_id
)
SELECT
    i.order_id,
    o.order_status,
    ROUND(i.merchandise_value, 2) AS merchandise_value_brl,
    ROUND(i.freight_value, 2) AS freight_value_brl,
    ROUND(i.merchandise_value + i.freight_value, 2)
        AS item_plus_freight_brl,
    o.order_purchase_timestamp
FROM item_totals AS i
LEFT JOIN payment_totals AS p
    ON i.order_id = p.order_id
INNER JOIN public.olist_orders AS o
    ON i.order_id = o.order_id
WHERE p.order_id IS NULL;





WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value
    FROM public.olist_order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM public.olist_order_payments
    GROUP BY order_id
),
matched_orders AS (
    SELECT
        i.order_id,
        p.payment_value
            - (i.merchandise_value + i.freight_value) AS difference_brl
    FROM item_totals AS i
    INNER JOIN payment_totals AS p
        ON i.order_id = p.order_id
)
SELECT
    COUNT(*) AS matched_orders,
    COUNT(*) FILTER (
        WHERE ABS(difference_brl) > 0.01
    ) AS orders_with_difference_over_one_cent,
    COUNT(*) FILTER (
        WHERE difference_brl > 0.01
    ) AS orders_payment_above_item_total,
    COUNT(*) FILTER (
        WHERE difference_brl < -0.01
    ) AS orders_payment_below_item_total,
    ROUND(SUM(difference_brl), 2) AS net_difference_brl,
    ROUND(MAX(ABS(difference_brl)), 2)
        AS largest_absolute_difference_brl
FROM matched_orders;





WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value
    FROM public.olist_order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM public.olist_order_payments
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    ROUND(i.merchandise_value, 2) AS merchandise_value_brl,
    ROUND(i.freight_value, 2) AS freight_value_brl,
    ROUND(i.merchandise_value + i.freight_value, 2)
        AS item_plus_freight_brl,
    ROUND(p.payment_value, 2) AS payment_value_brl,
    ROUND(
        p.payment_value - (i.merchandise_value + i.freight_value),
        2
    ) AS difference_brl
FROM item_totals AS i
INNER JOIN payment_totals AS p
    ON i.order_id = p.order_id
INNER JOIN public.olist_orders AS o
    ON i.order_id = o.order_id
WHERE ABS(
    p.payment_value - (i.merchandise_value + i.freight_value)
) > 0.01
ORDER BY ABS(
    p.payment_value - (i.merchandise_value + i.freight_value)
) DESC
LIMIT 20;





WITH item_totals AS (
    SELECT
        order_id,
        COUNT(*) AS item_rows,
        COUNT(DISTINCT product_id) AS distinct_products,
        COUNT(DISTINCT seller_id) AS distinct_sellers,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value
    FROM public.olist_order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        COUNT(*) AS payment_record_count,
        COUNT(DISTINCT payment_type) AS distinct_payment_types,
        SUM(payment_value) AS payment_value
    FROM public.olist_order_payments
    GROUP BY order_id
),
payment_details AS (
    SELECT
        order_id,
        STRING_AGG(
            payment_type || ' (sequence ' || payment_sequential::text
            || ', value ' || payment_value::text
            || ', installments ' || payment_installments::text || ')',
            '; ' ORDER BY payment_sequential
        ) AS payment_breakdown
    FROM public.olist_order_payments
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.order_status,
    i.item_rows,
    i.distinct_products,
    i.distinct_sellers,
    p.payment_record_count,
    p.distinct_payment_types,
    pd.payment_breakdown,
    ROUND(i.merchandise_value, 2) AS merchandise_value_brl,
    ROUND(i.freight_value, 2) AS freight_value_brl,
    ROUND(i.merchandise_value + i.freight_value, 2)
        AS item_plus_freight_brl,
    ROUND(p.payment_value, 2) AS payment_value_brl,
    ROUND(
        p.payment_value - (i.merchandise_value + i.freight_value),
        2
    ) AS difference_brl
FROM item_totals AS i
INNER JOIN payment_totals AS p
    ON i.order_id = p.order_id
INNER JOIN public.olist_orders AS o
    ON i.order_id = o.order_id
LEFT JOIN payment_details AS pd
    ON p.order_id = pd.order_id
WHERE ABS(
    p.payment_value - (i.merchandise_value + i.freight_value)
) > 0.01
ORDER BY ABS(
    p.payment_value - (i.merchandise_value + i.freight_value)
) DESC
LIMIT 20;




WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value
    FROM public.olist_order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM public.olist_order_payments
    GROUP BY order_id
),
largest_mismatch AS (
    SELECT i.order_id
    FROM item_totals AS i
    INNER JOIN payment_totals AS p
        ON i.order_id = p.order_id
    ORDER BY ABS(
        p.payment_value - (i.merchandise_value + i.freight_value)
    ) DESC
    LIMIT 1
)
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,
    oi.shipping_limit_date
FROM public.olist_order_items AS oi
INNER JOIN largest_mismatch AS lm
    ON oi.order_id = lm.order_id
ORDER BY oi.order_item_id;





WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value
    FROM public.olist_order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM public.olist_order_payments
    GROUP BY order_id
),
largest_mismatch AS (
    SELECT i.order_id
    FROM item_totals AS i
    INNER JOIN payment_totals AS p
        ON i.order_id = p.order_id
    ORDER BY ABS(
        p.payment_value - (i.merchandise_value + i.freight_value)
    ) DESC
    LIMIT 1
)
SELECT
    p.order_id,
    p.payment_sequential,
    p.payment_type,
    p.payment_installments,
    p.payment_value
FROM public.olist_order_payments AS p
INNER JOIN largest_mismatch AS lm
    ON p.order_id = lm.order_id
ORDER BY p.payment_sequential;





WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value
    FROM public.olist_order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        COUNT(*) AS payment_record_count,
        MAX(payment_installments) AS payment_installments,
        SUM(payment_value) AS payment_value
    FROM public.olist_order_payments
    GROUP BY order_id
),
matched_single_payment_orders AS (
    SELECT
        p.payment_installments,
        p.payment_value
            - (i.merchandise_value + i.freight_value)
            AS difference_brl
    FROM item_totals AS i
    INNER JOIN payment_totals AS p
        ON i.order_id = p.order_id
    WHERE p.payment_record_count = 1
)
SELECT
    payment_installments,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE ABS(difference_brl) > 0.01
    ) AS orders_with_difference,
    COUNT(*) FILTER (
        WHERE difference_brl > 0.01
    ) AS payment_above_item_total,
    COUNT(*) FILTER (
        WHERE difference_brl < -0.01
    ) AS payment_below_item_total,
    ROUND(AVG(difference_brl), 2)
        AS average_signed_difference_brl,
    ROUND(AVG(ABS(difference_brl)), 2)
        AS average_absolute_difference_brl,
    ROUND(MAX(ABS(difference_brl)), 2)
        AS largest_absolute_difference_brl
FROM matched_single_payment_orders
GROUP BY payment_installments
ORDER BY payment_installments;






WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value
    FROM public.olist_order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        COUNT(*) AS payment_record_count,
        MAX(payment_installments) AS payment_installments,
        SUM(payment_value) AS payment_value
    FROM public.olist_order_payments
    GROUP BY order_id
),
matched_single_payment_orders AS (
    SELECT
        p.payment_installments,
        p.payment_value
            - (i.merchandise_value + i.freight_value)
            AS difference_brl
    FROM item_totals AS i
    INNER JOIN payment_totals AS p
        ON i.order_id = p.order_id
    WHERE p.payment_record_count = 1
)
SELECT
    payment_installments,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE ABS(difference_brl) > 0.01
    ) AS orders_with_difference,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE ABS(difference_brl) > 0.01
        ) / NULLIF(COUNT(*), 0),
        3
    ) AS mismatch_rate_pct,
    ROUND(AVG(difference_brl) FILTER (
        WHERE ABS(difference_brl) > 0.01
    ), 2) AS avg_signed_difference_among_mismatches_brl,
    ROUND(AVG(ABS(difference_brl)) FILTER (
        WHERE ABS(difference_brl) > 0.01
    ), 2) AS avg_absolute_difference_among_mismatches_brl,
    ROUND(SUM(difference_brl) FILTER (
        WHERE ABS(difference_brl) > 0.01
    ), 2) AS total_signed_difference_among_mismatches_brl,
    ROUND(MAX(ABS(difference_brl)), 2)
        AS largest_absolute_difference_brl
FROM matched_single_payment_orders
GROUP BY payment_installments
ORDER BY payment_installments;








