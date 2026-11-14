-- ============================================================================
-- MYSQL CAPSTONE — every clause from the notes, run end-to-end on retail data
-- PREREQUISITE: run setup_mysql.sql FIRST (creates raw_sales, region_targets,
-- category_discounts) and load retail_sales_raw.csv into raw_sales.
-- This script assumes raw_sales already has its row_id auto-increment column.
-- ============================================================================

-- ---------- SECTION 0: SETUP ----------
SHOW DATABASES;
USE retail_practice;
SHOW TABLES;
DESCRIBE raw_sales;

-- ---------- SECTION 1: TABLE BASICS (CREATE / ALTER / DROP) ----------
CREATE TABLE IF NOT EXISTS capstone_sales LIKE raw_sales;   -- clone structure
INSERT INTO capstone_sales SELECT * FROM raw_sales;          -- copy data (work here, keep raw_sales untouched)

ALTER TABLE capstone_sales ADD COLUMN net_sales DECIMAL(14,2);   -- add column
ALTER TABLE capstone_sales MODIFY COLUMN customer_name VARCHAR(150);  -- widen column
-- ALTER TABLE capstone_sales DROP COLUMN net_sales;  -- (uncomment to test DROP)

-- ---------- SECTION 2: INSERT / UPDATE / DELETE ----------
INSERT INTO capstone_sales
  (order_id, order_date, customer_id, customer_name, region, segment, category, product, quantity, unit_price, sales, profit)
VALUES
  (9999, '2025-06-01', 'CUST9999', 'Ritesh Jajoria', 'North', 'Corporate', 'Electronics', 'Laptop', '2', 55000, 110000, 15000);

UPDATE capstone_sales SET unit_price = unit_price * 1.0 WHERE order_id = 9999;  -- no-op demo of UPDATE syntax
DELETE FROM capstone_sales WHERE order_id = 9999;  -- clean up the test row

-- ---------- SECTION 3: SELECT / FILTER / SORT ----------
SELECT * FROM capstone_sales LIMIT 10;
SELECT customer_name, sales FROM capstone_sales LIMIT 5;
SELECT DISTINCT region FROM capstone_sales;                       -- shows the mixed-case problem
SELECT * FROM capstone_sales WHERE sales > 100000 LIMIT 10;
SELECT * FROM capstone_sales WHERE region = 'North' AND sales > 50000 LIMIT 10;
SELECT * FROM capstone_sales WHERE category IN ('Electronics','Furniture') LIMIT 10;
SELECT * FROM capstone_sales WHERE customer_name LIKE 'R%' LIMIT 10;
SELECT * FROM capstone_sales WHERE customer_name LIKE '%esh%' LIMIT 10;
SELECT * FROM capstone_sales WHERE order_date BETWEEN '2024-01-01' AND '2024-12-31' LIMIT 10;
SELECT * FROM capstone_sales WHERE customer_name IS NULL OR customer_name = '' LIMIT 10;
SELECT * FROM capstone_sales ORDER BY sales DESC LIMIT 10;
SELECT * FROM capstone_sales ORDER BY region ASC, sales DESC LIMIT 10;
SELECT * FROM capstone_sales LIMIT 10 OFFSET 20;                   -- pagination

SELECT customer_name AS employee_name, sales, sales * 12 AS annualized
FROM capstone_sales AS c LIMIT 5;                                   -- aliasing

-- ---------- SECTION 4: CLEANING WITH SQL ----------
-- 4a. Standardize casing on Region and Category
UPDATE capstone_sales
SET region = CASE
    WHEN LOWER(region) = 'north' THEN 'North'
    WHEN LOWER(region) = 'south' THEN 'South'
    WHEN LOWER(region) = 'east'  THEN 'East'
    WHEN LOWER(region) = 'west'  THEN 'West'
    ELSE region END;

UPDATE capstone_sales
SET category = CASE
    WHEN LOWER(category) = 'furniture'   THEN 'Furniture'
    WHEN LOWER(category) = 'electronics' THEN 'Electronics'
    WHEN LOWER(category) = 'clothing'    THEN 'Clothing'
    WHEN LOWER(category) = 'groceries'   THEN 'Groceries'
    WHEN LOWER(category) = 'stationery'  THEN 'Stationery'
    ELSE category END;

SELECT DISTINCT region FROM capstone_sales;      -- confirm now clean: 4 values only
SELECT DISTINCT category FROM capstone_sales;

-- 4b. Find duplicate Order_IDs
SELECT order_id, COUNT(*) AS cnt
FROM capstone_sales GROUP BY order_id HAVING COUNT(*) > 1;

-- 4c. Remove exact duplicate rows (keep lowest row_id)
DELETE t1 FROM capstone_sales t1
JOIN capstone_sales t2
  ON t1.order_id = t2.order_id
 AND t1.customer_id = t2.customer_id
 AND t1.sales = t2.sales
 AND t1.row_id > t2.row_id;

-- 4d. Find nulls / blanks
SELECT * FROM capstone_sales WHERE customer_name IS NULL OR customer_name = '';
SELECT * FROM capstone_sales WHERE profit IS NULL;

-- 4e. Clean Quantity ("5 units" -> 5)
UPDATE capstone_sales
SET quantity = CAST(REGEXP_SUBSTR(quantity, '^[0-9]+') AS UNSIGNED);

-- 4f. Standardize text (trim + upper, generic pattern)
UPDATE capstone_sales SET customer_name = TRIM(customer_name);

-- 4g. Find orphan foreign keys (region not present in lookup table)
SELECT c.* FROM capstone_sales c
LEFT JOIN region_targets r ON c.region = r.region
WHERE r.region IS NULL;

-- ---------- SECTION 5: AGGREGATION & GROUPING ----------
SELECT COUNT(*) FROM capstone_sales;
SELECT region, COUNT(*) AS headcount FROM capstone_sales GROUP BY region;
SELECT region, SUM(sales) AS total_sales, AVG(sales) AS avg_sales,
       MIN(sales) AS min_sales, MAX(sales) AS max_sales
FROM capstone_sales GROUP BY region;
SELECT region, AVG(profit) AS avg_profit
FROM capstone_sales GROUP BY region
HAVING AVG(profit) > 20000
ORDER BY avg_profit DESC;

-- ---------- SECTION 6: JOINS ----------
SELECT c.order_id, c.region, t.regional_manager
FROM capstone_sales c
INNER JOIN region_targets t ON c.region = t.region
LIMIT 10;

SELECT c.order_id, c.region, t.regional_manager
FROM capstone_sales c
LEFT JOIN region_targets t ON c.region = t.region
LIMIT 10;

SELECT c.order_id, c.category, d.discount_rate
FROM capstone_sales c
RIGHT JOIN category_discounts d ON c.category = d.category
LIMIT 10;

-- SELF JOIN demo: pair each order with another order in the same region (sample logic)
SELECT a.order_id AS order_a, b.order_id AS order_b, a.region
FROM capstone_sales a
JOIN capstone_sales b ON a.region = b.region AND a.order_id < b.order_id
LIMIT 5;

-- Multiple joins together
SELECT c.order_id, c.region, t.regional_manager, d.discount_rate
FROM capstone_sales c
JOIN region_targets t ON c.region = t.region
JOIN category_discounts d ON c.category = d.category
LIMIT 10;

-- FULL OUTER JOIN simulated with UNION (MySQL has no native FULL JOIN)
SELECT c.order_id, t.regional_manager FROM capstone_sales c
LEFT JOIN region_targets t ON c.region = t.region
UNION
SELECT c.order_id, t.regional_manager FROM capstone_sales c
RIGHT JOIN region_targets t ON c.region = t.region
LIMIT 10;

-- ---------- SECTION 7: SUBQUERIES & CTEs ----------
-- Subquery in WHERE
SELECT customer_name, sales FROM capstone_sales
WHERE sales > (SELECT AVG(sales) FROM capstone_sales);

-- Correlated subquery: highest sale in each region
SELECT c1.order_id, c1.region, c1.sales
FROM capstone_sales c1
WHERE c1.sales = (SELECT MAX(c2.sales) FROM capstone_sales c2 WHERE c2.region = c1.region);

-- Subquery in FROM (derived table)
SELECT region, avg_sales FROM (
    SELECT region, AVG(sales) AS avg_sales FROM capstone_sales GROUP BY region
) AS region_avg
WHERE avg_sales > 100000;

-- CTE
WITH region_summary AS (
    SELECT region, AVG(sales) AS avg_sales, COUNT(*) AS orders
    FROM capstone_sales GROUP BY region
)
SELECT * FROM region_summary WHERE orders > 50 ORDER BY avg_sales DESC;

-- ---------- SECTION 8: WINDOW FUNCTIONS ----------
SELECT order_id, region, sales,
       ROW_NUMBER() OVER (PARTITION BY region ORDER BY sales DESC) AS rn,
       RANK()       OVER (PARTITION BY region ORDER BY sales DESC) AS rnk,
       DENSE_RANK() OVER (PARTITION BY region ORDER BY sales DESC) AS drnk
FROM capstone_sales
LIMIT 20;

SELECT order_date, sales,
       SUM(sales) OVER (ORDER BY order_date) AS running_total
FROM capstone_sales
ORDER BY order_date
LIMIT 20;

SELECT order_date, sales,
       AVG(sales) OVER (ORDER BY order_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3
FROM capstone_sales
ORDER BY order_date
LIMIT 20;

SELECT order_date, sales,
       LAG(sales, 1)  OVER (ORDER BY order_date) AS prev_sales,
       LEAD(sales, 1) OVER (ORDER BY order_date) AS next_sales
FROM capstone_sales
ORDER BY order_date
LIMIT 20;

-- Top 3 products per region
WITH ranked AS (
    SELECT region, product, SUM(sales) AS total_sales,
           ROW_NUMBER() OVER (PARTITION BY region ORDER BY SUM(sales) DESC) AS rn
    FROM capstone_sales
    GROUP BY region, product
)
SELECT * FROM ranked WHERE rn <= 3;

-- ---------- SECTION 9: STRING / DATE / CONDITIONAL FUNCTIONS ----------
SELECT UPPER(customer_name), LOWER(customer_name) FROM capstone_sales LIMIT 5;
SELECT TRIM(customer_name) FROM capstone_sales LIMIT 5;
SELECT LENGTH(customer_name) FROM capstone_sales LIMIT 5;
SELECT SUBSTRING(customer_name, 1, 3) FROM capstone_sales LIMIT 5;
SELECT LEFT(customer_name, 1) AS initial FROM capstone_sales LIMIT 5;
SELECT REPLACE(category, 'Furniture', 'Home Furniture') FROM capstone_sales LIMIT 5;

SELECT NOW(), CURDATE();
SELECT DATE_FORMAT(order_date, '%Y-%m-%d') FROM capstone_sales LIMIT 5;
SELECT YEAR(order_date), MONTH(order_date), DAY(order_date) FROM capstone_sales LIMIT 5;
SELECT DATEDIFF(CURDATE(), order_date) AS days_since_order FROM capstone_sales LIMIT 5;
SELECT DATE_ADD(order_date, INTERVAL 1 YEAR) FROM capstone_sales LIMIT 5;
SELECT DATE_SUB(CURDATE(), INTERVAL 30 DAY);

SELECT order_id, sales,
    CASE WHEN sales >= 200000 THEN 'High'
         WHEN sales >= 50000  THEN 'Medium'
         ELSE 'Low' END AS sales_band
FROM capstone_sales LIMIT 10;

SELECT order_id, IFNULL(customer_name, 'Unknown') AS customer_name FROM capstone_sales LIMIT 10;
SELECT order_id, COALESCE(profit, unit_price, 0) AS fallback_value FROM capstone_sales LIMIT 10;

-- ---------- SECTION 10: INDEXES & VIEWS ----------
CREATE INDEX idx_capstone_region ON capstone_sales(region);
EXPLAIN SELECT * FROM capstone_sales WHERE region = 'North';

CREATE OR REPLACE VIEW high_value_orders AS
SELECT order_id, region, category, sales
FROM capstone_sales
WHERE sales > 200000;
SELECT * FROM high_value_orders LIMIT 10;
-- DROP VIEW high_value_orders;   -- uncomment to remove when done practicing

-- ---------- SECTION 11: TRANSACTIONS ----------
START TRANSACTION;
UPDATE capstone_sales SET profit = profit + 0 WHERE order_id = (SELECT MIN(order_id) FROM capstone_sales);
COMMIT;
-- ROLLBACK;  -- uncomment instead of COMMIT to undo the change

-- ---------- SECTION 12: FINAL WORKFLOW QUERY (interview-style, all pieces combined) ----------
-- "Top-selling category per region, and how far each region is from its sales target"
WITH category_rank AS (
    SELECT region, category, SUM(sales) AS cat_sales,
           ROW_NUMBER() OVER (PARTITION BY region ORDER BY SUM(sales) DESC) AS rn
    FROM capstone_sales
    GROUP BY region, category
),
region_totals AS (
    SELECT region, SUM(sales) AS region_sales
    FROM capstone_sales GROUP BY region
)
SELECT cr.region, cr.category AS top_category, cr.cat_sales,
       rt.region_sales, t.sales_target,
       rt.region_sales - t.sales_target AS gap_vs_target
FROM category_rank cr
JOIN region_totals rt ON cr.region = rt.region
JOIN region_targets t ON cr.region = t.region
WHERE cr.rn = 1
ORDER BY gap_vs_target DESC;

-- ============================================================================
-- END OF CAPSTONE — every clause from the notes has been executed above.
-- ============================================================================
