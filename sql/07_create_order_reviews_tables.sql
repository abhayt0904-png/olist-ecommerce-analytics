CREATE TABLE olist_order_reviews (
    review_id TEXT,
    order_id TEXT,
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);



SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'olist_order_reviews'
ORDER BY ordinal_position;




SELECT
    COUNT(*) AS total_review_rows,
    COUNT(DISTINCT review_id) AS distinct_review_ids,
    COUNT(DISTINCT order_id) AS orders_with_reviews,
    COUNT(*) FILTER (
        WHERE review_id IS NULL
    ) AS missing_review_ids,
    COUNT(*) FILTER (
        WHERE order_id IS NULL
    ) AS missing_order_ids,
    COUNT(*) FILTER (
        WHERE review_score IS NULL
    ) AS missing_review_scores,
    COUNT(*) FILTER (
        WHERE review_score < 1 OR review_score > 5
    ) AS invalid_review_scores
FROM public.olist_order_reviews;




SELECT
    review_id,
    COUNT(*) AS occurrences
FROM public.olist_order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 10;



SELECT
    review_id,
    order_id,
    COUNT(*) AS occurrences
FROM public.olist_order_reviews
GROUP BY review_id, order_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;



SELECT
    COUNT(*) AS reviews_without_matching_order
FROM public.olist_order_reviews AS r
LEFT JOIN public.olist_orders AS o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;




ALTER TABLE public.olist_order_reviews
ADD CONSTRAINT pk_olist_order_reviews
PRIMARY KEY (review_id, order_id);



ALTER TABLE public.olist_order_reviews
ADD CONSTRAINT fk_olist_order_reviews_orders
FOREIGN KEY (order_id)
REFERENCES public.olist_orders (order_id);



SELECT
    conname AS constraint_name,
    contype AS constraint_type
FROM pg_constraint
WHERE conrelid = 'public.olist_order_reviews'::regclass
  AND contype IN ('p', 'f')
ORDER BY contype, conname;



SELECT 'olist_orders' AS table_name, COUNT(*) AS total_rows
FROM public.olist_orders

UNION ALL

SELECT 'olist_customers', COUNT(*)
FROM public.olist_customers

UNION ALL

SELECT 'olist_order_items', COUNT(*)
FROM public.olist_order_items

UNION ALL

SELECT 'olist_products', COUNT(*)
FROM public.olist_products

UNION ALL

SELECT 'olist_sellers', COUNT(*)
FROM public.olist_sellers

UNION ALL

SELECT 'olist_order_payments', COUNT(*)
FROM public.olist_order_payments

UNION ALL

SELECT 'olist_order_reviews', COUNT(*)
FROM public.olist_order_reviews

ORDER BY table_name;