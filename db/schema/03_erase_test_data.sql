-- FOOD-103

SET search_path TO shein_food, exts;

CREATE OR REPLACE PROCEDURE erase_test_data()
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM review;
    DELETE FROM payment;
    DELETE FROM order_structure;
    DELETE FROM "order";
    DELETE FROM courier_pay;
    DELETE FROM client_address;
    DELETE FROM product;
    DELETE FROM restaurant;
    DELETE FROM client;
    DELETE FROM courier;
    DELETE FROM address;
    DELETE FROM product_category;
END;
$$;