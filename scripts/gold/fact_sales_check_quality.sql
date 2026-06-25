USE DataWarehouse;

GO
SELECT
    sd.sls_ord_num,
    dc.customer_key,
    dp.product_key,
    sd.sls_order_dt,
    sd.sls_ship_dt,
    sd.sls_due_dt,
    sd.sls_sales,
    sd.sls_quantity,
    sd.sls_price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_customers dc
on sd.sls_cust_id = dc.customer_id
LEFT JOIN gold.dim_products dp
on sd.sls_prd_key = dp.product_number
where dc.customer_key = 10769;



/*
check if keys are actually populating
*/
SELECT 
    COUNT(*) as total_sales_rows,
    COUNT(dp.product_key) as successfully_matched_product_keys,
    COUNT(dc.customer_key) as successfully_matched_customer_keys
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products dp
    ON sd.sls_prd_key = dp.product_number
LEFT JOIN gold.dim_customers dc
    on sd.sls_cust_id = dc.customer_id;


/*
Which Sales records are missing Product Keys?
*/
SELECT DISTINCT
    sd.sls_prd_key AS missing_product_number
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products dp
    ON sd.sls_prd_key = dp.product_number
WHERE dp.product_key IS NULL;


/*
Which Sales records are missing Customer Keys?
*/
SELECT DISTINCT
    sd.sls_cust_id AS missing_customer_id
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_customers dc
    ON sd.sls_cust_id = dc.customer_id
WHERE dc.customer_key IS NULL;


/*
Which Customer Keys are missing in Sales records  ?
*/
SELECT 
    dp.product_key,
    dp.product_number
FROM gold.dim_products dp
LEFT JOIN silver.crm_sales_details sd
    ON dp.product_number = sd.sls_prd_key
WHERE sd.sls_prd_key IS NULL;

/*
Which Product Keys are missing in Sales records  ?
*/
SELECT 
    dc.customer_key,
    dc.customer_id
FROM gold.dim_customers dc
LEFT JOIN silver.crm_sales_details sd
    ON dc.customer_id = sd.sls_cust_id
WHERE sd.sls_cust_id IS NULL;


-- select the view
SELECT * FROM gold.fact_sales;

-- foreign key integrete
SELECT
    *
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers dc
ON fs.customer_key = dc.customer_key
LEFT JOIN gold.dim_products dp
ON fs.product_key = dp.product_key
WHERE fs.customer_key is NULL;
