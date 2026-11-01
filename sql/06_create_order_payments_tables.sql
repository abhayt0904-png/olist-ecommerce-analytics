CREATE TABLE olist_order_payments (
    order_id TEXT NOT NULL,
    payment_sequential INTEGER NOT NULL,
    payment_type TEXT NOT NULL,
    payment_installments INTEGER NOT NULL,
    payment_value NUMERIC(12,2) NOT NULL,

    CONSTRAINT pk_olist_order_payments
        PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_olist_order_payments_orders
        FOREIGN KEY (order_id)
        REFERENCES public.olist_orders (order_id)
);



SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'olist_order_payments'
ORDER BY ordinal_position;




SELECT
    COUNT(*) AS total_payment_records,
    COUNT(DISTINCT order_id) AS orders_with_payment_records
FROM public.olist_order_payments;



SELECT *
FROM public.olist_order_payments
LIMIT 10;



SELECT
    COUNT(*) AS payments_without_matching_order
FROM public.olist_order_payments AS p
LEFT JOIN public.olist_orders AS o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;



SELECT
    payment_type,
    COUNT(*) AS payment_records,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM public.olist_order_payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;