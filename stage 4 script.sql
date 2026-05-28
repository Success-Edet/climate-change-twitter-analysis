create table climate_dataset( 
created_at timestamp, 
id bigint, 
lng numeric, 
lat numeric, 
topic text, 
sentiment numeric, 
stance text, 
gender text, 
temperature_avg numeric, 
aggresiveness text 
); 
alter table climate_dataset
rename column aggresiveness to aggressiveness;

select * from climate_dataset; 
-- ========================================== 
--Part 1 : Data Understanding and Preparation 

-- ========================================== -- previewing dataset 
select *  
from climate_dataset; 
-- Range of date 
select 
min (created_at) as earliest_date, 
max (created_at) as latest_date 
from climate_dataset; 

-- identifying distict categorical columns 
select 
count (distinct topic) as unique_topic, 
count (distinct stance) as unique_stance, 
count (distinct gender) as unique_gender, 
count (distinct aggressiveness) as unique_aggressiveness 
from climate_dataset; 

select  
distinct topic 
from climate_dataset; 

-- range of sentiment score in dataset 
select 
min (sentiment) as least_score, 
max (sentiment) as highest_score 
from climate_dataset; 

-- checking for missing values  
select 
count (*) as total_rows, 
count(*) filter (where created_at is null) missing_dates, 
count(*) filter (where id is null) as missing_id, 
count(*) filter (where lng is null) as missing_lng, 
count(*) filter (where lat is null) as missing_lat, 
count(*) filter (where topic is null) as missing_topic, 
count(*) filter (where sentiment is null) as missing_sentiment, 
count(*) filter (where gender is null) as undefined_gender, 
count(*) filter (where temperature_avg is null) as missing_temp, 
count(*) filter (where stance is null) as missing_stance, 
count(*) filter (where aggressiveness is null) as missing_aggressiveness 
from climate_dataset; 

-- counting undefined genders 
select  
count(*) as undefined_gender_count 
from climate_dataset 
where gender = 'undefined'; 

-- checking for duplicates (using the key identifier) 
select id, 
count(*) as dupicated_id 
from climate_dataset 
group by id  
having count(*) > 1;

-- ================================================= 
-- PART 2: Data Wrangling and Transformation 
-- ================================================= 
--2.1 standardizing  text columns to lower case

update climate_dataset
set
topic = lower(topic),
stance = lower(stance),
gender = lower(gender),
aggressiveness = lower(aggressiveness);

-- updating the topic coulmn
update climate_dataset
set topic = 'importance of human intervention'
where topic = 'importance of human intervantion';

-- checking
select  
distinct topic 
from climate_dataset; 


-- 2.1.2 standardizing text column to trim spaces

update climate_dataset
set
topic = trim(topic),
stance = trim(stance),
gender = trim(gender),
aggressiveness = trim(aggressiveness);

-- 2.2 Adding derived columns
-- extraction 0f year, month, and time_period

alter table climate_dataset
add column  year int,
add column month int,
add column time_period text;

update climate_dataset
set 
year = extract(year from created_at),
month = extract (month from created_at),
time_period = case
when extract(year from created_at)between 2006 and 2010  then 'early'
when extract(year from created_at) between 2011 and 2015 then 'mid'
when extract(year from created_at) between 2016 and 2019 then 'late'
else 'unknown'
end;

-- checking the latest update
select * from climate_dataset; 

select  
count(*) as unknown_time_period 
from climate_dataset 
where time_period = 'unknown';-- no unkmown time period

-- adding the region column

select 
min (lng) as least_lng, 
max (lng) as highest_lng,
min (lat) as least_lat,
max (lat) as highest_lat
from climate_dataset; 

alter table climate_dataset
add column region text;

update climate_dataset
set region = case
-- unknown
when lat is null or lng is null then 'unknown'
-- africa
when  lat between -35 and 38 and lng between -20 and 55 then 'africa'
-- south america
when  lat between -60 and 15 and lng between -90 and -30 then 'south_america'
-- north america
when  lat between 15 and 85 and lng between -179 and -50 then 'north_america'
-- asia
when  lat between 5 and 85 and lng between 60 and 180 then 'asia'
-- europe
when  lat between -35 and 75 and lng between -25 and 60 then 'europe'
-- oceania
when  lat between -50 and 10 and lng between 110 and 180 then 'oceania'
else 'other'
end;

-- checking
select
count (*) as other_region
from climate_dataset
where region = 'other';
-- 33,011 rows have cordinates but unknown regions which makes about 0.6% of the rows with cordinates

-- adding columnto categorize sentiment
-- inspecting dentiment percentile distribution
select
avg (sentiment),
percentile_cont (0.25) within group (order by sentiment) as p25,
percentile_cont (0.5) within group (order by sentiment) as median,
percentile_cont (0.75) within group (order by sentiment) as p75
from climate_dataset;

alter table climate_dataset
add column sentiment_category text;

update climate_dataset
set sentiment_category =
case 
when sentiment <= (
select 
percentile_cont (0.25) within group (order by sentiment) 
					from climate_dataset )
					then 'negative'
when sentiment >= (
select
percentile_cont (0.75) within group (order by sentiment)
from climate_dataset)
then 'positive'
else 'neutral'
end;
-- checking

select sentiment_category,
count (*)
from climate_dataset
group by sentiment_category;

-- 2.3
-- creating views
--- creating overall view

create view c_climate_dataset as
select 
id,
topic,
year,
month,
time_period,
stance,
gender,
sentiment,
sentiment_category,
aggresiveness,
lng,
lat,
region,
temperature_avg
from climate_dataset;

alter view c_climate_dataset
rename column aggresiveness to aggressiveness;

select * from c_climate_dataset;

-- creating view for regional_analysis
drop view regional_analysis;

create view regional_analysis as 
select
id,
topic,
year,
month,
time_period,
stance,
gender,
sentiment,
sentiment_category,
aggresiveness,
lng,
lat,
region,
temperature_avg
from climate_dataset 
where region != 'unknown'; -- this also removes the null lng and lat

alter view regional_analysis
rename column aggresiveness to aggressiveness;

-- checking
select * from regional_analysis;

-- creating index to optimize performance

create index ind_created_at on climate_dataset(created_at);
create index ind_year on climate_dataset(year);
create index ind_sentiment_category on climate_dataset(sentiment_category);
create index ind_topic on climate_dataset(topic);
create index ind_region on climate_dataset(region);
create index ind_gender on climate_dataset(gender);
create index ind_aggressiveness on climate_dataset(aggressiveness);

-- =========================================
-- Part 3 : Descriptive Analytics (what is happening in this dataset)
-- =========================================

-- 3.1 summary statictis (counts, averages, distributions)

-- 3.1.1: total volume
select
count (*) as total_records
from c_climate_dataset; -- 15789411 rows

-- 3.1.2 sentiment summary
select
count (*) as total_sentiment,
avg (sentiment) as avg_sentiment,
min (sentiment) as min_sentiment,
max (sentiment) as max_sentiment
from c_climate_dataset;

-- sentiment distribution acorss the sentiment_category
select
sentiment_category,
count(*),
round (avg(sentiment) :: numeric, 2) as avg_sentiment,
round (min(sentiment) :: numeric, 2) as min_sentiment,
round (max(sentiment) :: numeric, 2) as max_sentiment
from c_climate_dataset
group by sentiment_category
order by avg_sentiment desc;

-- 3.1.3 topic summary

select
topic, 
count (*)
from c_climate_dataset
group by topic
order by topic desc; -- weather extremes has the highest count, most discused

select
distinct topic
from c_climate_dataset; -- total distinct topics documented are 10

-- how people feel about each topic
select 
topic,
avg(sentiment) as avg_sentiment
from c_climate_dataset
group by topic
order by avg_sentiment desc; -- most positive topics is undefined/ one word hashtags
							-- the most negative is ideological positions on global warming

-- how sentiment is spread per topic
select
topic,
sentiment_category,
count(*) as total
from c_climate_dataset
group by topic, sentiment_category
order by  sentiment_category desc;

-- 3.13 region summary
-- will be using the region analysis view

-- which region contributes the most to the conversation
select
region,
count(*) as total_region
from regional_analysis
group by region
order by total_region desc; -- north america contributed the most, the least os the other region

-- how does each region feel about climate change
select
region,
avg(sentiment) as avg_sentiment
from regional_analysis
group by region
order by avg_sentiment; -- thouh north america contribute a lot to the discusion, they have a negative recation
-- most the asians are averagely positive

-- which region have more aggresive tweets
select
region,
aggressiveness,
count (*) as total
from regional_analysis
group by region, aggressiveness
order by region , aggressiveness desc; -- north america have the most addresive tweets,

-- 3.1.4 aggressiveness summary
-- volume of aggressiveness tweet
select
aggressiveness,
count(*) as total
from c_climate_dataset
group by aggressiveness
order by total desc; -- not aggressive tweet is more than the aggrsive  tweets

-- on the average are aggressive tweet more negative?
select
aggressiveness,
avg (sentiment) as avg_sentiment
from c_climate_dataset
group by aggressiveness; -- aggresion is strongly associated with negative sentiment

--which topics are drivig aggresive discourse

select
topic,
aggressiveness,
count (*) as total,
round(
count(*) * 100.0 / sum(count(*)) over (partition by topic),2
)
as percentage
from c_climate_dataset
group by aggressiveness, topic
order by topic, percentage desc; -- global stance and politics are driving the most aggresive discourses

-- distribution of gender
select
gender,
count(*) as total_tweets
from c_climate_dataset
group by gender
order by total_tweets desc; -- male make more tweets than females

-- stance distribution
 select
 stance,
 count(*) as total_tweets,
 round (count(*) * 100.0/ sum(count(*)) over (), 2) as tweet_percentage
 from c_climate_dataset
 group by stance
 order by total_tweets;
 
-- ======================================
-- 3.2: time trends and patterns
-- ======================================

-- how has public opinion changed over 13 years
select
year,
count(*) as total_tweets
from c_climate_dataset
group by year
order by total_tweets desc; -- volume of tweets increased zizzagly the years with 2018 having the highest year

-- has aggressiveness increased or decreased over time?
select * from climate_dataset;
select
year,
count(*) filter (where aggressiveness = 'aggressive') as agggresive_count,
count(*) as total_tweets,
round(
count(*) filter (where aggressiveness = 'aggressive') * 100.0 /count(*), 2
) as aggression_rate
from c_climate_dataset
group by year
order by aggression_rate desc; -- agression has decreased over the  years, highest aggression rate is 2006

-- sentiment and aggressiveness by time_period
select
time_period,
count(*)as total_tweets,
round(avg(sentiment) :: numeric,4) as avg_sentiment,
round(stddev_samp (sentiment) :: numeric,4) as sentiment_deviation,
round(count(*) filter (where aggressiveness = 'aggressive')* 100.0 / count(*) , 2) as aggressive_rate,
mode() within group (order by sentiment_category) as dominant_sentiment,
mode() within group (order by stance) as dominant_stance
from c_climate_dataset
group by time_period
order by time_period;-- small rise in middle period but dropped in late period, it has decreased

-- =============
-- patterns
-- =============

-- is there a relationship between negative sentiment and agression?
select
sentiment_category,
count(*) as total_tweets,
count(*) filter (where aggressiveness = 'aggressive') as aggressive_tweets,
round(count(*) filter (where aggressiveness = 'aggressive')* 100.0 / count(*) , 2) as aggressive_rate
from c_climate_dataset
group by sentiment_category
order by aggressive_rate desc;-- tweets classified as negative show higher proportion of agressiveness
							-- positive tweets are the least agressive
							
-- what gender is more aggressive in posting

select
gender,
count(*) filter (where aggressiveness = 'aggressive') as aggressive_tweets,
round(count(*) filter (where aggressiveness = 'aggressive')* 100.0 / count(*) , 2) as aggressive_rate
from c_climate_dataset
group by gender
order by aggressive_rate desc;-- male give more aggressive tweets

-- what is the stance of the gender most aggressive in posting
select
gender,
stance,
count(*) filter (where aggressiveness = 'aggressive') as aggressive_tweets,
round(count(*) filter (where aggressiveness = 'aggressive')* 100.0 / count(*) , 2) as aggressive_rate
from c_climate_dataset
group by gender, stance
order by aggressive_rate desc;  --though the male believer makes more post, the male whos denier makes more agressive post

-- what topic gives the most agression
select
topic,
count(*) filter (where aggressiveness = 'aggressive') as aggressive_tweets,
round(count(*) filter (where aggressiveness = 'aggressive')* 100.0 / count(*) , 2) as aggressive_rate
from c_climate_dataset
group by topic
order by aggressive_rate desc; -- politics drives the most agression, with pollution awareness driving the last

-- what region gives the most agression
select
region,
count(*) filter (where aggressiveness = 'aggressive') as aggressive_tweets,
round(count(*) filter (where aggressiveness = 'aggressive')* 100.0 / count(*) , 2) as aggressive_rate
from regional_analysis
group by region
order by aggressive_rate desc;-- north korea have the highest aggression rate

-- ===============================
-- 3.3: exploraton of key variables
-- ===============================
-- sentiment exploration
--1. what is the range of sentiment

select
min(sentiment),
max(sentiment),
avg(sentiment)
from c_climate_dataset;

--1.1. what is the range of sentiment_category 
select
sentiment_category,
count(*)
from c_climate_dataset
group by sentiment_category;

-- 2: how many unique topics are there
select
count(distinct topic) as total_topics
from c_climate_dataset;-- there re 10 distinct topics

-- what are the top topics
select
topic,
count(*)
from c_climate_dataset
group by topic
order by count(*) desc --global stance is the top topic
limit 10;

-- 3 Region exploration
-- which region makes more tweets
select
region,
count(*)
from c_climate_dataset
group by region
order by count(*) desc;-- people that make more tweets have missing coordinates

-- stance exoloration
select
stance,
count(*)
from c_climate_dataset
group by stance; -- we have more tweets of people who's are believers

-- aggressiveness
select
aggressiveness,
count(*)
from c_climate_dataset
group by aggressiveness; -- not aggressive tweets are more than the aggrssive tweets


-- ========================================
-- Part 4: Diagonistic analysis
-- ========================================
-- why are some topics more agressive than others
with topic_profile as(
select
topic,
count(*) as total_tweets,
round(avg(sentiment) :: numeric, 4) as avg_sentiment,
round(stddev_samp(sentiment) :: numeric, 4) as sentiment_spread,
count(distinct stance) as stance_variety,
round(count(*) filter (where aggressiveness = 'aggressive')*100.0/ count(*), 2) as aggression_rate,
mode() within group(order by stance) as dominant_stance
from c_climate_dataset
group by topic
)
select *,
rank()over(order by aggression_rate desc,sentiment_spread desc) as divisiveness_rank
from topic_profile
order by divisiveness_rank; -- politics is more because it has the most aggression rate, more tweets and more negative sentiment

--why are certain region more aggressive?

select
region,
count(*) as total_tweets,
round(avg(sentiment) :: numeric, 4) as avg_sentiment,
round(stddev_samp(sentiment) :: numeric, 4) as sentiment_spread,
round(count(*) filter (where aggressiveness = 'aggressive')*100.0/ count(*), 2) as aggression_rate,
mode() within group(order by topic) as top_topic,
mode() within group(order by stance) as dorminant_stance,
mode() within group(order by sentiment_category) as dorminant_sentiment
from c_climate_dataset
group by region
order by aggression_rate desc;

-- why did aggression change over time

select
year,
round(
count(*) filter (where aggressiveness = 'aggressive')*100.0/ count(*), 2 ) as aggression_rate,
avg(sentiment) as avg_sentiment
from c_climate_dataset
group by year
order by year; -- averagely sentiment began to reduce down the years, that why agression drops

-- does stance drive aggression?
select
stance,
count (*) as total_tweets,
count(*) filter (where aggressiveness = 'aggressive') as aggressive_tweets,
round(count(*) filter (where aggressiveness = 'aggressive')* 100.0 / count(*) , 2) as aggressive_rate
from c_climate_dataset
group by stance
order by aggressive_rate desc ; -- the denier belief lead more aggressive post

-- is there a correlation between temperature and sentiment
select
 round(corr(temperature_avg,sentiment):: numeric, 4) as temp_sentiment_corr,
 count(*)filter (where temperature_avg is not null) as temperature
 from c_climate_dataset;

 -- why is the male gender having the most aggresive post
 select
gender,
stance,
count(*) filter (where aggressiveness = 'aggressive') as aggressive_tweets,
round(count(*) filter (where aggressiveness = 'aggressive')* 100.0 / count(*) , 2) as aggressive_rate
from c_climate_dataset
group by gender, stance
order by aggressive_rate desc; -- because the male denier is more than female and the denier have the most aggressive_rate

-- final insights
-- 1. Negative sentiments strongly drives  aggressive  discourse
-- 2. political topics are the primary  drivers of aggression
-- 3. Aggression peaked mid-period and declined in later years
-- 4. Male deniers contribute most to aggressive communication