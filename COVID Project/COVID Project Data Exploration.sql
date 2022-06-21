-- Checking NULL values

SELECT *
FROM COVID_Deaths
WHERE continent IS NULL
ORDER BY location, date


-- Select Data that we'll be working with, location, date,
-- total_cases, new_cases, total_deaths, population

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM Covid_Deaths
WHERE continent IS NOT NULL 
ORDER BY location, date


-- Realizing that date is stored as MM/DD/YY, unsupported by my SQL client. 
-- Updating date column from MM/DD/YY to YYYY/MM/DD.
-- Going back to Excel to fix this because Excel is much quicker than substring parsing.

DROP TABLE IF EXISTS COVID_Deaths
DROP TABLE IF EXISTS Vaccinations

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM Covid_Deaths
WHERE continent IS NOT NULL 
ORDER BY location, date
-- We did it.


-- Calculating Total Cases vs Total Deaths
-- Shows likelihood of dying if you contract COVID in your country
-- changing "WHERE location LIKE" to your country.

-- Because my SQL client rounds integer division, decimals are rounded to 0
-- therefore, we had to cast total_cases and total_deaths as real.

SELECT location, date, total_cases, total_deaths, (cast(total_deaths as real)/cast(total_cases as real)) * 100 as infected_death_rate
FROM COVID_Deaths
WHERE location LIKE "%states%"
AND continent IS NOT NULL
ORDER BY location, date


-- Calculating Total Cases vs Population
-- Shows what percentage of the population infected with COVID at a given date.

SELECT location, date, population, total_cases, cast(total_cases as real)/cast(population as real) * 100 as population_infected_percent
FROM Covid_Deaths
WHERE location LIKE "%states%"
ORDER BY location, date


-- Countries with Highest Infection Rate compared to Population

SELECT location, population, MAX(total_cases) as top_infection_count, MAX((cast(total_cases as real)/cast(population as real))) * 100 as infected_rate
FROM Covid_Deaths
GROUP BY location, population
ORDER BY infected_rate desc


-- Countries with Highest Death Rate per Population. What percent of the population died?

SELECT location, population, MAX(total_deaths) as top_death_count, MAX((cast(total_deaths as real)/cast(population as real))) * 100 as percent_deceased
FROM COVID_Deaths
WHERE continent IS NOT NULL 
GROUP BY location
ORDER BY percent_deceased desc


-- Breaking Things down by Continent
-- Showing continents with the highest death rate per population.
-- We can see that Europe suffered the biggest loss of life compared to their population.

SELECT continent, population, MAX(total_deaths) as top_death_count, MAX((cast(total_deaths as real)/cast(population as real))) * 100 as percent_deceased
From Covid_Deaths
WHERE continent IS NOT NULL 
GROUP BY continent
ORDER BY percent_deceased desc


-- And calculated total Global Numbers

SELECT SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, SUM(cast(new_deaths as real))/SUM(cast(new_cases as real)) * 100 as infected_death_rate
FROM Covid_Deaths
WHERE continent IS NOT NULL


-- Count of vaccinations, joining COVID_Deaths and Vaccinations tables.
-- Adding a rolling count of vaccinations per country with an OVER clause.

SELECT COVID_Deaths.continent, COVID_Deaths.location, COVID_Deaths.date, COVID_Deaths.population, Vaccinations.new_vaccinations,
SUM(Vaccinations.new_vaccinations) OVER (PARTITION BY COVID_Deaths.location ORDER BY COVID_Deaths.location, COVID_Deaths.date) as RollingPeopleVaccinated
FROM COVID_Deaths
JOIN Vaccinations
	ON COVID_Deaths.location = Vaccinations.location
	AND COVID_Deaths.date = Vaccinations.date
WHERE COVID_Deaths.continent IS NOT NULL 
ORDER BY COVID_Deaths.location, COVID_Deaths.date


-- Using CTE to perform calculation on PARTITION BY in previous query

With PopvsVac (continent, location, date, population, new_vaccinations, RollingPeopleVaccinated)
as
(SELECT COVID_Deaths.continent, COVID_Deaths.location, COVID_Deaths.date, COVID_Deaths.population, Vaccinations.new_vaccinations,
SUM(Vaccinations.new_vaccinations) OVER (PARTITION BY COVID_Deaths.location ORDER BY COVID_Deaths.location, COVID_Deaths.date) as RollingPeopleVaccinated
FROM COVID_Deaths
JOIN Vaccinations
	ON COVID_Deaths.location = Vaccinations.location
	AND COVID_Deaths.date = Vaccinations.date
WHERE COVID_Deaths.continent IS NOT NULL 
ORDER BY COVID_Deaths.location, COVID_Deaths.date
)
Select *, (cast(RollingPeopleVaccinated as real)/cast(Population as real)) * 100
From PopvsVac


-- We can also use a Temp Table to perform calculations on PARTITION BY in previous query.
-- We'll create a table with the column attributes we want and insert our values into it.

DROP TABLE IF EXISTS PercentPopulationVaccinated;
CREATE TEMP TABLE PercentPopulationVaccinated
(
continent nvarchar(255),
location nvarchar(255),
date datetime,
population real,
new_vaccinations real,
RollingPeopleVaccinated real
);

INSERT INTO PercentPopulationVaccinated
SELECT COVID_Deaths.continent, COVID_Deaths.location, COVID_Deaths.date, COVID_Deaths.population, Vaccinations.new_vaccinations
, SUM(Vaccinations.new_vaccinations) OVER (PARTITION BY COVID_Deaths.Location ORDER BY COVID_Deaths.location, COVID_Deaths.Date) as RollingPeopleVaccinated
FROM Covid_Deaths
JOIN Vaccinations
	ON COVID_Deaths.location = Vaccinations.location
	AND COVID_Deaths.date = Vaccinations.date
WHERE COVID_Deaths.continent IS NOT NULL 
ORDER BY COVID_Deaths.location, COVID_Deaths.date;

SELECT *, (RollingPeopleVaccinated/population) * 100 AS PercentPopulationVaccinated
FROM PercentPopulationVaccinated


-- Creating View to store data for visualization in Tableau

CREATE VIEW PercentPopulationVaccinated AS
SELECT COVID_Deaths.continent, COVID_Deaths.location, COVID_Deaths.date, COVID_Deaths.population, Vaccinations.new_vaccinations
, SUM(Vaccinations.new_vaccinations) OVER (PARTITION BY COVID_Deaths.Location ORDER BY COVID_Deaths.location, COVID_Deaths.Date) AS RollingPeopleVaccinated
FROM COVID_Deaths
JOIN Vaccinations
	ON COVID_Deaths.location = Vaccinations.location
	AND COVID_Deaths.date = Vaccinations.date
WHERE COVID_Deaths.continent IS NOT NULL
