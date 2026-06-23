/*
===================================================================================================
PURPOSE:
    This script serves as the final Data Quality Assurance (QA) and Verification suite 
    for the 'Silver' Operational Layer. 

    Its primary purpose is to audit the cleansed tables after the ETL process has run, 
    ensuring that all business logic rules, standardization patterns, and data integrity 
    expectations were successfully applied.

SCOPE OF VERIFICATION:
    - Primary Key Validation: Confirms that deduplication worked perfectly and that no 
      duplicate IDs or missing NULL keys exist in the primary columns.
      
    - Structural Cleanliness: Verifies that all trailing/leading whitespaces were completely 
      removed and that no rogue padding remains in text attributes.
      
    - Standardization & Formatting Check: Profiles low-cardinality columns (Gender, Marital Status, 
      Countries, Maintenance Flags) to ensure values are mapped uniformly with no text corruption.
      
    - Chronological & Boundary Logic: Validates that date attributes align with strict business 
      boundaries, verifying that no birth dates exist in the future and historical timeline bounds 
      never overlap.
      
    - Financial & Mathematical Accuracy: Checks high-cardinality transactional fields to confirm 
      that sales totals perfectly reconcile with quantity and unit price logic, with no negative or 
      missing values.

TARGET TABLES AUDITED:
    - silver.crm_cust_info       - silver.erp_cust_az12
    - silver.crm_prd_info        - silver.erp_loc_a101
    - silver.crm_sales_details   - silver.erp_px_cat_g1v2
===================================================================================================
*/


/*
Checking the quality of data in silver layer tables
silver.crm_cust_info
*/

-- check for nulls and duplicates in primary key columns of silver layer tables
-- expectation: no results
select
    cst_id,
    count(*) as cnt
from silver.crm_cust_info
group by cst_id
having count(*) > 1 or cst_id is null;

-- check for unwanted spaces in string columns of silver layer tables
-- expectation: no results
select
    cst_lastname
from silver.crm_cust_info
where cst_lastname != trim(cst_lastname);


-- check the consistency of the values in low cardinality columns
select distinct
    cst_marital_status
from silver.crm_cust_info;

-- check the consistency of the values in low cardinality columns
select distinct
    cst_gndr
from silver.crm_cust_info;

-- select all
select * from silver.crm_cust_info;


/*
Checking the quality of data in silver layer tables
silver.crm_prd_info
*/

-- check for nulls and duplicates in primary key columns
-- expectation: no results
select
    prd_id,
    count(*) as cnt
from silver.crm_prd_info
group by prd_id
having count(*) > 1 or prd_id is null;

-- check for unwanted spaces in string columns 
-- expectation: no results
select
    prd_nm
from silver.crm_prd_info
where prd_nm != trim(prd_nm);

-- check for negative value or null in numeric columns
-- expectation: no results
select
    prd_cost
from silver.crm_prd_info
where prd_cost < 0 or prd_cost is null;

-- check the consistency of the values in low cardinality columns
select distinct
    prd_line
from silver.crm_prd_info;

-- check the date range of the date columns
-- expectation: no results
select
    prd_key,
    prd_start_dt,
    prd_end_dt
from silver.crm_prd_info
WHERE prd_start_dt > prd_end_dt;

-- select all
select * from silver.crm_prd_info;

/*
silver.crm_sales_details
*/

-- check if sales = quantity*price or any of the values is null or negative or zero
-- expectation: no results
select
    sls_sales,
    sls_quantity,
    sls_price
from silver.crm_sales_details
where sls_sales != sls_quantity * sls_price
or sls_sales is null
or sls_quantity is null
or sls_price is null
or sls_sales <= 0
or sls_quantity <= 0
or sls_price <= 0
order by sls_sales, sls_quantity, sls_price;

/*
erp_cust_az12
*/

-- select all
SELECT * FROM silver.erp_cust_az12;

-- checking birth date
-- expectation: no results
SELECT 
    bdate
FROM silver.erp_cust_az12
WHERE year(bdate) < 1900 or bdate > GETDATE();

-- check the consistency of the values in low cardinality columns
select distinct
    gen
from silver.erp_cust_az12;

/*
erp_loc_a101
*/

-- select all
SELECT * FROM silver.erp_loc_a101;


-- check the consistency of the values in low cardinality columns
select distinct
    cntry
from silver.erp_loc_a101;

/*
erp_px_cat_g1v2
*/

-- select all
select * from silver.erp_px_cat_g1v2;

-- check the consistency of the values in low cardinality columns
select distinct
    MAINTENANCE
from silver.erp_px_cat_g1v2;

-- check for unwanted spaces in string columns 
-- expectation: no results
select
    id
from silver.erp_px_cat_g1v2
where id != trim(id);
