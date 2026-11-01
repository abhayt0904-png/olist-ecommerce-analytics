CREATE TABLE olist_order_items (
    order_id TEXT NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id TEXT NOT NULL,
    seller_id TEXT NOT NULL,
    shipping_limit_date TIMESTAMP NOT NULL,
    price NUMERIC(12,2) NOT NULL,
    freight_value NUMERIC(12,2) NOT NULL,

    CONSTRAINT pk_olist_order_items
        PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_olist_order_items_orders
        FOREIGN KEY (order_id)
        REFERENCES public.olist_orders (order_id)
);




SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'olist_order_items'
ORDER BY ordinal_position;



SELECT COUNT(*) AS total_order_items
FROM public.olist_order_items;


SELECT COUNT(DISTINCT order_id) AS orders_with_items
FROM public.olist_order_items;


SELECT COUNT(*) AS items_without_matching_order
FROM public.olist_order_items AS oi
LEFT JOIN public.olist_orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;



SELECT *
FROM public.olist_order_items
LIMIT 10;


