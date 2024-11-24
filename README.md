# Olist Store Sales Analysis Using SQL

![image](https://github.com/tolamoye/Olist-E-commerce-Data-Aanalysis/assets/128150171/b57e7bae-89a7-4b4f-84cc-449cbd1912e3)
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
