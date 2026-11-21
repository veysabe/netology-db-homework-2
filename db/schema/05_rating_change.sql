-- FOOD-105

SET search_path TO shein_food, exts;

CREATE OR REPLACE FUNCTION rating_change()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_entity_id   uuid;
    v_entity_type review_entity_type;
BEGIN
    -- определяем entity_id и entity_type из NEW или OLD
    IF TG_OP = 'DELETE' THEN
        v_entity_id   := OLD.entity_id;
        v_entity_type := OLD.entity_type;
    ELSE
        v_entity_id   := NEW.entity_id;
        v_entity_type := NEW.entity_type;
    END IF;

    IF v_entity_type = 'блюдо' THEN
        UPDATE product
           SET rating = (SELECT AVG(rating) FROM review WHERE entity_type = 'блюдо' AND entity_id = v_entity_id)
         WHERE product_id = v_entity_id;

    ELSIF v_entity_type = 'ресторан' THEN
        UPDATE restaurant
           SET rating = (SELECT AVG(rating) FROM review WHERE entity_type = 'ресторан' AND entity_id = v_entity_id)
         WHERE restaurant_id = v_entity_id;

    -- entity_type = 'заказ' - ничего не пересчитываем (BR-9.6)
    END IF;

    -- при UPDATE если изменился entity_id или entity_type - пересчитываем и старую сущность
    IF TG_OP = 'UPDATE' THEN
        IF OLD.entity_id != NEW.entity_id OR OLD.entity_type != NEW.entity_type THEN
            IF OLD.entity_type = 'блюдо' THEN
                UPDATE product
                   SET rating = (SELECT AVG(rating) FROM review WHERE entity_type = 'блюдо' AND entity_id = OLD.entity_id)
                 WHERE product_id = OLD.entity_id;
            ELSIF OLD.entity_type = 'ресторан' THEN
                UPDATE restaurant
                   SET rating = (SELECT AVG(rating) FROM review WHERE entity_type = 'ресторан' AND entity_id = OLD.entity_id)
                 WHERE restaurant_id = OLD.entity_id;
            END IF;
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_rating_change
AFTER INSERT OR UPDATE OR DELETE ON review
FOR EACH ROW EXECUTE FUNCTION rating_change();
