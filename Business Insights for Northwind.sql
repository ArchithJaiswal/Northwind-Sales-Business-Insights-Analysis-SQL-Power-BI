/*
===============================================================================
NORTHWIND SALES & BUSINESS ANALYTICS PROJECT
===============================================================================

Project Summary:
Cleaned and transformed the Northwind dataset, created a consolidated SQL
view named `MASTER_ORDERS`.The project focuses on extracting business insights
related to customer behavior, revenue performance, product demand, supplier
distribution, regional trends, and sales patterns using exploratory and KPI-
driven SQL analysis.

Analysis Covered:
-- Customer Segmentation Based on Spending and Order Behavior 
-- How frequently do different customer segments place orders? 
-- Average Number of Orders Placed by Each Customer 
-- Customer-wise Revenue and Order Frequency Analysis 
-- Geographical Distribution of Customer Orders by Country and City 
-- Category-wise Revenue Contribution Analysis 
-- Product-wise Revenue Performance Analysis  
-- Revenue in Countries 
-- Relationship between Countries and their top selling category 
-- What is the geographic and title-wise distribution of employees 
-- What trends can we observe in hire dates across employee titles? 
-- Are there correlations between product pricing, stock levels, and sales performance? 
-- How does product demand change over months 
-- Order Revenue Distribution Summary Across All Orders 
-- regional trends in supplier distribution and pricing 
-- suppliers distributed across different product categories 
--  relation of supplier pricing and categories across different regions

SQL Concepts Used:
• Joins
• CTEs
• Aggregate Functions
• Window Functions
• Views
• Business KPI Analysis

Author: Archith Jaiswal
===============================================================================
*/


use `b'sales accio'`;

SELECT * FROM customers LIMIT 10;
SELECT * FROM employees LIMIT 10;
SELECT * FROM categories LIMIT 10;
SELECT * FROM orders LIMIT 10;
SELECT * FROM order_details limit 10;
SELECT * FROM products LIMIT 10;
SELECT * FROM SHIPPERS LIMIT 10;
SELECT * FROM SUPPLIERS LIMIT 10;

-- DATA CLEANING --
 
RENAME TABLE `order details` TO order_details;

DESCRIBE CUSTOMERS;

UPDATE customers
SET region = 'Not Available'
WHERE region IS NULL;

ALTER TABLE customers
DROP COLUMN ImageThumbnail,
DROP COLUMN IMAGE,
DROP COLUMN FAX,
DROP COLUMN PHONE,
DROP COLUMN POSTALCODE,
DROP COLUMN ADDRESS;

DESCRIBE EMPLOYEES;

alter table employees
drop column notes,
drop column photo;

update employees
set region = "Not Available"
where region is null;

Alter table employees
Add column FullName Varchar(255);

update employees
set FullName = concat(Titleofcourtesy,' ',FirstName,' ',LastName);

Alter Table employees
drop column Titleofcourtesy,
drop column FirstName,
drop column LastName,
drop column Homephone,
drop column Extension,
drop column postalcode,
drop column Address
;

DESCRIBE CATEGORIES;

Alter table Categories
drop column `Description`,
drop column Picture;

DESCRIBE ORDERS;

ALTER TABLE ORDERS
DROP COLUMN SHIPADDRESS;

update orders
set shipregion = "Not Available"
where shipregion is null;

update orders
set shippostalcode = "NA"
WHERE SHIPPOSTALCODE IS NULL;

ALTER TABLE orders
ADD OrderYear INT,
ADD OrderMonth INT;

UPDATE orders
SET 
OrderYear = YEAR(OrderDate),
OrderMonth = MONTH(OrderDate);

SELECT ORDERID,COUNT(ORDERID) AS NO_OF_IDS
FROM ORDERS
GROUP BY ORDERID
HAVING COUNT(ORDERID) > 1;

DESCRIBE products;

SELECT PRODUCTID,COUNT(PRODUCTID) AS NO_OF_IDS
FROM products
GROUP BY productID
HAVING COUNT(PRODUCTID) > 1;

DESCRIBE SUPPLIERS;

ALTER TABLE SUPPLIERS
DROP COLUMN HOMEPAGE,
DROP COLUMN FAX,
DROP COLUMN PHONE,
DROP COLUMN ADDRESS;

UPDATE SUPPLIERS
SET REGION = "NA"
WHERE REGION IS NULL;

DESCRIBE SHIPPERS;

ALTER TABLE SHIPPERS
DROP COLUMN PHONE;

describe ORDER_DETAILS;

ALTER TABLE order_details
ADD COLUMN REVENUE DECIMAL(10,2);

UPDATE order_details
SET REVENUE = UNITPRICE * QUANTITY;

-- VIEW --

create VIEW MASTER_ORDERS AS
SELECT O.ORDERID,
O.CUSTOMERID,
O.ORDERDATE,
OD.PRODUCTID,
OD.QUANTITY,
OD.UNITPRICE,
OD.REVENUE,
C.COUNTRY,
C.CITY,
P.CATEGORYID
FROM ORDERS O 
JOIN ORDER_DETAILS OD ON OD.ORDERID = O.ORDERID
JOIN CUSTOMERS C ON C.CUSTOMERID = O.CUSTOMERID
JOIN PRODUCTS P ON P.PRODUCTID = OD.PRODUCTID;

-- Average Number of Orders Placed by Each Customer --

SELECT CUSTOMERID,avg(ORDER_COUNT) AS AVG_NUMBER_OF_ORDERS
FROM (SELECT CUSTOMERID,COUNT(ORDERID) AS ORDER_COUNT
FROM MASTER_ORDERS
GROUP BY CUSTOMERID) AS T1
GROUP BY CUSTOMERID;

-- Customer-wise Revenue and Order Frequency Analysis --

SELECT CUSTOMERID,SUM(REVENUE) AS TOTAL_REVENUE,COUNT(ORDERID) AS NO_OF_ORDERS
FROM MASTER_ORDERS
GROUP BY CUSTOMERID
ORDER BY TOTAL_REVENUE DESC;

-- Geographical Distribution of Customer Orders by Country and City --

SELECT CUSTOMERID,Country,city,COUNT(ORDERID) AS ORDERS
from master_orders
group by customerid,country,city
order by country,city,orders;

-- Customer Segmentation Based on Spending and Order Behavior --
 
 WITH customer_features AS (
SELECT
CUSTOMERID,
SUM(REVENUE)AS total_spend,
COUNT(DISTINCT ORDERID)AS order_count,
COUNT(DISTINCT CATEGORYID)AS category_count
FROM MASTER_ORDERS
GROUP BY CUSTOMERID
),

ranked AS (
SELECT *,
PERCENT_RANK() OVER (ORDER BY total_spend) AS spend_pct,
PERCENT_RANK() OVER (ORDER BY order_count) AS orders_pct
FROM customer_features
)

SELECT
CUSTOMERID,
total_spend,
order_count,
category_count,
CASE
WHEN spend_pct >= 0.66 AND orders_pct >= 0.66 THEN 'High-value'
WHEN spend_pct <= 0.33 AND orders_pct <= 0.33 THEN 'Low-engagement'
ELSE 'Mid-tier'
END AS customer_segment
FROM ranked
ORDER BY total_spend DESC;

-- Category-wise Revenue Contribution Analysis --

SELECT CATEGORYID,SUM(REVENUE) AS TOTAL_REVENUE
FROM master_orders
GROUP BY CATEGORYID
ORDER BY TOTAL_REVENUE DESC;

-- Product-wise Revenue Performance Analysis -- 

SELECT PRODUCTID,SUM(REVENUE) AS TOTAL_REVENUE
FROM master_orders
GROUP BY PRODUCTID
ORDER BY TOTAL_REVENUE DESC;

-- REVENUE IN COUNTRIES --
SELECT COUNTRY,COUNT(DISTINCT(CUSTOMERID)) AS NO_OF_CUSTOMERS,COUNT(DISTINCT(ORDERID)) AS NO_OF_ORDERS,SUM(REVENUE) AS TOTAL_REVENUE,
ROUND(AVG(REVENUE),2) AS AVG_REVENUE,ROUND(SUM(REVENUE)/COUNT(DISTINCT(CUSTOMERID)),2) AS AVG_REVENUE_PER_CUSTOMER
FROM master_orders
GROUP BY COUNTRY
ORDER BY AVG_REVENUE;

-- Relationship between Countries and their top selling category --

with table_1 as (select country,Categoryid,sum(revenue) as total_revenue,count(distinct(orderid)) as no_of_orders,
rank() over(partition by country order by avg(revenue)desc) as rnk,
avg(revenue) as avg_revenue
from master_orders
group by country,categoryid
order by country,total_revenue)

select country,categoryid,total_revenue,no_of_orders,avg_revenue from table_1
where rnk = 1 ;

-- How frequently do different customer segments place orders? --

with table_1 as (select customerid,sum(revenue) as total_revenue,count(distinct(orderid)) as orders,ORDERDATE,
LAG(ORDERDATE) OVER(PARTITION BY CUSTOMERID ORDER BY ORDERDATE) AS PREV_ORDER_DATE
 from master_orders
 group by customerid,ORDERDATE),
 
 TABLE_2 AS ( SELECT *,DATEDIFF(ORDERDATE,PREV_ORDER_DATE) AS DAYS_BETWEEN_ORDERS
 FROM TABLE_1
 WHERE PREV_ORDER_DATE IS NOT NULL),
 
 ranking as ( select *, percent_rank() over (order by total_revenue) as prcnt_revenue
 from table_2
 )
 
 select CUSTOMERID,TOTAL_REVENUE,ORDERS,DAYS_BETWEEN_ORDERS,
 case when prcnt_revenue >= 0.66 then "High Value"
	  when prcnt_revenue >= 0.33 then "Mid vALUE"
      else "Low Value" END AS CUSTOMER_CATEGORY
      FROM RANKING
      ORDER BY TOTAL_REVENUE DESC;
      
-- What is the geographic and title-wise distribution of employees --

select country,region,title,count(employeeid) as employees,
round(count(employeeid)*100.0/sum(count(employeeid)) over(),2) as pct_of_total
from employees
group by country,region,title
order by employees desc;

-- What trends can we observe in hire dates across employee titles? --

select TITLE,year(hiredate) AS YEAR,MONTH(HIREDATE) AS MONTH,count(EmployeeID) AS EMPLOYEES_HIRED
from employees
GROUP BY TITLE,YEAR(HIREDATE),MONTH(HIREDATE)
ORDER BY YEAR,MONTH,EMPLOYEES_HIRED;

-- Are there correlations between product pricing, stock levels, and sales performance? --

select m.productid,p.productname,m.unitprice,p.unitsinstock,sum(m.quantity) total_quantity_sold,sum(m.revenue) as revenue
from master_orders m
join products p on p.productid = m.productid
group by m.productid,m.unitprice,p.productname,p.unitsinstock
order by revenue desc;

-- How does product demand change over months --

select o.ordermonth,count(p.unitsonorder) as units
from orders o 
join master_orders m on o.orderid = m.orderid
join products p on p.productid = m.productid
group by o.ordermonth 
order by o.ordermonth ;

-- Order Revenue Distribution Summary Across All Orders --

select count(*) as total_orders,
round(avg(order_revenue),2) as avg_reveue,
round(stddev(order_revenue),2) as stddev_revenue,
round(min(order_revenue),2) as min_reveue,
round(max(order_revenue),2) as max_revenue
from (select orderid, sum(unitPrice * quantity * (1 - discount)) as order_revenue
from  order_details
group by orderid) as order_total;

-- regional trends in supplier distribution and pricing --

select s.country,s.city,count(distinct(s.supplierid)) as suppliers,count(distinct(p.productid)) total_product,
round(avg(p.unitprice)) as avg_price,min(unitprice) as min_price,max(unitprice) as max_price
from products p 
join suppliers s on p.SupplierID = s.SupplierID
group by  s.country,s.city
order by avg_price desc;

-- suppliers distributed across different product categories --

select p.categoryid , count(distinct(p.productid)) as total_products,count(distinct(s.supplierid)) as total_suppliers
from suppliers s 
join products p on p.supplierid = s.supplierid
group by p.categoryid
order by total_suppliers desc;

--  relation of supplier pricing and categories across different regions --

select s.country,s.city,s.supplierid,count(distinct(productid)) as total_products,round(avg(p.unitprice),2) as avg_price,count(distinct(categoryid)) as total_categories
from suppliers s
join products p on p.supplierid = s.supplierid
group by s.country,s.city,s.supplierid
order by avg_price;











