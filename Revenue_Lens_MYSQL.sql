LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/cleaned_store_sales_data.csv'
INTO TABLE retail_sales
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;
#-------------------------------------------
SELECT COUNT(*) FROM retail_sales;
SELECT * FROM retail_sales;
# Changed Format DATETIME To DATE------------------------------------------
ALTER TABLE retail_sales_project.retail_sales
MODIFY COLUMN `Date of Birth` DATE,
MODIFY COLUMN `Sales Date` DATE,
MODIFY COLUMN `Order Date` DATE,
MODIFY COLUMN `Ship Date` DATE;
# Renamed All Columns ------------------------------------------------
ALTER TABLE retail_sales
    RENAME COLUMN `Customer ID` TO customer_id,
    RENAME COLUMN `Customer Name` TO customer_name,
    RENAME COLUMN `Last Name` TO last_name,
    RENAME COLUMN `Date of Birth` TO date_of_birth,
    RENAME COLUMN `Sales` TO sales,
    RENAME COLUMN `Year` TO year,
    RENAME COLUMN `Outlet Type` TO outlet_type,
    RENAME COLUMN `City Type` TO city_type,
    RENAME COLUMN `Category of Goods` TO category_of_goods,
    RENAME COLUMN `Region` TO region,
    RENAME COLUMN `Country` TO country,
    RENAME COLUMN `Segment` TO segment,
    RENAME COLUMN `Sales Date` TO sales_date,
    RENAME COLUMN `Order ID` TO order_id,
    RENAME COLUMN `Order Date` TO order_date,
    RENAME COLUMN `Ship Date` TO ship_date,
    RENAME COLUMN `Ship Mode` TO ship_mode,
    RENAME COLUMN `State` TO state,
    RENAME COLUMN `Postal Code` TO postal_code,
    RENAME COLUMN `Product ID` TO product_id,
    RENAME COLUMN `Sub-Category` TO sub_category,
    RENAME COLUMN `Product Name` TO product_name,
    RENAME COLUMN `Quantity` TO quantity,
    RENAME COLUMN `Discount` TO discount,
    RENAME COLUMN `Profit` TO profit;
#-----------------------------------------------------------------------------------
# Feature Engineering 1 - Customer Age--------
ALTER TABLE retail_sales
ADD COLUMN customer_age INT;

UPDATE retail_sales
SET customer_age = TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE());

# Feature 2 – Shipping Days ---------------------------------------------
ALTER TABLE retail_sales
ADD COLUMN shipping_days INT;

UPDATE retail_sales
SET shipping_days = DATEDIFF(ship_date, order_date);

# Feature 3 – Profit Margin (%)-------------------------------------------
ALTER TABLE retail_sales
ADD COLUMN profit_margin DECIMAL(8,2);

UPDATE retail_sales
SET profit_margin =
CASE
    WHEN sales = 0 THEN 0
    ELSE ROUND((profit / sales) * 100,2)
END;

# Feature 4 – Discount Category --------------------------------------------
ALTER TABLE retail_sales
ADD COLUMN discount_category VARCHAR(20);

UPDATE retail_sales
SET discount_category =
CASE

WHEN discount = 0 THEN 'No Discount'

WHEN discount <= 0.10 THEN 'Low'

WHEN discount <= 0.30 THEN 'Medium'

ELSE 'High'

END;

# Feature 5 – Order Month --------------------------------------------------
ALTER TABLE retail_sales
ADD COLUMN order_month VARCHAR(20);

UPDATE retail_sales
SET order_month = MONTHNAME(order_date);

# Feature 6 – Order Quarter ------------------------------------------------
ALTER TABLE retail_sales
ADD COLUMN order_quarter VARCHAR(5);

UPDATE retail_sales
SET order_quarter = CONCAT('Q',QUARTER(order_date));

# Feature 7 – Order Weekday ---------------------------------------------------
ALTER TABLE retail_sales
ADD COLUMN order_day VARCHAR(20);

UPDATE retail_sales
SET order_day = DAYNAME(order_date);

# Feature 8 – Profit Status ---------------------------------------------------
ALTER TABLE retail_sales
ADD COLUMN profit_status VARCHAR(15);

UPDATE retail_sales
SET profit_status =
CASE

WHEN profit > 0 THEN 'Profit'

WHEN profit < 0 THEN 'Loss'

ELSE 'Break Even'

END;

# Verify the Engineered Features -----------------------------------------------
SELECT
customer_name,
sales,
profit,
profit_margin,
shipping_days,
customer_age,
discount_category,
profit_status,
order_month,
order_quarter
FROM retail_sales
LIMIT 10;

# Query 1 – Top 10 Products by Sales -----------------------------------------
SELECT
product_name,
SUM(sales) AS total_sales
FROM retail_sales
GROUP BY product_name
ORDER BY total_sales DESC
LIMIT 10;

# Query 2 – Top Customers by Profit ------------------------------------------------
SELECT
customer_name,
SUM(profit) AS total_profit
FROM retail_sales
GROUP BY customer_name
ORDER BY total_profit DESC;

# Query 3 – Average Shipping Days by Region --------------------------------------------
SELECT
region,
ROUND(AVG(shipping_days),2) AS avg_shipping_days
FROM retail_sales
GROUP BY region
ORDER BY avg_shipping_days;

# Query 4 – Profit Margin by Category -----------------------------------------
SELECT
category_of_goods,
ROUND(AVG(profit_margin),2) AS avg_margin
FROM retail_sales
GROUP BY category_of_goods
ORDER BY avg_margin DESC;

# Query 5 – Monthly Sales Trend ----------------------------------------------------
SELECT
order_month,
SUM(sales) AS total_sales
FROM retail_sales
GROUP BY order_month
ORDER BY MIN(order_date);

# (Advanced Query) CTE – State-wise Profit
WITH state_profit AS (
    SELECT
        state,
        SUM(profit) AS total_profit
    FROM retail_sales
    GROUP BY state
)
SELECT *
FROM state_profit
ORDER BY total_profit DESC;

# Window Function – Product Ranking --------------------------------------------
SELECT
category_of_goods,
product_name,
SUM(sales) AS total_sales,
RANK() OVER (
PARTITION BY category_of_goods
ORDER BY SUM(sales) DESC
) AS product_rank
FROM retail_sales
GROUP BY category_of_goods, product_name;

# Window Function – Running Sales ------------------------------------
SELECT
order_date,
sales,
SUM(sales) OVER(
ORDER BY order_date
) AS cumulative_sales
FROM retail_sales;

# Window Function – Month-over-Month Sales ----------------------------------
WITH monthly_sales AS
(
SELECT
DATE_FORMAT(order_date,'%Y-%m') AS month,
SUM(sales) AS total_sales
FROM retail_sales
GROUP BY month
)

SELECT
month,
total_sales,
LAG(total_sales) OVER(
ORDER BY month
) AS previous_month
FROM monthly_sales;

# VIEW 1 — Sales Summary View ---------------------------------------------------------------
CREATE OR REPLACE VIEW vw_sales_summary AS
SELECT
    order_id,
    order_date,
    sales_date,
    ship_date,
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month_num,
    MONTHNAME(order_date) AS order_month_name,
    QUARTER(order_date) AS order_quarter_num,
    CONCAT('Q', QUARTER(order_date)) AS order_quarter,
    DAYNAME(order_date) AS order_day_name,

    customer_id,
    customer_name,
    segment,

    region,
    state,
    country,
    city_type,
    outlet_type,
    ship_mode,

    category_of_goods,
    sub_category,
    product_id,
    product_name,

    sales,
    quantity,
    discount,
    profit,
    shipping_days,
    profit_margin,
    discount_category,
    profit_status
FROM retail_sales;

# VIEW 2 — Customer Analysis View ----------------------------------------------------------
CREATE OR REPLACE VIEW vw_customer_analysis AS
SELECT
    customer_id,
    customer_name,
    last_name,
    segment,
    region,
    state,
    country,
    city_type,
    outlet_type,
    customer_age,

    COUNT(DISTINCT order_id) AS total_orders,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    SUM(quantity) AS total_quantity,
    AVG(discount) AS avg_discount,
    ROUND(AVG(profit_margin), 2) AS avg_profit_margin,
    ROUND(AVG(shipping_days), 2) AS avg_shipping_days,

    CASE
        WHEN SUM(sales) = 0 THEN 0
        ELSE ROUND(SUM(sales) / COUNT(DISTINCT order_id), 2)
    END AS avg_order_value

FROM retail_sales
GROUP BY
    customer_id,
    customer_name,
    last_name,
    segment,
    region,
    state,
    country,
    city_type,
    outlet_type,
    customer_age;
    
# VIEW 3 — Product Performance View ----------------------------------------------------------
CREATE OR REPLACE VIEW vw_product_performance AS
SELECT
    product_id,
    product_name,
    category_of_goods,
    sub_category,

    COUNT(DISTINCT order_id) AS total_orders,
    SUM(quantity) AS total_quantity_sold,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    ROUND(AVG(discount), 2) AS avg_discount,
    ROUND(AVG(profit_margin), 2) AS avg_profit_margin,
    ROUND(AVG(shipping_days), 2) AS avg_shipping_days,

    CASE
        WHEN SUM(quantity) = 0 THEN 0
        ELSE ROUND(SUM(sales) / SUM(quantity), 2)
    END AS avg_selling_price_per_unit

FROM retail_sales
GROUP BY
    product_id,
    product_name,
    category_of_goods,
    sub_category;
    
# VIEW 4 — Shipping Performance View
CREATE OR REPLACE VIEW vw_shipping_performance AS
SELECT
    ship_mode,
    region,
    state,
    country,
    city_type,
    outlet_type,

    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(AVG(shipping_days), 2) AS avg_shipping_days,
    MAX(shipping_days) AS max_shipping_days,
    MIN(shipping_days) AS min_shipping_days,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit

FROM retail_sales
GROUP BY
    ship_mode,
    region,
    state,
    country,
    city_type,
    outlet_type;
    
# VIEW 5 — Monthly Business Trend View
CREATE VIEW vw_monthly_trends AS
SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS month_key,
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month_num,
    MONTHNAME(order_date) AS order_month_name,
    QUARTER(order_date) AS order_quarter_num,

    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    SUM(quantity) AS total_quantity,
    ROUND(AVG(discount), 2) AS avg_discount,
    ROUND(AVG(profit_margin), 2) AS avg_profit_margin,
    ROUND(AVG(shipping_days), 2) AS avg_shipping_days,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customers

FROM retail_sales
GROUP BY
    DATE_FORMAT(order_date, '%Y-%m'),
    YEAR(order_date),
    MONTH(order_date),
    MONTHNAME(order_date),
    QUARTER(order_date);
# All Views Final Check --------------------------------------------------------------
SELECT * FROM vw_sales_summary LIMIT 10;
SELECT * FROM vw_customer_analysis LIMIT 10;
SELECT * FROM vw_product_performance LIMIT 10;
SELECT * FROM vw_shipping_performance LIMIT 10;
SELECT * FROM vw_monthly_trends LIMIT 10;

#----------------------------------(Project Successfully Completed)-----------------------------------------

