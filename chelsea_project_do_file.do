clear all
set more off
capture log close


* Import Excel spreadsheet with data
import excel "/Users/soheelim/Desktop/Projects/Chelsea Project/Original Dataset Sent from Chelsea.xlsx", sheet("SW - ACCOUNT LISTING CHELSEA ON") firstrow

* Order MeterType after Usage21
order MeterType, after (Usage21)

* Convert MeterSize from string to numeric and handle zeros
destring MeterSize, force replace
replace MeterSize = . if MeterSize == 0

* Generate a new binary variable for Senior Discount
gen NewSeniorDiscount = (SeniorDiscount == "YES")
replace NewSeniorDiscount = 0 if SeniorDiscount == "NO"
label variable NewSeniorDiscount "Binary Senior Discount"
order NewSeniorDiscount, after(MeterSize)
drop SeniorDiscount

* Replace zeros with missing values for various variables
foreach var in CurrentMonthUsage CurrentWaterCharge CurrentSewerDue CurrentTrashCharge CurrentTotalDue Usage43 Usage32 Usage21 {
  replace `var' = . if `var' == 0
}

* Billing and Charge Structure Examination Tiered Pricing Analysis:

* To investigate if there's tiered pricing, you can create categories of water usage (e.g., low, medium, high) based on CurrentMonthUsage or historical usage (Usage43, Usage32, Usage21).

* Use tabstat or summarize to analyze the average total charge (CurrentTotalDue) within each category.

egen UsageCategory = cut(CurrentMonthUsage), at(0 100 500 1000 5000 10000 20000 50000 100000)
tabstat CurrentTotalDue, by(UsageCategory) stats(mean)

* Meter Size and Charge Relationship:

* Adding a regression analysis to determine if the relationship is linear.

regress CurrentWaterCharge MeterSize

* Create a new variable for broad property categories

gen BroadCategory = ""

* Assign "Residential" to property types starting with "R"

replace BroadCategory = "Residential" if regexm(PropertyType, "^R")

* Assign "Commercial" to property types starting with "C" or "COM"

replace BroadCategory = "Commercial" if regexm(PropertyType, "^(C|COM)")

* Tabulate BroadCategory to create dummy variables

tabulate BroadCategory, generate(PropTypeDummy)

* Tiered Pricing Impact on Total Bill:

* Analyze the variability within the CurrentTotalDue across different UsageCategory to infer tiered pricing.

graph box CurrentTotalDue, over(UsageCategory) title("Tiered Pricing Impact on Total Bill")

* Discrepancies in Charge Increases Relative to Meter Size:

* Investigate the relationship between meter size and charges using a more detailed regression analysis, including a polynomial term to check for non-linearity.

gen MeterSizeSq = MeterSize^2

regress CurrentWaterCharge MeterSize MeterSizeSq

encode AccountType, generate(AccountTypeNum)   

summarize MeterType

* Assign a unique numeric code to missing values in MeterType.

replace MeterType = -1 if missing(MeterType)

* Run the regression including the new category for missing values.
regress CurrentMonthUsage AccountTypeNum MeterType

* Water Usage Spikes and Maintenance Issues:

* This requires additional variables indicating maintenance issues, which you might not have. However, you can identify unusual spikes in usage that could imply such issues.
 
* Calculate the difference between successive readings and look for large deviations.
 
gen UsageDifference43 = Usage43 - Usage32

summarize UsageDifference43, detail

regress CurrentWaterCharge CurrentMonthUsage

gen UsageSq = CurrentMonthUsage^2

regress CurrentWaterCharge CurrentMonthUsage UsageSq

* Scatter plot for comparison of water charges by meter size between commercial and residential properties
twoway (scatter CurrentWaterCharge MeterSize if PropTypeDummy1 == 1, mcolor(red)) (lfit CurrentWaterCharge MeterSize if PropTypeDummy1 == 1, lcolor(red)) (scatter CurrentWaterCharge MeterSize if PropTypeDummy2 == 1, mcolor(blue)) (lfit CurrentWaterCharge MeterSize if PropTypeDummy2 == 1, lcolor(blue)), legend(label(1 "Commercial") label(2 "Commercial Fit") label(3 "Residential") label(4 "Residential Fit")) title("Comparison of Current Water Charges by Meter Size Across Different Property Types")

* Regression including dummy variables
regress CurrentTotalDue CurrentMonthUsage MeterSize PropTypeDummy* NewSeniorDiscount

* Clean up by dropping unused dummy variables
drop PropTypeDummy*

* Summary statistics for MeterType
summarize MeterType

* Replace missing MeterType with unique code
replace MeterType = -1 if missing(MeterType)

* Regression of Current Month Usage on AccountTypeNum and MeterType
regress CurrentMonthUsage AccountTypeNum MeterType

* Scatter plot matrix for usage across billing periods
graph matrix Usage21 Usage32 Usage43, title("Scatter Plot Matrix of Water Usage Across Three Billing Periods")

* Save the file.
save "/Users/soheelim/Desktop/Projects/Chelsea Project/chelsea_project_do_file.do", replace
