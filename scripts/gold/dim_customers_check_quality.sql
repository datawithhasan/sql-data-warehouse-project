SELECT * FROM silver.crm_cust_info;
SELECT * FROM silver.erp_cust_az12;
SELECT * FROM silver.erp_loc_a101;

/*
check if there is any duplicate value
*/
SELECT 
    cst_id,
    COUNT(*)
FROM
    (SELECT
        ci.cst_id,
        ci.cst_key,
        ci.cst_firstname,
        ci.cst_lastname,
        ci.cst_marital_status,
        ci.cst_gndr,
        ci.cst_create_date,
        cb.BDATE,
        cb.GEN,
        cl.CNTRY
    FROM silver.crm_cust_info ci
    LEFT JOIN silver.erp_cust_az12 cb
    ON ci.cst_key = cb.cid
    LEFT JOIN silver.erp_loc_a101 cl
    ON ci.cst_key = cl.CID)t 
GROUP BY cst_id
HAVING COUNT(*) >1;


/*
check if there is any gender missmatch
*/
SELECT distinct
    ci.cst_gndr,
    cb.GEN
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 cb
ON ci.cst_key = cb.cid
LEFT JOIN silver.erp_loc_a101 cl
ON ci.cst_key = cl.CID;

/*
checking after fixing the missmatch
*/
SELECT distinct
    cst_gndr,
    GEN,
    new_gender
FROM
    (SELECT
        ci.cst_gndr,
        cb.gen,
        case 
            when ci.cst_gndr = 'n/a' then isnull(cb.GEN, 'n/a')
            else ci.cst_gndr
        end as new_gender
    FROM silver.crm_cust_info ci
    LEFT JOIN silver.erp_cust_az12 cb
    ON ci.cst_key = cb.cid
    LEFT JOIN silver.erp_loc_a101 cl
    ON ci.cst_key = cl.CID)t;


/*
checking data from the view
*/
-- SELECT * FROM gold.dim_customers;