-- Visualize the two datasets to begin data exploration
select *
from PortfolioProject..CovidDeaths

select *
from PortfolioProject..CovidVax

-- Data Exploration

select location, date, population, total_cases, total_deaths, total_tests
from PortfolioProject..CovidDeaths
order by 1, 2

-- Does population ever change?
-- Answer: The population never changes.
select location
from PortfolioProject..CovidDeaths
group by location
having min(population) != max(population)
order by location

-- Total cases and deaths per continent and economic status
-- Note: Many of the columns with numerical values are actually stored as strings/nvarchars which messes with arithmetic and sorting
select location, date, total_cases, total_deaths, total_tests
from PortfolioProject..CovidDeaths
where continent is null and date = '2023-04-12 00:00:00.000'
order by cast(total_deaths as int) desc

select location as country, date, people_fully_vaccinated, total_boosters, stringency_index, handwashing_facilities, hospital_beds_per_thousand
from PortfolioProject..CovidVax
where continent is not null
order by country

select location, date
from PortfolioProject..CovidVax
where continent is not null

select location, date, total_cases, icu_patients, hosp_patients
from PortfolioProject..CovidDeaths
where hosp_patients is not null
order by 1 asc, 2 desc

create view PercentPopulationVaccinated as
select dea.continent, dea.location, dea.date, dea.population, dea.total_cases, vax.new_vaccinations,
	sum(cast(vax.new_vaccinations as float)) over (partition by dea.location order by dea.location, dea.date) as RollingVaxed
from PortfolioProject..CovidDeaths dea
join PortfolioProject..CovidVax vax
	on dea.location = vax.location
	and dea.date = vax.date
where dea.continent is not null

-- Total Cases vs Total Deaths per Country

-- % of cases that are fatal as of March 31, 2023
Select Location, date, total_cases, total_deaths, (CAST(total_deaths as FLOAT) / CAST(total_cases as FLOAT)) * 100 as DeathPercentage
From PortfolioProject..CovidDeaths
where date = '2023-03-31 00:00:00.000'
Order by DeathPercentage desc

-- % of total population infected as of March 31, 2023
Select Location, date, Population, total_cases, (CAST(total_deaths as FLOAT) / Population) * 100 as InfectedPercentage
From PortfolioProject..CovidDeaths
where date = '2023-03-31 00:00:00.000'
Order by InfectedPercentage desc

Select Location, Population, MAX(total_cases) as HighestInfectionCount,
	(MAX(CAST(total_cases as FLOAT)) / Population) * 100 as MaxPercentPopulationInfected
from PortfolioProject..CovidDeaths
group by Location, Population
order by 1, 2

Select Location, MAX(CAST(total_deaths as int)) as TotalDeathCount
from PortfolioProject..CovidDeaths
where continent is not null
group by Location
order by TotalDeathCount desc

Select Location, MAX(CAST(total_deaths as int)) as TotalDeathCount
from PortfolioProject..CovidDeaths
where continent is null
group by Location
order by TotalDeathCount desc

select date, sum(cast(total_cases as int)) as GlobalCases, sum(cast(total_deaths as int)) as GlobalDeaths,
	sum(cast(total_deaths as float)) / sum(cast(total_cases as float)) * 100 as GlobalDeathPercentage
from PortfolioProject..CovidDeaths
where continent is not null
group by date
order by date

with PopvsVac (Continent, Location, Date, Population, Total_Cases, New_Vaccinations, RollingVaxed)
as
(
-- Rolling count of vaccinations
select dea.continent, dea.location, dea.date, dea.population, dea.total_cases, vax.new_vaccinations,
	sum(cast(vax.new_vaccinations as float)) over (partition by dea.location order by dea.location, dea.date) as RollingVaxed
from PortfolioProject..CovidDeaths dea
join PortfolioProject..CovidVax vax
	on dea.location = vax.location
	and dea.date = vax.date
where dea.continent is not null
)
select *, (RollingVaxed / Population) * 100 as PercentRollingVaxed
from PopvsVac
order by PercentRollingVaxed desc

drop table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
Total_Cases numeric,
New_Vaccinations numeric,
RollingVaxed numeric
)

Insert into #PercentPopulationVaccinated
select dea.continent, dea.location, dea.date, dea.population, dea.total_cases, vax.new_vaccinations,
	sum(cast(vax.new_vaccinations as float)) over (partition by dea.location order by dea.location, dea.date) as RollingVaxed
from PortfolioProject..CovidDeaths dea
join PortfolioProject..CovidVax vax
	on dea.location = vax.location
	and dea.date = vax.date
where dea.continent is not null

select *
from #PercentPopulationVaccinated

create view PercentPopulationVaccinated as
select dea.continent, dea.location, dea.date, dea.population, dea.total_cases, vax.new_vaccinations,
	sum(cast(vax.new_vaccinations as float)) over (partition by dea.location order by dea.location, dea.date) as RollingVaxed
from PortfolioProject..CovidDeaths dea
join PortfolioProject..CovidVax vax
	on dea.location = vax.location
	and dea.date = vax.date
where dea.continent is not null
go

select *
from PercentPopulationVaccinated

-- Paradigms Start

/*
Paradigms to understand the global situation
1. Country Response: people_fully_vaccinated, hospital_beds, handwashing_facilities, stringency_index
2. Country Health: female_smokers, male_smokers, cardiovasc_death_rate, diabetes_prevalence, life_expectancy, median_age
3. Country Capabilities: gdp_per_capita, extreme_poverty, human_development_index
4. Covid Statistics total_cases, total_deaths, positive_rate, icu_patients, hosp_patients
*/

/*
PARADIGM 1

Country Response: How well a country responded to COVID
- Measured on 5 standards: people_fully_vaccinated, total_boosters, stringency_index, handwashing_facilities, and hospital_beds_per_thousand


Issues:
- There are many NULL fields for a country's April 12, 2023 update.
	- Retrieve the MAX() recorded people_fully_vaccinated and total_boosters as it is akin to retrieving the last updated record
	- The last recorded stringency index, handwashing facilities, and hospital beds do not reflect a country's overall efforts. AVG() is better, so we will use that, but it is also imperfect due to the sheer amount of NULLs the dataset has. Given our circumstances, it is the best option.
*/

create view CountryResponse as
select a.country, a.people_fully_vaccinated, a.total_boosters, a.avg_stringency_index, a.avg_handwashing_facilities, a.avg_hospital_beds_per_thousand, b.population, b.total_tests
from
(select location as country, max(cast(people_fully_vaccinated as int)) as people_fully_vaccinated, max(cast(total_boosters as int)) total_boosters,
	round(avg(cast(stringency_index as float)), 2) as avg_stringency_index,
	round(avg(cast(handwashing_facilities as float)), 2) as avg_handwashing_facilities,
	round(avg(cast(hospital_beds_per_thousand as float)), 2) as avg_hospital_beds_per_thousand
from PortfolioProject..CovidVax
where continent is not null
group by location) as a
inner join 
(select location, max(population) as population, max(total_tests) as total_tests
from PortfolioProject..CovidDeaths
group by location) as b
on a.country = b.location
go

select *
from CountryResponse
order by country

/*
PARADIGM 2

Country Health: How healthy the inhabitants of a country are
- Measured on 6 standards: female_smokers, male_smokers, cardiovasc_death_rate, diabetes_prevalence, life_expectancy, median_age

Issues:
- These statistics change, some perhaps due to COVID and some not. How do we represent the ones that change with time?
     - Solution: AVG() the ones that change with time. The ones that don't change will still = to itself after the AVG().
*/

create view CountryHealth as
select location as country, round(avg(cast(female_smokers as float)), 2) as avg_female_smokers, round(avg(cast(male_smokers as float)), 2) as avg_male_smokers,
	round(avg(cast(cardiovasc_death_rate as float)), 2) as avg_cardiovasc_death_rate, round(avg(cast(diabetes_prevalence as float)), 2) as avg_diabetes_prevalence,
	round(avg(cast(life_expectancy as float)), 2) as life_expectancy, round(avg(cast(median_age as float)), 2) as median_age
from PortfolioProject..CovidVax
where continent is not null
group by location
go

select *
from CountryHealth
order by country

/*
PARADIGM 3

Country Capabilities: How well-equipped a country is in terms of its resources and finances
- Measured on 3 standards: gdp_per_capita, extreme_poverty, human_development_index
*/

create view CountryCapabilities as
select location as country, max(cast(gdp_per_capita as float)) as gdp_per_capita, max(cast(extreme_poverty as float)) as extreme_poverty, max(cast(human_development_index as float)) as human_development_index
from PortfolioProject..CovidVax
where continent is not null
group by location
go

select *
from CountryCapabilities
order by country

/*
PARADIGM 4

Covid Statistics: All the important statistics, as of April 12, 2023, that are the "outputs" of the COVID situation. The other three paradigms are "inputs".
- This is the table where we see the results of a country's capabilities, health, and responses.
- Measured on 7 standards: total_cases, total_deaths, % mortality, positive_rate, icu_patients, hosp_patients, % hospitalized
*/

create view CovidStatistics as
select a.location as country, a.total_deaths, a.total_cases,
	cast(a.total_deaths as float) / cast(a.total_cases as float) * 100 as mortality_rate,
	a.avg_icu_patients, a.avg_hosp_patients
from
(select location, max(population) as population, max(cast(total_cases as int)) as total_cases, max(cast(total_deaths as int)) as total_deaths,
	round(avg(cast(icu_patients as float)), 2) as avg_icu_patients,
	round(avg(cast(hosp_patients as float)), 2) as avg_hosp_patients
from CovidDeaths
where continent is not null
group by location) as a
go

select *
from PortfolioProject..CovidStatistics
order by country

select *
from CountryResponse

-- Paradigms End

/*
Master Table that combines all 4 Paradigms
- Helps visualize the correlation between Country Response, Preparedness, and Health vs Covid Statistics
*/

select *
from PortfolioProject..CovidStatistics as a
inner join PortfolioProject..CountryResponse as b
on a.country = b.country
inner join PortfolioProject..CountryHealth as c
on c.country = b.country
inner join PortfolioProject..CountryCapabilities as d
on d.country = c.country
order by a.country