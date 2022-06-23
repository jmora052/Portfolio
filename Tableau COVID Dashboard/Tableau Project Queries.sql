--Global Data for Overview

SELECT SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, SUM(cast(new_deaths as real))/SUM(cast(new_Cases as real)) * 100 as DeathPercentage
FROM Covid_Deaths
WHERE continent IS NOT NULL 
ORDER BY total_cases, total_deaths


--Overview Data by Continent for Bar Graph

SELECT location, SUM(new_deaths) as TotalDeaths
FROM Covid_deaths
WHERE continent IS NULL
    AND location not in ("World", "European Union", "International")
GROUP BY location
ORDER BY TotalDeaths desc


--Percent Infected for Geographical Analysis
--Will be organized by Country in Tableau.

SELECT location, population, MAX(total_cases) as HighestInfectionCount, cast(total_cases as real)/cast(population as real) * 100 as PercentPopulationInfected
FROM Covid_deaths
GROUP BY location
ORDER BY PercentPopulationInfected desc


--Percent Infected by Date
--For visualizing infection rate over time per Country.

SELECT location, population, date, MAX(total_cases) as HighestInfectionCount, cast(total_cases as real)/cast(population as real) * 100 as PercentPopulationInfected
FROM Covid_deaths
GROUP BY location, date
ORDER BY PercentPopulationInfected desc
