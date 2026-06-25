USE DataWarehouse;
GO

DROP VIEW gold.fact_sales;
GO
CREATE VIEW gold.fact_sales AS
SELECT
    sd.sls_ord_num AS order_number,
    dc.customer_key,
    dp.product_key,
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt AS shipping_date,
    sd.sls_due_dt AS due_date,
    sd.sls_sales AS total_sale,
    sd.sls_quantity AS quantity,
    sd.sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_customers dc
on sd.sls_cust_id = dc.customer_id
LEFT JOIN gold.dim_products dp
on sd.sls_prd_key = dp.product_number;