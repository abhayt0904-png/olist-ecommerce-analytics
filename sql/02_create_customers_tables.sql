CREATE TABLE olist_customers (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT NOT NULL,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT
);



SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'olist_customers'
ORDER BY ordinal_position;


SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS distinct_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS distinct_real_customers
FROM public.olist_customers;



SELECT COUNT(*) AS orders_without_customer_record
FROM public.olist_orders AS o
LEFT JOIN public.olist_customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;






-- Check foreign keys on the orders table

SELECT
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'public.olist_orders'::regclass
  AND conname = 'fk_olist_orders_customers'
  AND contype = 'f';


 
-- Add customer foreign key to orders

ALTER TABLE public.olist_orders
ADD CONSTRAINT fk_olist_orders_customers
FOREIGN KEY (customer_id)
REFERENCES public.olist_customers (customer_id);
