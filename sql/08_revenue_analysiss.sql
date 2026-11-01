SELECT
    order_status,
    COUNT(*) AS total_orders
FROM public.olist_orders
GROUP BY order_status
ORDER BY total_orders DESC;



SELECT
    MIN(order_purchase_timestamp) AS earliest_purchase,
    MAX(order_purchase_timestamp) AS latest_purchase,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE order_purchase_timestamp IS NULL
    ) AS missing_purchase_timestamps
FROM public.olist_orders;





SELECT
    COUNT(*) AS total_item_rows,
    COUNT(DISTINCT order_id) AS distinct_orders_with_items,
    ROUND(SUM(price), 2) AS merchandise_value_all_statuses_brl,
    ROUND(SUM(freight_value), 2) AS freight_value_all_statuses_brl,
    ROUND(
        SUM(price) + SUM(freight_value), 2
    ) AS merchandise_plus_freight_brl,
    ROUND(
        SUM(price) / NULLIF(COUNT(DISTINCT order_id), 0),
        2
    ) AS avg_merchandise_value_per_order_brl
FROM public.olist_order_items;





SELECT
    COUNT(*) AS delivered_item_rows,
    COUNT(DISTINCT oi.order_id) AS delivered_orders_with_items,
    ROUND(SUM(oi.price), 2) AS delivered_gmv_brl,
    ROUND(SUM(oi.freight_value), 2) AS delivered_freight_brl,
    ROUND(
        SUM(oi.price) / NULLIF(COUNT(DISTINCT oi.order_id), 0),
        2
    ) AS delivered_aov_brl
FROM public.olist_order_items AS oi
INNER JOIN public.olist_orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';






SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS purchase_month,
    COUNT(DISTINCT oi.order_id) AS delivered_orders_with_items,
    ROUND(SUM(oi.price), 2) AS delivered_gmv_brl,
    ROUND(SUM(oi.freight_value), 2) AS delivered_freight_brl,
    ROUND(
        SUM(oi.price) / NULLIF(COUNT(DISTINCT oi.order_id), 0),
        2
    ) AS delivered_aov_brl
FROM public.olist_order_items AS oi
INNER JOIN public.olist_orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)::date
ORDER BY purchase_month;



