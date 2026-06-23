/*
===============================================================================
DDL Script: Create silver Layer Tables
===============================================================================
Script Purpose:
    This script initialises the structures for the 'silver Layer'  
    within the 'DataWarehouse' database. It drops existing tables if they 
    exist and recreates them to ensure a clean, repeatable environment.

Source Systems Coverered:
    1. CRM (Customer Relationship Management) System:
       - silver.crm_cust_info     : Core customer details and profile data
       - silver.crm_prd_info      : Product catalog master records
       - silver.crm_sales_details : Transactional sales orders
    2. ERP (Enterprise Resource Planning) System:
       - silver.erp_cust_az12     : Additional legacy customer attributes
       - silver.erp_loc_a101      : Customer country and regional mappings
       - silver.erp_px_cat_g1v2   : Product categories and maintenance logs

Design Philosophy:
    - Tables are created with flexible, raw data types to avoid loading errors.
    - Dates in transactional sales are stored as integers (surrogate date keys).
    - Dropping and recreating tables (Idempotent script) facilitates clean
      automated test runs and schema updates.

WARNING:
    Executing this script will DROP all matching tables in the 'silver' schema.
    Any existing data currently loaded into these staging tables will be 
    permanently deleted. Ensure this is run only during ETL initialisation or 
    development refreshes.
===============================================================================
*/



USE DataWarehouse;
GO

-- crm_cust_info table
if object_id('silver.crm_cust_info', 'U') is not null
    drop table silver.crm_cust_info;
create table silver.crm_cust_info (
    cst_id int,
    cst_key nvarchar(50),
    cst_firstname nvarchar(100),
    cst_lastname nvarchar(100),
    cst_marital_status nvarchar(50),
    cst_gndr nvarchar(50),
    cst_create_date date,
    dwh_create_date DATETIME2 default getdate()
);
GO

-- crm_prd_info table
if object_id('silver.crm_prd_info', 'U') is not null
    drop table silver.crm_prd_info;
create table silver.crm_prd_info(
    prd_id int,
    prd_key nvarchar(50),
    sls_prd_key nvarchar(50),
    cat_id nvarchar(50),
    prd_nm nvarchar(100),
    prd_cost decimal(10,2),
    prd_line nvarchar(100),
    prd_start_dt date,
    prd_end_dt date,
    dwh_create_date DATETIME2 default getdate()
);
GO

-- crm_sales_details table
if object_id('silver.crm_sales_details', 'U') is not null
    drop table silver.crm_sales_details;
create table silver.crm_sales_details(
    sls_ord_num nvarchar(50),
    sls_prd_key nvarchar(50),
    sls_cust_id int,
    sls_order_dt DATE,
    sls_ship_dt DATE,
    sls_due_dt DATE,
    sls_sales decimal(10,2),
    sls_quantity int,
    sls_price decimal(10,2),
    dwh_create_date DATETIME2 default getdate()
);
GO

-- erp_cust_az12 table
if object_id('silver.erp_cust_az12', 'U') is not null
    drop table silver.erp_cust_az12;
create table silver.erp_cust_az12(
    CID nvarchar(50),
    BDATE date,
    GEN nvarchar(50),
    dwh_create_date DATETIME2 default getdate()
);
GO

-- erp_loc_a101 table
if object_id('silver.erp_loc_a101', 'U') is not null
    drop table silver.erp_loc_a101;
create table silver.erp_loc_a101(
    CID nvarchar(50),
    CNTRY nvarchar(100),
    dwh_create_date DATETIME2 default getdate()
);
GO

-- erp_px_cat_g1v2 table
if object_id('silver.erp_px_cat_g1v2', 'U') is not null
    drop table silver.erp_px_cat_g1v2;
create table silver.erp_px_cat_g1v2(
    ID nvarchar(50),
    CAT nvarchar(100),
    SUBCAT nvarchar(100),
    MAINTENANCE nvarchar(100),
    dwh_create_date DATETIME2 default getdate()
);
GO
