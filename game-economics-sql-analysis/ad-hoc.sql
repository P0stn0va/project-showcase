/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Постнова Ю.Д.
 * Дата: 22.10.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT 
		COUNT(id) AS total_users,
		SUM(payer) AS payer_users,
		ROUND(AVG(payer),4) AS share_of_paying
FROM fantasy.users

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
		r.race,
		SUM(payer) AS payer_users_of_race,
		COUNT(id) AS total_users_of_race,
		ROUND(SUM(payer) / CAST(COUNT(id)AS numeric), 4) AS share_of_paying_of_race
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
GROUP BY r.race
ORDER BY total_users_of_race DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
		'данные с нулевыми покупоками' AS data_type,
		COUNT(amount) AS count_amount,
		SUM(amount) AS sum_amount,
		MAX(amount) AS max_amount,
		MIN(amount) AS min_amount,
		ROUND(CAST(AVG(amount) AS NUMERIC), 2) AS avg_amount,
		PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY amount) ::numeric(4,2) AS median,
		ROUND(CAST(STDDEV(amount) AS NUMERIC), 2) AS stand_dev
FROM fantasy.events
UNION
SELECT 
		'данные без нулевых покупок' AS data_type,
		COUNT(amount) AS count_amount,
		SUM(amount) AS sum_amount,
		MAX(amount) AS max_amount,
		MIN(amount) AS min_amount,
		ROUND(CAST(AVG(amount) AS NUMERIC), 2) AS avg_amount,
		PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY amount) ::numeric(4,2) AS median,
		ROUND(CAST(STDDEV(amount) AS NUMERIC), 2) AS stand_dev
FROM fantasy.events
WHERE amount > 0;

-- 2.2: Аномальные нулевые покупки:
SELECT 
		COUNT(*) FILTER (WHERE amount = 0) AS count_zero_purchase,
		COUNT(*) AS total_purchase,
		(COUNT(*) FILTER (WHERE amount = 0)::real / COUNT(*))::numeric(5,4) AS share_of_zero_purchase
FROM fantasy.events

--Посчитаем сколько покупок было на сумму больше 100000 и что за предмет был куплен
--SELECT
		--game_items AS name_of_purchase,
		--amount,
		--COUNT(*) OVER() AS cout_big_purchase
--FROM fantasy.events		
--JOIN fantasy.items USING(item_code)
--WHERE amount > 100000

-- 2.3: Популярные эпические предметы:
WITH item_sales AS (
    SELECT 
    	item_code,
        COUNT(*) AS total_count_items,
        COUNT(DISTINCT id) AS count_buyers_item
    FROM fantasy.events
    WHERE amount > 0
    GROUP BY item_code
),
total AS(
	SELECT
		COUNT(transaction_id) AS total_count,
		COUNT(DISTINCT id) AS total_buyers
	FROM fantasy.events 
	WHERE amount > 0
)
SELECT 
		item_code,
		game_items,
		total_count_items,
		(total_count_items / total_count::REAL)::numeric(5,4) AS sales_share,
		(count_buyers_item / total_buyers::REAL)::numeric(5,4) AS users_share
FROM item_sales
CROSS JOIN total
JOIN fantasy.items USING(item_code)
ORDER BY users_share DESC;

-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH count_players_by_race AS (
	SELECT race_id,
			COUNT(id) AS total_players
	FROM fantasy.users
	GROUP BY race_id
),
paying_players_by_race AS (
	SELECT u.race_id,
			COUNT(DISTINCT u.id) AS paying_players_count
	FROM fantasy.users AS u
	JOIN fantasy.events AS e ON u.id = e.id
	WHERE amount > 0
	GROUP BY u.race_id
),
purchase_stats_by_race AS (
	SELECT u.race_id,
			COUNT(*) AS total_purchases,
			SUM(e.amount) AS total_spent
	FROM fantasy.users AS u
	JOIN fantasy.events AS e ON u.id = e.id
	WHERE amount > 0
	GROUP BY u.race_id
),
payers AS (
	SELECT race_id,
			COUNT(DISTINCT u.id) AS real_payer
	FROM fantasy.users AS u
	JOIN fantasy.events AS e ON u.id = e.id
	WHERE amount > 0 AND payer = 1
	GROUP BY race_id
)
SELECT r.race,
		cp.total_players,
		pp.paying_players_count,
		(pp.paying_players_count / CAST(total_players AS float))::numeric(5,4) AS share_players_purchases,
		(p.real_payer / CAST(pp.paying_players_count AS float))::numeric(5,4) AS share_paying_players,
		(ps.total_purchases/ CAST(pp.paying_players_count AS float))::numeric(7,4) AS avg_purchases_per_paying_user,
		(ps.total_spent / CAST(ps.total_purchases AS float))::numeric(6,2) AS avg_cost_purchase,
		(ps.total_spent / CAST(pp.paying_players_count AS float))::numeric(7,2) AS avg_purchase_per_players
FROM count_players_by_race AS cp
LEFT JOIN paying_players_by_race AS pp ON cp.race_id = pp.race_id
LEFT JOIN purchase_stats_by_race AS ps ON cp.race_id = ps.race_id
LEFT JOIN payers AS p ON cp.race_id = p.race_id
JOIN fantasy.race AS r ON cp.race_id = r.race_id
ORDER BY total_players DESC;







