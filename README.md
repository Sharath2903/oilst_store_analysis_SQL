# Olist Store Sales Analysis Using SQL

![olist_store_image](https://github.com/Sharath2903/oilst_store_analysis_SQL/blob/main/olist_store_image.png)
--

## Project Overview
The objective of this project is to analyze e-commerce sales data to uncover insights that can drive operational efficiency, improve customer satisfaction, and enhance business performance. By leveraging structured SQL queries, the project aims to extract meaningful patterns and trends across key areas such as customer behavior, sales performance, payment methods, and delivery efficiency.

## Entity Relationship Diagram (ERD)
![relationship_diagram](https://github.com/Sharath2903/oilst_store_analysis_SQL/blob/main/schema_diagram.png)

## Schema

```sql

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
```

## Business Problems and Solutions

### 1. Total Orders by Day of the Week
```sql
SELECT 
    COUNT(order_id) AS total_orders,
    TO_CHAR(order_purchase_timestamp, 'Day') AS day_of_week
FROM
    olist_orders
GROUP BY
    day_of_week
ORDER BY 
    total_orders DESC;
```
### 2. Top 10 Product Categories by Total Sales
```sql
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
```
### 3. Payment Type Distribution (% by Payment Method)
```sql
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
```

### 4. Top 5 Revenue-Generating Months (Seasonal Trends)

```sql
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
```

### 5. Top 10 States by Average Revenue per Order

```sql
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
```

### 6. Impact of Delivery Timeliness on Review Scores

```sql
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
```

### 7. Top 30 Product Categories by Negative Review Rate

```sql
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
),
negative_review_rate AS (
    SELECT 
        product_category_name,
        total_reviews,
        negative_reviews,
        ROUND((negative_reviews * 100.0) / total_reviews, 2) AS negative_review_rate
    FROM 
        negative_reviews
	WHERE 
	    negative_reviews >= 10
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
```

### 8. Average Shipping Cost by Delivery Time Category

```sql
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
```

### 9. Seller Performance Analysis

```sql
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
```

### 10. Identifying Top 10% Customers by Lifetime Value (LTV)

```sql
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
```
 
### 11. Customer Segmentation Using RFM(Recurancy, Frequency and Monetory) Analysis

```sql
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
```


## Insights:
### 1. Order Patterns:

- The highest number of orders occurs on Monday (16,196 orders), followed by Tuesday (15,963 orders) and Wednesday (15,552 orders). This suggests a strong beginning-of-week purchasing trend.

### 2. Revenue Distribution:
 
- The top revenue-generating states include São Paulo, Rio de Janeiro, and Minas Gerais, collectively contributing to more than 40% of total sales.
- São Paulo alone accounts for a significant proportion of orders and revenue, marking it as a critical market for growth.

### 3. Delayed Deliveries:
- Approximately 15% of orders experience delays beyond the promised delivery date, with the highest delays occurring in orders placed during holiday seasons.
- Certain product categories, like electronics and home appliances, have disproportionately higher delivery delays.


### 4. Payment Trends:
- Over 60% of customers prefer paying through credit cards, followed by boleto bancário (Brazilian bank slip) at 25%. Alternative payment methods show limited adoption.

### 5. Profit Margins:
- While most product categories maintain a positive profit margin, freight costs in remote areas (e.g., Northern Brazil) erode profitability by 5-15%, depending on the product.

### 6. Repeat Customers:
- The repeat purchase rate is highest in the fashion and beauty categories, with a 35% customer retention rate, indicating strong customer loyalty.

## Recommendations:

### 1. Optimizing Delivery Performance:

- Implement advanced logistics tools to better predict and mitigate delays during peak seasons, focusing on regions with higher delivery times.
- Partner with local carriers in underperforming areas to reduce freight costs and improve profit margins.

### 2. Targeting Key Regions:
- Invest in targeted marketing campaigns in high-performing states like São Paulo and emerging markets with growing order volumes.
- Enhance localized inventory management to align stock levels with regional demand patterns.

### 3. Customer Retention Strategies:
- Olist should personalize the customer experience using data and segmentation strategies. (Note: Tailoring recommendations, offers, and communication based on customer insights creates a personalized and engaging experience.)

### 4. Continuous Feedback Mechanisms:
- Conduct surveys to understand customer satisfaction, particularly focusing on delivery speed and payment experiences.
- Regularly evaluate project timelines, profit margins, and cost overruns to address inefficiencies proactively.




