/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор:Постнова Ю.Д.
 * Дата:18.11.2025
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Оставляем только валидные id
raw AS (
    SELECT
        a.id AS ad_id,
        a.first_day_exposition::date AS first_day,
        a.days_exposition,
        a.last_price,
        f.total_area,
        f.rooms,
        f.balcony,
        f.ceiling_height,
        f.floor,
        f.floors_total,
        c.city,
        t.type AS place_type,
        a.last_price/ f.total_area::numeric AS price_per_m2
    FROM real_estate.advertisement AS a
    INNER JOIN filtered_id USING(id)
    INNER JOIN real_estate.flats AS f USING(id)
    LEFT JOIN real_estate.city AS c USING(city_id)
    LEFT JOIN real_estate.TYPE AS t USING(type_id)
),
ad_categories AS (
	SELECT 
		CASE 
			WHEN days_exposition IS NULL THEN 'active'
			WHEN days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
			WHEN days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
			WHEN days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
			WHEN days_exposition >= 181 THEN '181+ days'
		END AS activity_category,
		CASE
            WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'ЛенОбл'
        END AS region,
        *
	FROM raw
	WHERE 
		place_type = 'город' 
		AND first_day BETWEEN DATE '2015-01-01' AND DATE '2018-12-31'
		AND price_per_m2 IS NOT NULL AND price_per_m2 > 0
)
SELECT 
	a.region,
	activity_category,
	COUNT(*) AS number_of_ads,
	ROUND((COUNT(*) / SUM(COUNT(*)) OVER())::numeric, 2) AS share_total,
	ROUND((COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY region))::numeric, 2) AS share_region,
	ROUND(AVG(price_per_m2)::numeric, 2) AS avg_price_per_m2,
	ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_per_m2)::numeric, 2) AS median_price_per_m2,
	ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
	ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_area)::numeric, 2) AS median_total_area,
	ROUND(AVG(rooms)::numeric, 2) AS avg_rooms,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms)::numeric, 2) AS median_rooms,
    ROUND(AVG(balcony)::numeric, 2) AS avg_balcony,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony)::numeric, 2) AS median_balcony,
    ROUND(AVG(ceiling_height)::numeric, 2) AS avg_ceiling_height,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor)::numeric, 2) AS median_floor
FROM ad_categories AS a
GROUP BY a.region, a.activity_category
ORDER BY region DESC, activity_category;


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
 -- Оставляем только валидные id
raw AS (
    SELECT
        a.first_day_exposition::date AS first_day,
        a.days_exposition,
        a.last_price,
        f.total_area,
        t.type AS place_type,
        a.last_price/ f.total_area::numeric AS price_per_m2
    FROM real_estate.advertisement AS a
    INNER JOIN filtered_id USING(id)
    INNER JOIN real_estate.flats AS f USING(id)
    LEFT JOIN real_estate.city AS c USING(city_id)
    LEFT JOIN real_estate.TYPE AS t USING(type_id)
),
-- Добываем месяцы публикации и снятия;
with_months AS (
    SELECT
        *,
        EXTRACT(MONTH FROM first_day)::int AS month_published,
        CASE 
	        WHEN days_exposition IS NOT NULL 
	        THEN EXTRACT(MONTH FROM (first_day + (days_exposition * INTERVAL '1 day')))::int 
	        END AS month_removed
    FROM raw
    WHERE 
    	place_type = 'город' 
		AND first_day BETWEEN DATE '2015-01-01' AND DATE '2018-12-31'
		AND price_per_m2 IS NOT NULL AND price_per_m2 > 0
),
stat_pub AS(
	SELECT
		month_published AS month_num,
		COUNT(*) AS cnt_published,
		ROUND(AVG(price_per_m2)::numeric, 2) AS avg_price_per_m2_published,
		ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_per_m2)::numeric, 2) AS median_price_per_m2_published,
        ROUND(AVG(total_area)::numeric, 2) AS avg_total_area_published,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_area)::numeric, 2) AS median_total_area_published
	FROM with_months
	GROUP BY month_published
),
stat_rem AS (
	SELECT
		month_removed AS month_num,
		COUNT(*) AS cnt_removed,
		ROUND(AVG(price_per_m2)::numeric, 2) AS avg_price_per_m2_removed,
		ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_per_m2)::numeric, 2) AS median_price_per_m2_removed,
        ROUND(AVG(total_area)::numeric, 2) AS avg_total_area_removed,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_area)::numeric, 2) AS median_total_area_removed
	FROM with_months
	WHERE days_exposition IS NOT NULL
	GROUP BY month_removed
)
SELECT 
	COALESCE(sp.month_num, sr.month_num) AS month_num,
	TO_CHAR(
            TO_DATE(COALESCE(sp.month_num, sr.month_num)::text, 'MM'),
            'Month') AS month_name,
	COALESCE(sp.cnt_published, 0) AS cnt_published,
	avg_price_per_m2_published,
	median_price_per_m2_published,
	avg_total_area_published,
	median_total_area_published,
	COALESCE(sr.cnt_removed, 0) AS cnt_removed,
    avg_price_per_m2_removed,
    median_price_per_m2_removed,
    avg_total_area_removed,
    median_total_area_removed
FROM stat_pub AS sp
FULL JOIN stat_rem AS sr USING(month_num)
ORDER BY month_num












   

