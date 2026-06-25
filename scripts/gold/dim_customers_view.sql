USE DataWarehouse;
GO

CREATE VIEW gold.dim_customers AS
SELECT
    customer_key,
    cst_id AS customer_id,
    cst_key AS customer_number,
    cst_firstname AS firstname,
    cst_lastname AS lastname,
    BDATE AS birth_date,
    gender,
    CNTRY AS country,
    cst_marital_status AS marital_status,
    cst_create_date AS create_date
FROM
    (SELECT
        ROW_NUMBER() OVER(ORDER BY cst_id) AS customer_key,
        ci.cst_id,
        ci.cst_key,
        ci.cst_firstname,
        ci.cst_lastname,
        ci.cst_marital_status,
        ci.cst_create_date,
        cb.BDATE,
        case 
            when ci.cst_gndr = null then isnull(cb.GEN, 'n/a')
            else ci.cst_gndr
        end as gender,
        cl.CNTRY
    FROM silver.crm_cust_info ci
    LEFT JOIN silver.erp_cust_az12 cb
    ON ci.cst_key = cb.cid
    LEFT JOIN silver.erp_loc_a101 cl
    ON ci.cst_key = cl.CID)t;
