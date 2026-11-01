CREATE TABLE olist_sellers (
    seller_id TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT NOT NULL,
    seller_city TEXT NOT NULL,
    seller_state TEXT NOT NULL
);



SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'olist_sellers'
ORDER BY ordinal_position;





SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT seller_id) AS distinct_seller_ids
FROM public.olist_sellers;



SELECT *
FROM public.olist_sellers
LIMIT 10;



SELECT
    COUNT(*) AS total_sellers,
    COUNT(*) FILTER (
        WHERE seller_zip_code_prefix IS NULL
    ) AS missing_zip_codes,
    COUNT(*) FILTER (
        WHERE seller_city IS NULL
    ) AS missing_cities,
    COUNT(*) FILTER (
        WHERE seller_state IS NULL
    ) AS missing_states
FROM public.olist_sellers;



SELECT
    COUNT(*) AS items_without_matching_seller
FROM public.olist_order_items AS oi
LEFT JOIN public.olist_sellers AS s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;



ALTER TABLE public.olist_order_items
ADD CONSTRAINT fk_olist_order_items_sellers
FOREIGN KEY (seller_id)
REFERENCES public.olist_sellers (seller_id);