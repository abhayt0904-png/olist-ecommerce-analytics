CREATE TABLE olist_products (
    product_id TEXT PRIMARY KEY,
    product_category_name TEXT,
    product_name_lenght NUMERIC,
    product_description_lenght NUMERIC,
    product_photos_qty NUMERIC,
    product_weight_g NUMERIC,
    product_length_cm NUMERIC,
    product_height_cm NUMERIC,
    product_width_cm NUMERIC
);



SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'olist_products'
ORDER BY ordinal_position;




SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS distinct_products
FROM public.olist_products;



SELECT *
FROM public.olist_products
LIMIT 5;



SELECT
    COUNT(*) AS total_products,
    COUNT(*) FILTER (
        WHERE product_category_name IS NULL
    ) AS missing_categories,
    COUNT(*) FILTER (
        WHERE product_name_lenght IS NULL
    ) AS missing_name_lengths,
    COUNT(*) FILTER (
        WHERE product_description_lenght IS NULL
    ) AS missing_description_lengths,
    COUNT(*) FILTER (
        WHERE product_weight_g IS NULL
    ) AS missing_weights,
    COUNT(*) FILTER (
        WHERE product_length_cm IS NULL
           OR product_height_cm IS NULL
           OR product_width_cm IS NULL
    ) AS products_missing_any_dimension
FROM public.olist_products;




SELECT COUNT(*) AS items_without_matching_product
FROM public.olist_order_items AS oi
LEFT JOIN public.olist_products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;



ALTER TABLE public.olist_order_items
ADD CONSTRAINT fk_olist_order_items_products
FOREIGN KEY (product_id)
REFERENCES public.olist_products (product_id);

