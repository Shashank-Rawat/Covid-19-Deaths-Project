USE [Portfolio project Covid Deaths]
GO

-- Fetching all data where the continent is not null
SELECT *
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL;

-- Selecting specific columns needed for analysis:

SELECT 
    location,
    date,
    total_cases,
    new_cases,
    total_deaths,
    population
FROM dbo.CovidDeaths
ORDER BY location, date;
GO

-- Exploring total cases vs total deaths, calculating death percentage
SELECT 
    location,
    date,
    total_cases,
    total_deaths,
    CASE 
        WHEN total_cases = 0 THEN NULL
        ELSE ROUND((total_deaths * 1.0 / total_cases) * 100, 2)
    END AS [Death Percentage]
FROM dbo.CovidDeaths
ORDER BY location, date;
GO

-- Analyzing total cases vs deaths in the United Kingdom
SELECT 
    location,
    date,
    total_cases,
    total_deaths,
    CASE 
        WHEN total_cases = 0 THEN NULL
        ELSE ROUND((total_deaths * 1.0 / total_cases) * 100, 2)
    END AS [Death Percentage]
FROM dbo.CovidDeaths
WHERE location = 'United Kingdom'
ORDER BY date;
GO

-- Exploring total cases vs population to determine infection percentage
SELECT
    location,
    date,
    total_cases,
    population,
    ROUND((total_cases / population) * 100, 2) AS [Population Infected %]
FROM dbo.CovidDeaths
ORDER BY location, date;
GO

-- Analyzing total cases vs population in the United Kingdom
SELECT
    location,
    date,
    total_cases,
    population,
    ROUND((total_cases / population) * 100, 2) AS [Population Infected %]
FROM dbo.CovidDeaths
WHERE location = 'United Kingdom'
ORDER BY date;
GO

-- Exploring countries with the highest number of cases
SELECT
    location,
    population,
    MAX(total_cases) AS [MaxInfectionCount]
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY MaxInfectionCount DESC;
GO

-- Exploring countries with the highest infection rate compared to population
SELECT
    location,
    population,
    MAX(total_cases) AS [MaxInfectionCount],
    MAX(ROUND((total_cases / population) * 100, 2)) AS [MaxPopulationInfected%]
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL 
GROUP BY location, population
ORDER BY [MaxPopulationInfected%] DESC;
GO

-- Exploring locations with the highest death count per population
SELECT
    location,
    MAX(total_deaths) AS [Total Deaths]
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY [Total Deaths] DESC;
GO

-- CONTINENT-WISE ANALYSIS ------------------------------------------

-- Exploring continents and groups with the highest number of cases
SELECT
    location,
    population,
    MAX(total_cases) AS [MaxInfectionCount]
FROM dbo.CovidDeaths
WHERE continent IS NULL
GROUP BY location, population
ORDER BY [MaxInfectionCount] DESC;
GO

-- Exploring continents and groups with the highest infection rate compared to population
SELECT
    location,
    population,
    MAX(total_cases) AS [MaxInfectionCount],
    MAX(ROUND((total_cases / population) * 100, 2)) AS [MaxPopulationInfected%]
FROM dbo.CovidDeaths
WHERE continent IS NULL 
GROUP BY location, population
ORDER BY [MaxPopulationInfected%] DESC;
GO

-- Continent-wise death count analysis
SELECT
    continent,
    MAX(total_deaths) AS [Total Deaths]
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY [Total Deaths] DESC;
GO

-- GLOBAL NUMBERS ---------------------------------------------------

-- Summing up global new cases and new deaths, calculating death percentage
SELECT 
    SUM(new_cases) AS [Total Cases], 
    SUM(CAST(new_deaths AS INT)) AS [Total Deaths], 
    ROUND(SUM(CAST(new_deaths AS INT)) / SUM(new_cases) * 100, 2) AS [DeathPercentage]
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL;
GO

-- POPULATION & VACCINATION -----------------------------------------

-- Showing the percentage of the population that has received at least one COVID vaccine
SELECT
    dt.continent, 
    dt.location, 
    dt.date, 
    dt.population, 
    vac.new_vaccinations,
    SUM(COALESCE(CONVERT(BIGINT, vac.new_vaccinations), 0)) 
        OVER (PARTITION BY dt.location ORDER BY dt.location, dt.date) AS [Cumulative Vaccinations]
FROM dbo.CovidDeaths AS dt
JOIN dbo.CovidVaccinations AS vac
    ON dt.location = vac.location
    AND dt.date = vac.date
WHERE dt.continent IS NOT NULL 
ORDER BY dt.location, dt.date;
GO

-- Using CTE to calculate cumulative vaccinations by location and date
WITH Popvsvac (Continent, Location, Date, Population, New_Vaccinations, [Cumulative Vaccinations])
AS (
    SELECT
        dt.continent, 
        dt.location, 
        dt.date, 
        dt.population, 
        vac.new_vaccinations,
        SUM(COALESCE(CONVERT(BIGINT, vac.new_vaccinations), 0)) 
            OVER (PARTITION BY dt.location ORDER BY dt.location, dt.date) AS [Cumulative Vaccinations]
    FROM dbo.CovidDeaths AS dt
    JOIN dbo.CovidVaccinations AS vac
        ON dt.location = vac.location
        AND dt.date = vac.date
    WHERE dt.continent IS NOT NULL
)
SELECT
    *,
    ROUND([Cumulative Vaccinations] / Population * 100, 2) AS [VaccinatedPopulationPercentage]
FROM Popvsvac;
GO

-- Using Temp Table to calculate cumulative vaccinations and population vaccinated percentage
DROP TABLE IF EXISTS #PopulationvaccinatedPercentage;

CREATE TABLE #PopulationvaccinatedPercentage
(
    Continent NVARCHAR(100),
    Location NVARCHAR(100),
    Date DATETIME,
    Population NUMERIC,
    New_Vaccination NUMERIC,
    [Cumulative Vaccinations] NUMERIC
);

INSERT INTO #PopulationvaccinatedPercentage
SELECT
    dt.continent, 
    dt.location, 
    dt.date, 
    dt.population, 
    vac.new_vaccinations,
    SUM(COALESCE(CONVERT(BIGINT, vac.new_vaccinations), 0)) 
        OVER (PARTITION BY dt.location ORDER BY dt.location, dt.date) AS [Cumulative Vaccinations]
FROM dbo.CovidDeaths AS dt
JOIN dbo.CovidVaccinations AS vac
    ON dt.location = vac.location
    AND dt.date = vac.date
WHERE dt.continent IS NOT NULL;

SELECT
    *,
    ROUND([Cumulative Vaccinations] / Population * 100, 3) AS [VaccinatedPopulationPercentage]
FROM #PopulationvaccinatedPercentage;
GO

-- Creating a view to store data for visualization
CREATE VIEW PercentagePopulationVaccinated AS
SELECT
    dt.continent, 
    dt.location, 
    dt.date, 
    dt.population, 
    vac.new_vaccinations,
    SUM(COALESCE(CONVERT(BIGINT, vac.new_vaccinations), 0)) 
        OVER (PARTITION BY dt.location ORDER BY dt.location, dt.date) AS [Cumulative Vaccinations]
FROM dbo.CovidDeaths AS dt
JOIN dbo.CovidVaccinations AS vac
    ON dt.location = vac.location
    AND dt.date = vac.date
WHERE dt.continent IS NOT NULL;
GO

-- Querying data from the created view
SELECT * FROM PercentagePopulationVaccinated;
GO