CREATE TABLE olist_orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    order_status TEXT NOT NULL,
    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);



SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'olist_orders'
ORDER BY ordinal_position;





SELECT COUNT(*) AS total_orders
FROM public.olist_orders;


SELECT *
FROM public.olist_orders
LIMIT 5;


SELECT order_id, COUNT(*) AS occurrences
FROM public.olist_orders
GROUP BY order_id
HAVING COUNT(*) > 1;
