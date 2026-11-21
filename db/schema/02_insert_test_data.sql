-- FOOD-102

SET search_path TO shein_food, exts;

CREATE OR REPLACE PROCEDURE insert_test_data(value int)
LANGUAGE plpgsql AS $$
DECLARE
    v_address_ids    uuid[];
    v_client_ids     uuid[];
    v_courier_ids    uuid[];
    v_restaurant_ids uuid[];
    v_product_ids    uuid[];
    v_category_ids   uuid[];
    v_order_ids      uuid[];

    v_id             uuid;
    v_client_id      uuid;
    v_courier_id     uuid;
    v_restaurant_id  uuid;
    v_address_id     uuid;
    v_product_id     uuid;
    v_order_id       uuid;
    v_order_amount   numeric(12,2);
    v_total_amount   numeric(12,2);

    v_hire_date      date;
    v_dismissal_date date;
    v_work_start     time;
    v_work_end       time;
    v_order_ts       timestamp;
    v_delivery_ts    timestamp;

    v_coeff          numeric(3,2);
    v_coeff_new      numeric(3,2);
    v_delivery_count int;
    v_commission_sum numeric(12,2);
    v_month_offset   int;
    v_month_start    date;
    v_month_end      date;

    v_num_items      int;
    v_num_payments   int;
    v_rest_products  uuid[];
    v_used_products  uuid[];
    v_used_addresses uuid[];
    v_client_addrs   uuid[];
    v_addr_count     int;
    v_addr_idx       int;
    v_addr_attempts  int;
    v_pidx           int;
    v_pidx_attempts  int;

    v_etype          review_entity_type;
    v_eid            uuid;

    i int;
    j int;
BEGIN

    -- 1. product_category (value * 1)
    FOR i IN 1..value LOOP
        v_id := exts.uuid_generate_v4();
        INSERT INTO product_category (product_category_id, product_category_name)
        VALUES (
            v_id,
            substring(md5(random()::text || i::text), 1, floor(random() * 30 + 1)::int)
        );
        v_category_ids := array_append(v_category_ids, v_id);
    END LOOP;

    -- 2. courier (value * 1)
    FOR i IN 1..value LOOP
        v_id       := exts.uuid_generate_v4();
        v_hire_date := current_date - floor(random() * 180 + 1)::int;

        -- последний курьер всегда активен (BR-6.6)
        IF i = value THEN
            INSERT INTO courier (courier_id, fio, phone_number, status, hire_date, dismissal_date, coefficient)
            VALUES (v_id,
                    substring(md5(random()::text), 1, floor(random() * 20 + 1)::int),
                    lpad(floor(random() * 90000000000 + 10000000000)::bigint::text, 11, '0'),
                    'свободен', v_hire_date, NULL, 0.1);

        ELSIF random() < 0.2 THEN
            -- уволен: дата увольнения >= даты найма (BR-6.3)
            v_dismissal_date := v_hire_date + floor(random() * 90 + 1)::int;
            IF v_dismissal_date > current_date THEN
                v_dismissal_date := current_date;
            END IF;
            INSERT INTO courier (courier_id, fio, phone_number, status, hire_date, dismissal_date, coefficient)
            VALUES (v_id,
                    substring(md5(random()::text), 1, floor(random() * 20 + 1)::int),
                    lpad(floor(random() * 90000000000 + 10000000000)::bigint::text, 11, '0'),
                    'уволен', v_hire_date, v_dismissal_date, 0.1);

        ELSE
            -- свободен / занят / на_доставке - индексы 1,2,3 из enum (BR-6.2)
            INSERT INTO courier (courier_id, fio, phone_number, status, hire_date, dismissal_date, coefficient)
            VALUES (v_id,
                    substring(md5(random()::text), 1, floor(random() * 20 + 1)::int),
                    lpad(floor(random() * 90000000000 + 10000000000)::bigint::text, 11, '0'),
                    (enum_range(NULL::courier_status))[floor(random() * 3 + 1)::int],
                    v_hire_date, NULL, 0.1);
        END IF;

        v_courier_ids := array_append(v_courier_ids, v_id);
    END LOOP;

    -- 3. address (value * 5)
    --    первые value - под рестораны, остальные value*4 - под клиентов (BR-11.7)
    FOR i IN 1..(value * 5) LOOP
        v_id := exts.uuid_generate_v4();
        INSERT INTO address (address_id, street, house_number, apartment_office)
        VALUES (
            v_id,
            substring(md5(random()::text), 1, floor(random() * 50 + 1)::int),
            floor(random() * 200 + 1)::int::text,
            CASE WHEN random() < 0.3 THEN NULL
                 ELSE floor(random() * 200 + 1)::int::text END
        );
        v_address_ids := array_append(v_address_ids, v_id);
    END LOOP;

    -- 4. restaurant (value * 1) - первые value адресов под рестораны
    FOR i IN 1..value LOOP
        v_id := exts.uuid_generate_v4();
        -- work_start 06:00..12:00, интервал +4..8 ч => max 20:00 (не выходим за 24:00)
        v_work_start := (floor(random() * 7 + 6)::int || ':00')::time;
        v_work_end   := v_work_start + (floor(random() * 5 + 4)::int || ' hours')::interval;

        INSERT INTO restaurant (restaurant_id, restaurant_name, address_id, description,
                                work_start, work_end, company_details, rating, status)
        VALUES (
            v_id,
            substring(md5(random()::text), 1, floor(random() * 50 + 1)::int),
            v_address_ids[i],
            substring(md5(random()::text), 1, floor(random() * 100 + 1)::int),
            v_work_start, v_work_end,
            substring(md5(random()::text), 1, floor(random() * 100 + 1)::int),
            NULL,
            (enum_range(NULL::restaurant_status))[floor(random() * 2 + 1)::int]
        );
        v_restaurant_ids := array_append(v_restaurant_ids, v_id);
    END LOOP;

    -- 5. client (value * 1)
    FOR i IN 1..value LOOP
        v_id := exts.uuid_generate_v4();
        INSERT INTO client (client_id, login, password, phone_number)
        VALUES (
            v_id,
            -- глобальный счётчик гарантирует уникальность при повторных вызовах (BR-2.2)
            substring(md5(random()::text), 1, 8) || '_' || nextval('shein_food.client_login_seq')::text,
            md5(random()::text),
            lpad((nextval('shein_food.client_phone_seq') % 100000000000)::text, 11, '7')
        );
        v_client_ids := array_append(v_client_ids, v_id);
    END LOOP;

    -- 6. client_address: каждый клиент получает 1..3 адреса из клиентских (BR-2.4, BR-2.5)
    FOR i IN 1..value LOOP
        v_client_id      := v_client_ids[i];
        v_used_addresses := ARRAY[]::uuid[];
        v_num_items      := floor(random() * 3 + 1)::int;

        FOR j IN 1..v_num_items LOOP
            v_addr_attempts := 0;
            LOOP
                v_addr_idx   := value + floor(random() * (value * 4) + 1)::int;
                IF v_addr_idx > value * 5 THEN
                    v_addr_idx := value * 5;
                END IF;
                v_address_id := v_address_ids[v_addr_idx];
                EXIT WHEN NOT (v_address_id = ANY(v_used_addresses)) OR v_addr_attempts > 10;
                v_addr_attempts := v_addr_attempts + 1;
            END LOOP;

            IF NOT (v_address_id = ANY(v_used_addresses)) THEN
                INSERT INTO client_address (client_id, address_id)
                VALUES (v_client_id, v_address_id)
                ON CONFLICT DO NOTHING;
                v_used_addresses := array_append(v_used_addresses, v_address_id);
            END IF;
        END LOOP;
    END LOOP;

    -- 7. product (value * 5)
    FOR i IN 1..(value * 5) LOOP
        v_id := exts.uuid_generate_v4();
        INSERT INTO product (product_id, product_name, product_category_id, price,
                             restaurant_id, photo_url, rating, status, description)
        VALUES (
            v_id,
            substring(md5(random()::text), 1, floor(random() * 50 + 1)::int),
            v_category_ids[floor(random() * value + 1)::int],
            round((random() * 2000 + 100)::numeric, 2),
            v_restaurant_ids[floor(random() * value + 1)::int],
            CASE WHEN random() < 0.3 THEN NULL
                 ELSE 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg' END,
            NULL,
            (enum_range(NULL::product_status))[floor(random() * 3 + 1)::int],
            substring(md5(random()::text), 1, floor(random() * 100 + 1)::int)
        );
        v_product_ids := array_append(v_product_ids, v_id);
    END LOOP;

    -- 8. order (value * 5)
    FOR i IN 1..(value * 5) LOOP
        v_id            := exts.uuid_generate_v4();
        v_client_id     := v_client_ids[floor(random() * value + 1)::int];
        v_courier_id    := v_courier_ids[floor(random() * value + 1)::int];
        v_restaurant_id := v_restaurant_ids[floor(random() * value + 1)::int];

        -- адрес доставки - один из адресов этого клиента (BR-7.4)
        SELECT array_agg(ca.address_id) INTO v_client_addrs
        FROM client_address ca
        WHERE ca.client_id = v_client_id;

        IF v_client_addrs IS NULL OR array_length(v_client_addrs, 1) = 0 THEN
            -- edge case: добавляем адрес клиенту если вдруг не добавился
            v_address_id := v_address_ids[LEAST(value + floor(random() * (value * 4) + 1)::int, value * 5)];
            INSERT INTO client_address (client_id, address_id)
            VALUES (v_client_id, v_address_id)
            ON CONFLICT DO NOTHING;
        ELSE
            v_addr_count := array_length(v_client_addrs, 1);
            v_address_id := v_client_addrs[floor(random() * v_addr_count + 1)::int];
        END IF;

        v_order_amount := round((random() * 4000 + 1000)::numeric, 2);
        v_order_ts     := localtimestamp - (random() * 180)::int * interval '1 day';

        IF random() < 0.4 THEN
            v_delivery_ts := v_order_ts + floor(random() * 120 + 10)::int * interval '1 minute';
            INSERT INTO "order" (order_id, courier_id, client_id, address_id, restaurant_id,
                                 order_timestamp, delivery_timestamp, order_amount, status, pay_status)
            VALUES (v_id, v_courier_id, v_client_id, v_address_id, v_restaurant_id,
                    v_order_ts, v_delivery_ts, v_order_amount, 'доставлен', 'оплачен');
        ELSE
            INSERT INTO "order" (order_id, courier_id, client_id, address_id, restaurant_id,
                                 order_timestamp, delivery_timestamp, order_amount, status, pay_status)
            VALUES (
                v_id, v_courier_id, v_client_id, v_address_id, v_restaurant_id,
                v_order_ts, NULL, v_order_amount,
                -- явный массив без 'доставлен' чтобы не попасть с NULL delivery_timestamp (BR-7.12)
                (ARRAY['создан','готовится','в_доставке','отменён']::order_status[])[floor(random() * 4 + 1)::int],
                (enum_range(NULL::order_pay_status))[floor(random() * 3 + 1)::int]
            );
        END IF;

        v_order_ids := array_append(v_order_ids, v_id);
    END LOOP;

    -- 9. order_structure: 1..5 блюд из ресторана заказа (BR-7.3, BR-7.16)
    FOR i IN 1..(value * 5) LOOP
        v_order_id      := v_order_ids[i];
        v_used_products := ARRAY[]::uuid[];

        SELECT restaurant_id INTO v_restaurant_id FROM "order" WHERE order_id = v_order_id;

        SELECT array_agg(product_id) INTO v_rest_products
        FROM product
        WHERE restaurant_id = v_restaurant_id;

        IF v_rest_products IS NULL OR array_length(v_rest_products, 1) = 0 THEN
            CONTINUE;
        END IF;

        v_num_items := LEAST(floor(random() * 5 + 1)::int, array_length(v_rest_products, 1));

        FOR j IN 1..v_num_items LOOP
            v_pidx_attempts := 0;
            LOOP
                v_pidx       := floor(random() * array_length(v_rest_products, 1) + 1)::int;
                v_product_id := v_rest_products[v_pidx];
                EXIT WHEN NOT (v_product_id = ANY(v_used_products)) OR v_pidx_attempts > 20;
                v_pidx_attempts := v_pidx_attempts + 1;
            END LOOP;

            IF NOT (v_product_id = ANY(v_used_products)) THEN
                INSERT INTO order_structure (order_id, product_id, quantity)
                VALUES (v_order_id, v_product_id, round((random() * 4 + 1)::numeric, 3));
                v_used_products := array_append(v_used_products, v_product_id);
            END IF;
        END LOOP;
    END LOOP;

    -- 10. payment: 1..3 попытки, первая всегда успешная (BR-8.1, BR-8.4)
    FOR i IN 1..(value * 5) LOOP
        v_order_id := v_order_ids[i];

        -- при повторном вызове не добавляем платежи если уже есть (BR-8.1)
        CONTINUE WHEN EXISTS (SELECT 1 FROM payment WHERE order_id = v_order_id);

        SELECT total_amount INTO v_total_amount FROM "order" WHERE order_id = v_order_id;
        v_num_payments := floor(random() * 3 + 1)::int;

        FOR j IN 1..v_num_payments LOOP
            INSERT INTO payment (payment_id, order_id, payment_type, amount, transaction_id, paid_at, status)
            VALUES (
                exts.uuid_generate_v4(),
                v_order_id,
                (enum_range(NULL::payment_type))[floor(random() * 3 + 1)::int],
                v_total_amount,
                md5(random()::text || v_order_id::text || j::text),
                localtimestamp - (random() * 180)::int * interval '1 day',
                CASE WHEN j = 1 THEN 'успех' ELSE 'ошибка' END::payment_status
            );
        END LOOP;
    END LOOP;

    -- 11. review (value * 5)
    FOR i IN 1..(value * 5) LOOP
        v_order_id  := v_order_ids[floor(random() * (value * 5) + 1)::int];
        v_client_id := (SELECT client_id FROM "order" WHERE order_id = v_order_id);

        v_eid   := NULL;
        v_etype := (enum_range(NULL::review_entity_type))[floor(random() * 3 + 1)::int];

        IF v_etype = 'блюдо' THEN
            SELECT os.product_id INTO v_eid
            FROM order_structure os
            WHERE os.order_id = v_order_id
            ORDER BY random() LIMIT 1;
        ELSIF v_etype = 'ресторан' THEN
            SELECT restaurant_id INTO v_eid FROM "order" WHERE order_id = v_order_id;
        ELSE
            v_eid := v_order_id;
        END IF;

        IF v_eid IS NOT NULL THEN
            INSERT INTO review (review_id, client_id, review_timestamp, entity_id, entity_type,
                                order_id, description, photo_url, rating)
            VALUES (
                exts.uuid_generate_v4(),
                v_client_id,
                localtimestamp - (random() * 180)::int * interval '1 day',
                v_eid,
                v_etype,
                v_order_id,
                substring(md5(random()::text), 1, floor(random() * 100 + 1)::int),
                CASE WHEN random() < 0.3 THEN NULL
                     ELSE 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg' END,
                floor(random() * 5 + 1)::int
            )
            ON CONFLICT ON CONSTRAINT uq_review_per_entity DO NOTHING;
        END IF;
    END LOOP;

    -- 12. courier_pay: последние 6 месяцев по BR-10.2
    --     цикл по месяцам: 0 = 5 месяцев назад, 5 = текущий
    FOR j IN 1..value LOOP
        v_courier_id := v_courier_ids[j];
        -- начальный коэффициент берём один раз до цикла по месяцам
        SELECT coefficient INTO v_coeff FROM courier WHERE courier_id = v_courier_id;

        FOR v_month_offset IN 0..5 LOOP
            v_month_start := date_trunc('month', current_date - (5 - v_month_offset) * interval '1 month')::date;
            v_month_end   := (v_month_start + interval '1 month' - interval '1 day')::date;

            SELECT count(*), coalesce(sum(commission), 0)
              INTO v_delivery_count, v_commission_sum
              FROM "order"
             WHERE courier_id = v_courier_id
               AND status = 'доставлен'
               AND order_timestamp::date BETWEEN v_month_start AND v_month_end;

            -- coefficient_used = коэффициент действовавший в этом месяце (BR-10.2)
            INSERT INTO courier_pay (year, month, courier_id, amount, coefficient_used)
            VALUES (
                extract(year  from v_month_start)::int,
                extract(month from v_month_start)::int,
                v_courier_id,
                round(v_coeff * v_commission_sum, 2),
                v_coeff
            )
            ON CONFLICT (year, month, courier_id) DO UPDATE
                SET amount           = EXCLUDED.amount,
                    coefficient_used = EXCLUDED.coefficient_used;

            -- считаем новый коэффициент на следующий месяц по BR-10.2
            IF v_delivery_count <= 150 THEN
                v_coeff_new := 0.1;
            ELSIF v_delivery_count <= 250 THEN
                v_coeff_new := 0.2;
            ELSIF v_delivery_count <= 500 THEN
                v_coeff_new := 0.3;
            ELSE
                v_coeff_new := 0.5;
            END IF;

            -- коэффициент следующего месяца становится текущим на следующей итерации
            v_coeff := v_coeff_new;
        END LOOP;

        -- после всех месяцев - обновляем коэффициент только не уволенным (BR-10.6)
        UPDATE courier
           SET coefficient = v_coeff_new
         WHERE courier_id = v_courier_id
           AND status != 'уволен';
    END LOOP;

END;
$$;
