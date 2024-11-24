----Schema----
DROP TABLE IF EXISTS olist_customers;
CREATE TABLE IF EXISTS olist_customers(
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(50),
    customer_state VARCHAR(10)
);

DROP TABLE IF EXISTS olist_geolocation;
CREATE TABLE olist_geolocation(
    geolocation_zip_code_prefix INT,
    geolocation_lat DECIMAL,
    geolocation_lng DECIMAL,
    geolocation_city VARCHAR(50),
    geolocation_state VARCHAR(10)
);

DROP TABLE IF EXISTS olist_order_items;
CREATE TABLE olist_order_items(
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date TIMESTAMP,
    price DECIMAL(10, 2),
    freight_value DECIMAL(10, 2)
);

DROP TABLE IF EXISTS olist_order_payments;
CREATE TABLE olist_order_payments(
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(10,2)
);

DROP TABLE IF EXISTS olist_orders;
CREATE TABLE olist_orders(
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(15),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

DROP TABLE IF EXISTS olist_order_ratings;
CREATE TABLE olist_order_ratings(
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_answer_timestamp TIMESTAMP
);

DROP TABLE IF EXISTS olist_sellers;
CREATE TABLE olist_sellers(
    seller_id VARCHAR(50),
    seller_zip_code_prefix INT,
    seller_city VARCHAR(50),
    seller_state VARCHAR(10)
);

DROP TABLE IF EXISTS olist_products;
CREATE TABLE olist_products(
    product_id VARCHAR(50),
    product_category_name_pt VARCHAR(50),
    product_category_name_eng VARCHAR(50)
);


-------------------Business Problems-----------------------------
--1. Total Orders by Day of the Week
SELECT 
    COUNT(order_id) AS total_orders,
    TO_CHAR(order_purchase_timestamp, 'Day') AS day_of_week
FROM
    olist_orders
GROUP BY
    day_of_week
ORDER BY 
    total_orders DESC;

--2. Top 10 Product Categories by Total Sales
SELECT
    P.product_category_name_eng AS category,
    ROUND(SUM(Py.payment_value)) AS total_sales
FROM
    olist_products P
INNER JOIN
    olist_order_items O
ON
    P.product_id = O.product_id
INNER JOIN
    olist_order_payments Py
ON 
    O.order_id = Py.order_id
GROUP BY
    P.product_category_name_eng
ORDER BY 
    total_sales DESC
LIMIT 10;


--3. Payment Type Distribution (% by Payment Method)
WITH PaymentTypeSummary AS (
    SELECT 
        payment_type,
        COUNT(payment_type) AS total_payments_by_type
    FROM 
        olist_order_payments 
    WHERE
        payment_type != 'not_defined'
    GROUP BY
        payment_type
)
SELECT 
    payment_type,
    ROUND(total_payments_by_type * 100.0 / (SELECT SUM(total_payments_by_type) FROM PaymentTypeSummary), 2) AS payment_percentage
FROM 
    PaymentTypeSummary
ORDER BY 
    payment_percentage DESC;


--4. Top 5 Revenue-Generating Months (Seasonal Trends)
WITH total_sales AS (
    SELECT 
        INITCAP(TO_CHAR(O.order_purchase_timestamp, 'Month')) AS sales_month,
        EXTRACT(MONTH FROM O.order_purchase_timestamp) AS month_number,
        SUM(P.payment_value) AS total_sales
    FROM 
        olist_order_payments P
    INNER JOIN
        olist_orders O ON P.order_id = O.order_id
    WHERE 
        O.order_status = 'delivered' -- Focus on completed orders
    GROUP BY 
        TO_CHAR(O.order_purchase_timestamp, 'Month'),
        EXTRACT(MONTH FROM O.order_purchase_timestamp)
),
sales_rank AS (
    SELECT 
        sales_month, 
        total_sales,
        DENSE_RANK() OVER(ORDER BY total_sales DESC) AS revenue_rank
    FROM 
        total_sales
)
SELECT 
    revenue_rank AS rank, 
    sales_month,
    total_sales
FROM
    sales_rank
WHERE 
    revenue_rank <= 5
ORDER BY 
    rank;


--5. Top 10 States by Average Revenue per Order
WITH yearly_revenue AS (
    SELECT 
        COALESCE(C.customer_state, 'Unknown') AS state,
        EXTRACT(YEAR FROM O.order_purchase_timestamp) AS order_year,
        ROUND(SUM(P.payment_value) / COUNT(DISTINCT O.order_id), 2) AS avg_revenue_per_order
    FROM 
        olist_order_payments P
    INNER JOIN 
        olist_orders O ON P.order_id = O.order_id
    INNER JOIN
        olist_customers C ON O.customer_id = C.customer_id
    WHERE 
        O.order_status = 'delivered' -- Ensures only completed orders are considered
    GROUP BY
        C.customer_state,
        EXTRACT(YEAR FROM O.order_purchase_timestamp)
),
revenue_rank AS (
    SELECT 
        state,
        order_year,
        avg_revenue_per_order,
        DENSE_RANK() OVER (PARTITION BY order_year ORDER BY avg_revenue_per_order DESC) AS revenue_rank
    FROM 
        yearly_revenue
)
SELECT 
    order_year,
    state AS customer_state,
    avg_revenue_per_order,
    revenue_rank
FROM  
    revenue_rank
WHERE 
    revenue_rank <= 10
ORDER BY
    order_year, 
    revenue_rank;


--6. Impact of Delivery Timeliness on Review Scores
WITH delivery_analysis AS (
    SELECT 
        O.order_id,
        CASE 
            WHEN O.order_delivered_customer_date > O.order_estimated_delivery_date THEN 'Delayed'
            ELSE 'On-Time'
        END AS delivery_status,
        R.review_score
    FROM 
        olist_orders O
    INNER JOIN
        olist_order_ratings R ON O.order_id = R.order_id
    WHERE 
        O.order_status = 'delivered'
        AND O.order_delivered_customer_date IS NOT NULL
        AND O.order_estimated_delivery_date IS NOT NULL
)
SELECT 
    delivery_status,
    COUNT(delivery_status) AS total_instances,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM  
    delivery_analysis
GROUP BY 
    delivery_status
ORDER BY 
    avg_review_score DESC;


--7. Analysis of Negative Review Rates by Product Category
WITH negative_reviews AS (
    SELECT
        COALESCE(P.product_category_name_eng, 'Unknown') AS product_category_name,
        COUNT(R.review_id) AS total_reviews,
        SUM(CASE WHEN R.review_score <= 2 THEN 1 ELSE 0 END) AS negative_reviews
    FROM  
        olist_products P
    INNER JOIN
        olist_order_items OI ON P.product_id = OI.product_id
    INNER JOIN
        olist_order_ratings R ON OI.order_id = R.order_id
    GROUP BY
        P.product_category_name_eng
    HAVING 
        COUNT(R.review_id) >= 10 -- Exclude categories with fewer than 10 reviews
),
negative_review_rate AS (
    SELECT 
        product_category_name,
        total_reviews,
        negative_reviews,
        ROUND((negative_reviews * 100.0) / total_reviews, 2) AS negative_review_rate
    FROM 
        negative_reviews
)
SELECT  
    product_category_name,
    total_reviews,
    negative_reviews,
    CONCAT(negative_review_rate, '%') AS formatted_negative_review_rate
FROM 
    negative_review_rate
ORDER BY
    negative_review_rate DESC
LIMIT 30;


--8. Average Shipping Cost by Delivery Time Category
WITH total_delivery_time AS (
    SELECT 
        O.order_id,
        ROUND(
            EXTRACT(DAY FROM (O.order_delivered_customer_date - O.order_purchase_timestamp)) +  
            EXTRACT(HOUR FROM (O.order_delivered_customer_date - O.order_purchase_timestamp)) / 24, 
            2
        ) AS total_delivery_time,
        OI.Shipping_cost
    FROM 
        olist_orders O
    INNER JOIN 
        olist_order_items OI
    ON 
        O.order_id = OI.order_id
),
delivery_times AS (
    SELECT 
        total_delivery_time, 
        shipping_cost,
        CASE 
            WHEN total_delivery_time BETWEEN 0 AND 3 THEN '0-3 days'
            WHEN total_delivery_time BETWEEN 3 AND 7 THEN '3-7 days'
            WHEN total_delivery_time BETWEEN 7 AND 14 THEN '7-14 days'
            ELSE '14+ days'
        END AS delivery_time_category
    FROM 
        total_delivery_time
)
SELECT 
    delivery_time_category, 
    ROUND(AVG(shipping_cost), 2) AS average_shipping_cost
FROM 
    delivery_times
GROUP BY 
    delivery_time_category
ORDER BY 
    average_shipping_cost DESC;

--9.Seller Performance Analysis

SELECT 
    OI.seller_id,
    SUM(P.payment_value) AS total_revenue,
    ROUND(AVG(R.review_score), 2) AS avg_rating,
    COUNT(DISTINCT OI.order_id) AS order_count
FROM
    olist_order_items OI
INNER JOIN
    olist_order_ratings R ON OI.order_id = R.order_id
INNER JOIN
    olist_order_payments P ON OI.order_id = P.order_id
GROUP BY
    OI.seller_id
HAVING
    COUNT(DISTINCT OI.order_id) >= 25
ORDER BY
    avg_rating DESC
LIMIT 30;


--10. Identifying Top 10% Customers by Lifetime Value (LTV)

WITH customer_ltv AS (
    SELECT 
        customer_unique_id,
        SUM(payment_value) AS lifetime_value
    FROM 
        olist_order_payments P
    INNER JOIN
        olist_orders O
    ON 
        P.order_id = O.order_id
    INNER JOIN
        olist_customers C
    ON
        O.customer_id = C.customer_id
    GROUP BY 
        customer_unique_id
),
ranked_customers AS (
    SELECT 
        customer_unique_id,
        lifetime_value,
        NTILE(10) OVER (ORDER BY lifetime_value DESC) AS percentile
    FROM 
        customer_ltv
)
SELECT 
    customer_unique_id, 
    lifetime_value
FROM 
    ranked_customers
WHERE 
    percentile = 1
ORDER BY 
    lifetime_value DESC;

--11.Customer Segmentation Using RFM Analysis

WITH RFM_Calculation AS (
    SELECT 
        customer_unique_id,
        EXTRACT(DAY FROM (DATE '2018-12-31' - MAX(O.order_purchase_timestamp))) AS recency,
        COUNT(DISTINCT O.order_id) AS frequency,
        SUM(payment_value) AS monetary
    FROM olist_order_payments P
    JOIN olist_orders O ON P.order_id = O.order_id
    JOIN olist_customers C ON O.customer_id = C.customer_id
    GROUP BY customer_unique_id
),
RFM_Scores AS (
    SELECT
        customer_unique_id,
        NTILE(5) OVER (ORDER BY recency ASC) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary DESC) AS monetary_score
    FROM 
        RFM_Calculation
)
SELECT 
    customer_unique_id,
    recency_score,
    frequency_score,
    monetary_score,
    (recency_score + frequency_score + monetary_score) AS total_score
FROM 
    RFM_Scores
ORDER BY 
    total_score DESC;


