-- SQL Cleaning & Feature Engineering for Chelsea Project
-- SQLite-compatible data cleaning and feature engineering script for City of Chelsea water billing analysis

-- ---------------------------------------------------------------------
-- STEP 1: Create a cleaned version of the raw Chelsea water billing data
-- ---------------------------------------------------------------------
CREATE TABLE chelsea_water_clean AS
SELECT
    newid,
    current_month_usage,
    current_water_charge,
    current_total_due,
    current_trash_charge,
    current_sewer_due,
    usage_43,
    usage_32,
    usage_21,
    meter_size,
    senior_discount,
    property_type,
    read_date_4 AS read_date_start,
    read_date_3 AS read_date_end,
    account_type,
    meter_type,

    -- Cleaned meter size: convert to NULL if 0
    NULLIF(CAST(meter_size AS REAL), 0) AS meter_size_cleaned,

    -- Convert senior_discount to binary
    CASE
        WHEN senior_discount IS NOT NULL AND TRIM(senior_discount) <> '' THEN 1
        ELSE 0
    END AS new_senior_discount,

    -- Categorize property types
    CASE
        WHEN property_type LIKE 'RES%' THEN 'Residential'
        WHEN property_type LIKE 'COM%' THEN 'Commercial'
        ELSE 'Other'
    END AS property_category,

    -- Create usage tier
    CASE
        WHEN current_month_usage < 1000 THEN 'Low'
        WHEN current_month_usage BETWEEN 1000 AND 5000 THEN 'Medium'
        WHEN current_month_usage BETWEEN 5001 AND 10000 THEN 'High'
        ELSE 'Very High'
    END AS usage_category

FROM chelsea_water_data
WHERE 
    current_month_usage > 0
    AND current_total_due >= 0;

-- ---------------------------------------------------------------------
-- STEP 2: Drop rows with missing cleaned meter_size
-- ---------------------------------------------------------------------
DELETE FROM chelsea_water_clean
WHERE meter_size_cleaned IS NULL;

-- ---------------------------------------------------------------------
-- STEP 3: Normalize usage per day (SQLite-compatible)
-- ---------------------------------------------------------------------
ALTER TABLE chelsea_water_clean ADD COLUMN usage_per_day REAL;

UPDATE chelsea_water_clean
SET usage_per_day = current_month_usage / MAX(julianday(read_date_end) - julianday(read_date_start), 1);

-- ---------------------------------------------------------------------
-- STEP 4: Add flags and normalized features
-- ---------------------------------------------------------------------
ALTER TABLE chelsea_water_clean ADD COLUMN high_usage_flag INTEGER;

UPDATE chelsea_water_clean
SET high_usage_flag = CASE
    WHEN current_month_usage > 10000 THEN 1
    ELSE 0
END;

ALTER TABLE chelsea_water_clean ADD COLUMN charges_per_gallon REAL;

UPDATE chelsea_water_clean
SET charges_per_gallon = CASE
    WHEN current_month_usage > 0 THEN current_total_due / current_month_usage
    ELSE NULL
END;

-- ---------------------------------------------------------------------
-- STEP 5: Remove rows with invalid or missing dates
-- ---------------------------------------------------------------------
DELETE FROM chelsea_water_clean
WHERE 
    read_date_start IS NULL OR read_date_end IS NULL
    OR julianday(read_date_end) < julianday(read_date_start);
