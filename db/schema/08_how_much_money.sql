-- FOOD-108

SET search_path TO shein_food, exts;

CREATE OR REPLACE VIEW how_much_money AS
WITH RECURSIVE
-- границы диапазона - от первого до последнего доставленного заказа
bounds AS (
    SELECT date_trunc('month', min(order_timestamp))::date AS first_month,
           date_trunc('month', max(order_timestamp))::date AS last_month
      FROM "order"
     WHERE status = 'доставлен'
),
-- рекурсивный CTE для генерации всех месяцев (BR-11.9)
months AS (
    SELECT first_month AS m FROM bounds
    UNION ALL
    SELECT (m + interval '1 month')::date
      FROM months, bounds
     WHERE m < last_month
),
-- суммы по доставленным заказам за каждый месяц
order_sums AS (
    SELECT date_trunc('month', order_timestamp)::date AS m,
           sum(order_amount)  AS sum_no_comm,
           sum(total_amount)  AS sum_with_comm
      FROM "order"
     WHERE status = 'доставлен'
     GROUP BY date_trunc('month', order_timestamp)::date
),
-- выплаты курьерам за каждый месяц
pay_sums AS (
    SELECT year, month, sum(amount) AS total_pay
      FROM courier_pay
     GROUP BY year, month
),
-- собираем всё вместе
combined AS (
    SELECT to_char(mo.m, 'YYYY-MM')                            AS year_month,
           coalesce(os.sum_no_comm,  0)                        AS sum_no_commission,
           coalesce(os.sum_with_comm, 0)                       AS sum_with_commission,
           coalesce(os.sum_with_comm, 0) - coalesce(os.sum_no_comm, 0) AS commission,
           coalesce(ps.total_pay, 0)                           AS courier_pay
      FROM months mo
      LEFT JOIN order_sums os ON os.m = mo.m
      LEFT JOIN pay_sums   ps ON ps.year  = extract(year  from mo.m)::int
                              AND ps.month = extract(month from mo.m)::int
)
SELECT year_month,
       sum_no_commission,
       sum_with_commission,
       commission,
       lag(commission) OVER (ORDER BY year_month)              AS prev_commission,
       commission - lag(commission) OVER (ORDER BY year_month) AS commission_diff,
       courier_pay,
       commission - courier_pay                                 AS net_profit
  FROM combined
 ORDER BY year_month;
