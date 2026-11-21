-- FOOD-104

SET search_path TO shein_food, exts;

CREATE OR REPLACE PROCEDURE add_product(
    p_restaurant_id       uuid,
    p_product_category_id uuid,
    p_name                varchar(200),
    p_price               numeric(10,2),
    p_status              product_status,
    p_description         text,
    p_photo_url           text DEFAULT NULL,
    p_rating              numeric(3,2) DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM restaurant WHERE restaurant_id = p_restaurant_id) THEN
        RAISE EXCEPTION 'ресторан % не найден', p_restaurant_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM product_category WHERE product_category_id = p_product_category_id) THEN
        RAISE EXCEPTION 'категория % не найдена', p_product_category_id;
    END IF;

    INSERT INTO product (product_id, product_name, product_category_id, price,
                         restaurant_id, photo_url, rating, status, description)
    VALUES (
        exts.uuid_generate_v4(),
        p_name,
        p_product_category_id,
        p_price,
        p_restaurant_id,
        p_photo_url,
        p_rating,
        p_status,
        p_description
    );
END;
$$;
