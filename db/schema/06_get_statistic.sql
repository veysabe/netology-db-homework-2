-- FOOD-106

SET search_path TO shein_food, exts;

CREATE OR REPLACE FUNCTION get_statistic()
RETURNS TABLE (
    restaurant_name  varchar(200),
    best_product_name varchar(200),
    total_amount     numeric,
    avg_amount       numeric,
    best_user        varchar(100)
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH delivered AS (
        -- все доставленные заказы с суммами
        SELECT o.order_id,
               o.restaurant_id,
               o.total_amount,
               o.client_id
          FROM "order" o
         WHERE o.status = 'доставлен'
    ),
    rest_stats AS (
        -- суммы по ресторанам
        SELECT d.restaurant_id,
               sum(d.total_amount)              AS total_am,
               avg(d.total_amount)              AS avg_am
          FROM delivered d
         GROUP BY d.restaurant_id
    ),
    product_qty AS (
        -- количество каждого блюда в доставленных заказах
        SELECT p.restaurant_id,
               os.product_id,
               sum(os.quantity) AS qty
          FROM order_structure os
          JOIN delivered d  ON d.order_id = os.order_id
          JOIN product p    ON p.product_id = os.product_id
         GROUP BY p.restaurant_id, os.product_id
    ),
    best_product AS (
        -- лучшее блюдо на ресторан - берём первое при совпадении (случайное через random())
        SELECT DISTINCT ON (pq.restaurant_id)
               pq.restaurant_id,
               pr.product_name
          FROM product_qty pq
          JOIN product pr ON pr.product_id = pq.product_id
         ORDER BY pq.restaurant_id, pq.qty DESC, random()
    ),
    client_orders AS (
        -- количество заказов каждого клиента в каждом ресторане
        SELECT d.restaurant_id,
               d.client_id,
               count(*) AS cnt
          FROM delivered d
         GROUP BY d.restaurant_id, d.client_id
    ),
    best_client AS (
        -- лучший клиент на ресторан
        SELECT DISTINCT ON (co.restaurant_id)
               co.restaurant_id,
               cl.login
          FROM client_orders co
          JOIN client cl ON cl.client_id = co.client_id
         ORDER BY co.restaurant_id, co.cnt DESC, random()
    )
    SELECT r.restaurant_name,
           bp.product_name,
           rs.total_am,
           rs.avg_am,
           bc.login
      FROM restaurant r
      LEFT JOIN rest_stats  rs ON rs.restaurant_id  = r.restaurant_id
      LEFT JOIN best_product bp ON bp.restaurant_id = r.restaurant_id
      LEFT JOIN best_client  bc ON bc.restaurant_id = r.restaurant_id;
END;
$$;
