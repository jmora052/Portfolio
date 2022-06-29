
SELECT * FROM NashvilleHousing

-- Populate Property Address Data
-- ParcelID is another unique identifier for a residence. If PropertyAddress is known for one,
-- It should be known for all addresses with the same ParcelIDs.

-- Checking data structure and missing values

SELECT *
FROM NashvilleHousing
WHERE PropertyAddress IS NULL
ORDER BY ParcelID;

-- Populating NULL PropertyAddresses with Known Addresses Sharing ParcelID

SELECT a.parcelID, a.propertyaddress, b.parcelid, b.propertyaddress, IFNULL(a.propertyaddress, b.propertyaddress) as filltest
FROM NashvilleHousing as a
JOIN NashvilleHousing as b
    ON a.parcelID = b.parcelID
    AND a."UniqueID " <> b."UniqueID "
WHERE a.propertyaddress IS NULL
    AND a.parcelID = b.parcelID;

-- Committing Known PropertyAddresses to NULL Values with CTE

WITH PropertyAddressTemp
AS (SELECT IFNULL(a.propertyaddress, b.propertyaddress) as PropertyFill,
a."UniqueID "
FROM NashvilleHousing as a
JOIN NashvilleHousing as b
    ON a.parcelID = b.parcelID
    AND a."UniqueID " <> b."UniqueID "
WHERE a.propertyaddress IS NULL
    AND a.parcelID = b.parcelID)
UPDATE NashvilleHousing
SET PropertyAddress = PropertyFill
FROM PropertyAddressTemp
WHERE NashvilleHousing."UniqueID " = PropertyAddressTemp."UniqueID ";

----------

-- Breaking out Property Address Into Individual Columns (Address, City, State)
-- We can see PropertyAddress consists of a comma delimited Address+City field

SELECT PropertyAddress
FROM NashvilleHousing;

-- Break out using substrings and character index (instr in my client)
 
SELECT
substring(propertyaddress, 1, instr(propertyaddress, ",")-1) as address,
substring(propertyaddress, instr(propertyaddress, ",") + 2, length(propertyaddress)) as address2,
instr(propertyaddress, ",")
FROM NashvilleHousing;

-- Create New Columns for Split PropertyAddress

ALTER TABLE NashvilleHousing
ADD PropertySplitAddress NVARCHAR(255);

UPDATE NashvilleHousing
SET PropertySplitAddress = substring(propertyaddress, 1, instr(propertyaddress, ",")-1);

ALTER TABLE NashvilleHousing
ADD PropertySplitCity NVARCHAR(255);

UPDATE NashvilleHousing
SET PropertySplitCity = substring(propertyaddress, instr(propertyaddress, ",") + 2, length(propertyaddress));

SELECT PropertySplitAddress, PropertySplitCity
FROM NashvilleHousing;

-- Breaking out Using CTE's for Complex Cleanup
-- We can see OwnerAddress consists of a comma delimited Address+City+State field

SELECT OwnerAddress
FROM NashvilleHousing;

-- 3 Element Split Delimiting
-- Due to software limitation, PARSENAME cannot be used.
-- Separating Address From Owner Address

SELECT
substring(OwnerAddress, 1, instr(OwnerAddress, ",")-1) as OwnerSplitAddress
FROM NashvilleHousing;

-- Delimiting by CTE for City and State
-- Since original field had 3 elements to split, must use CTE or subquery to manipulate a 2nd temp field.

WITH OWNERSPLIT
AS (SELECT substring(OwnerAddress, instr(OwnerAddress, ",")+1, length(owneraddress)) as SplitCityStateTemp
FROM NashvilleHousing)
SELECT
substring(SplitCityStateTemp, 1, instr(SplitCityStateTemp, ",")-1) as SplitCityTemp,
substring(SplitCityStateTemp, instr(SplitCityStateTemp, ",")+2, length(SplitCityStateTemp)) as SplitStateTemp
FROM OWNERSPLIT;

-- Committing separated Address from OwnerAddress to Table

ALTER TABLE NashvilleHousing
ADD OwnerSplitAddress NVARCHAR(255);

UPDATE NashvilleHousing
SET OwnerSplitAddress = substring(OwnerAddress, 1, instr(OwnerAddress, ",")-1);

-- Committing Separated City and State from OwnerAddress to Table
-- We have to use some nested CTE's to ensure we can manipulate the second split
-- of "SplitCityStateTemp".
-- The easiest option would be a PARSENAME function, but this will do when unsupported.

ALTER TABLE NashvilleHousing
ADD OwnerSplitCity NVARCHAR(255);

ALTER TABLE NashvilleHousing
ADD OwnerSplitState NVARCHAR(2);

-- Committing Both Through Nested CTEs

WITH OWNERSPLIT
AS (SELECT substring(OwnerAddress, instr(OwnerAddress, ",")+1, length(owneraddress)) as SplitCityStateTemp,
"UniqueID "
FROM NashvilleHousing),
CTE_SPLITCITYSTATE
AS (SELECT substring(SplitCityStateTemp, 1, instr(SplitCityStateTemp, ",")-1) as SplitCityTemp,
substring(SplitCityStateTemp, instr(SplitCityStateTemp, ",")+2, length(SplitCityStateTemp)) as SplitStateTemp,
"UniqueID "
FROM OWNERSPLIT)
UPDATE NashvilleHousing 
SET OwnerSplitCity = SplitCityTemp, OwnerSplitState = SplitStateTemp
FROM CTE_SPLITCITYSTATE
WHERE NashvilleHousing."UniqueID " = CTE_SPLITCITYSTATE."UniqueID ";

SELECT OwnerAddress, OwnerSplitAddress,OwnerSplitCity, OwnerSplitState
FROM NashvilleHousing;

----------

-- Cleaning Yes/No Responses
-- Change Y to Yes and N to No

SELECT SoldAsVacant, count(SoldAsVacant)
FROM NashvilleHousing
GROUP BY SoldAsVacant;

SELECT SoldAsVacant,
(CASE
WHEN SoldAsVacant = "Y" THEN "Yes"
WHEN SoldAsVacant = "N" THEN "No"
ELSE SoldAsVacant END) as SoldAsVacant_CorrectedTemp
FROM NashvilleHousing;

-- Checking Transformation for Accuracy

WITH SoldAsVacantTemp
AS (SELECT SoldAsVacant,
(CASE
WHEN SoldAsVacant = "Y" THEN "Yes"
WHEN SoldAsVacant = "N" THEN "No"
ELSE SoldAsVacant END) as SoldAsVacant_CorrectedTemp
FROM NashvilleHousing)
SELECT SoldAsVacant_CorrectedTemp, count(SoldAsVacant_CorrectedTemp)
FROM SoldAsVacantTemp
GROUP BY SoldAsVacant_CorrectedTemp;

-- Committing Transformation

ALTER TABLE NashvilleHousing
ADD SoldAsVacantCorrected VARCHAR(3);

UPDATE NashvilleHousing
SET SoldAsVacantCorrected = (CASE
WHEN SoldAsVacant = "Y" THEN "Yes"
WHEN SoldAsVacant = "N" THEN "No"
ELSE SoldAsVacant END);

----------

-- Deleting Duplicates
-- As a best practice, I'll move the deleted duplicates to a different table. 

-- Gathering Duplicates If They Match 5 Columns in Another Row

WITH CTE_Row_Num
AS (SELECT *, ROW_NUMBER() OVER (
PARTITION BY
    ParcelID,
    PropertyAddress,
    SalePrice,
    SaleDate,
    LegalReference
    ORDER BY
        "UniqueID ") as Row_Num
FROM NashvilleHousing)
SELECT *
FROM CTE_Row_Num
WHERE Row_Num > 1
ORDER BY "UniqueID ";

-- Moving Duplicates to New Table

CREATE TABLE DuplicateValues AS
WITH CTE_Row_Num
AS (SELECT *, ROW_NUMBER() OVER (
PARTITION BY
    ParcelID,
    PropertyAddress,
    SalePrice,
    SaleDate,
    LegalReference
    ORDER BY
        "UniqueID ") as Row_Num
FROM NashvilleHousing)
SELECT *
FROM CTE_Row_Num
WHERE Row_Num > 1
ORDER BY "UniqueID ";

-- Deleting 104 Duplicates From Original Table

WITH CTE_Row_Num
AS (SELECT *, ROW_NUMBER() OVER (
PARTITION BY
    ParcelID,
    PropertyAddress,
    SalePrice,
    SaleDate,
    LegalReference
    ORDER BY
        "UniqueID ") as Row_Num
FROM NashvilleHousing)
DELETE
FROM CTE_Row_Num
WHERE Row_Num > 1;

----------

-- Deleting Unused Columns

SELECT *
FROM NashvilleHousing;

ALTER TABLE NashvilleHousing
DROP COLUMN OwnerAddress, TaxDistrict, PropertyAddress;
