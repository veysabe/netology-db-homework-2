-- FOOD-107

SET search_path TO shein_food, exts;

CREATE OR REPLACE PROCEDURE courier_salary()
LANGUAGE plpgsql AS $$
DECLARE
    v_courier_id     uuid;
    v_coeff          numeric(3,2);
    v_coeff_new      numeric(3,2);
    v_delivery_count int;
    v_commission_sum numeric(12,2);
    v_year           int;
    v_month          int;
BEGIN
    v_year  := extract(year  from current_date)::int;
    v_month := extract(month from current_date)::int;

    FOR v_courier_id IN SELECT courier_id FROM courier LOOP

        SELECT coefficient INTO v_coeff FROM courier WHERE courier_id = v_courier_id;

        SELECT count(*), coalesce(sum(commission), 0)
          INTO v_delivery_count, v_commission_sum
          FROM "order"
         WHERE courier_id    = v_courier_id
           AND status        = 'доставлен'
           AND extract(year  from order_timestamp)::int = v_year
           AND extract(month from order_timestamp)::int = v_month;

        -- вставляем или обновляем запись за текущий месяц (BR-10.3)
        INSERT INTO courier_pay (year, month, courier_id, amount, coefficient_used)
        VALUES (v_year, v_month, v_courier_id, round(v_coeff * v_commission_sum, 2), v_coeff)
        ON CONFLICT (year, month, courier_id) DO UPDATE
            SET amount           = EXCLUDED.amount,
                coefficient_used = EXCLUDED.coefficient_used;

        -- новый коэффициент по BR-10.2
        IF v_delivery_count <= 150 THEN
            v_coeff_new := 0.1;
        ELSIF v_delivery_count <= 250 THEN
            v_coeff_new := 0.2;
        ELSIF v_delivery_count <= 500 THEN
            v_coeff_new := 0.3;
        ELSE
            v_coeff_new := 0.5;
        END IF;

        -- уволенным коэффициент не обновляем (BR-10.6)
        UPDATE courier
           SET coefficient = v_coeff_new
         WHERE courier_id = v_courier_id
           AND status != 'уволен';

    END LOOP;
END;
$$;
