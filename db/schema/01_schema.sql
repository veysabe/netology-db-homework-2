-- FOOD-101

CREATE SCHEMA IF NOT EXISTS shein_food;

SET search_path TO shein_food, exts;

-- enums

CREATE TYPE restaurant_status  AS ENUM ('активен', 'неактивен');
CREATE TYPE product_status     AS ENUM ('доступно', 'нет_в_наличии', 'архив');
CREATE TYPE courier_status     AS ENUM ('свободен', 'занят', 'на_доставке', 'уволен');
CREATE TYPE order_status       AS ENUM ('создан', 'готовится', 'в_доставке', 'доставлен', 'отменён');
CREATE TYPE order_pay_status   AS ENUM ('ожидает', 'оплачен', 'ошибка');
CREATE TYPE payment_status     AS ENUM ('успех', 'ошибка', 'в_обработке');
CREATE TYPE payment_type       AS ENUM ('карта', 'наличные', 'безнал');
CREATE TYPE review_entity_type AS ENUM ('блюдо', 'ресторан', 'заказ');

-- sequences

-- используется в insert_test_data для уникальных телефонов клиентов
CREATE SEQUENCE IF NOT EXISTS client_phone_seq START 10000000000 INCREMENT 1;
CREATE SEQUENCE IF NOT EXISTS client_login_seq START 1 INCREMENT 1;

-- tables

CREATE TABLE address (
    address_id       uuid         NOT NULL DEFAULT exts.uuid_generate_v4(),
    street           varchar(200) NOT NULL,
    house_number     varchar(20)  NOT NULL,
    apartment_office varchar(20)  NULL,
    CONSTRAINT pk_address PRIMARY KEY (address_id)
);

CREATE TABLE product_category (
    product_category_id   uuid         NOT NULL DEFAULT exts.uuid_generate_v4(),
    product_category_name varchar(100) NOT NULL,
    CONSTRAINT pk_product_category PRIMARY KEY (product_category_id)
);

CREATE TABLE restaurant (
    restaurant_id   uuid              NOT NULL DEFAULT exts.uuid_generate_v4(),
    restaurant_name varchar(200)      NOT NULL,
    address_id      uuid              NOT NULL,
    description     text              NOT NULL,
    work_start      time              NOT NULL,
    work_end        time              NOT NULL,
    company_details text              NOT NULL,
    rating          numeric(3,2)      NULL,
    status          restaurant_status NOT NULL,
    CONSTRAINT pk_restaurant         PRIMARY KEY (restaurant_id),
    CONSTRAINT fk_restaurant_address FOREIGN KEY (address_id) REFERENCES address(address_id),
    CONSTRAINT uq_restaurant_address UNIQUE (address_id),
    CONSTRAINT chk_restaurant_rating CHECK (rating BETWEEN 0 AND 5),
    CONSTRAINT chk_restaurant_hours  CHECK (work_end > work_start)
);

CREATE TABLE courier (
    courier_id     uuid           NOT NULL DEFAULT exts.uuid_generate_v4(),
    fio            varchar(300)   NOT NULL,
    phone_number   char(11)       NOT NULL,
    status         courier_status NOT NULL,
    hire_date      date           NOT NULL,
    dismissal_date date           NULL,
    coefficient    numeric(3,2)   NOT NULL DEFAULT 0.1,
    CONSTRAINT pk_courier              PRIMARY KEY (courier_id),
    CONSTRAINT chk_courier_coefficient CHECK (coefficient BETWEEN 0.1 AND 0.5),
    CONSTRAINT chk_courier_dismissal   CHECK (
        (status = 'уволен' AND dismissal_date IS NOT NULL)
        OR (status != 'уволен' AND dismissal_date IS NULL)
    ),
    CONSTRAINT chk_courier_dates CHECK (dismissal_date IS NULL OR dismissal_date >= hire_date)
);

CREATE TABLE client (
    client_id    uuid         NOT NULL DEFAULT exts.uuid_generate_v4(),
    login        varchar(100) NOT NULL,
    password     char(32)     NOT NULL,
    phone_number char(11)     NOT NULL,
    CONSTRAINT pk_client       PRIMARY KEY (client_id),
    CONSTRAINT uq_client_login UNIQUE (login),
    CONSTRAINT uq_client_phone UNIQUE (phone_number)
);

CREATE TABLE client_address (
    client_id  uuid NOT NULL,
    address_id uuid NOT NULL,
    CONSTRAINT pk_client_address PRIMARY KEY (client_id, address_id),
    CONSTRAINT fk_ca_client      FOREIGN KEY (client_id)  REFERENCES client(client_id),
    CONSTRAINT fk_ca_address     FOREIGN KEY (address_id) REFERENCES address(address_id)
);

CREATE TABLE product (
    product_id          uuid           NOT NULL DEFAULT exts.uuid_generate_v4(),
    product_name        varchar(200)   NOT NULL,
    product_category_id uuid           NOT NULL,
    price               numeric(10,2)  NOT NULL,
    restaurant_id       uuid           NOT NULL,
    photo_url           text           NULL,
    rating              numeric(3,2)   NULL,
    status              product_status NOT NULL,
    description         text           NOT NULL,
    CONSTRAINT pk_product            PRIMARY KEY (product_id),
    CONSTRAINT fk_product_category   FOREIGN KEY (product_category_id) REFERENCES product_category(product_category_id),
    CONSTRAINT fk_product_restaurant FOREIGN KEY (restaurant_id)       REFERENCES restaurant(restaurant_id),
    CONSTRAINT chk_product_price     CHECK (price >= 0),
    CONSTRAINT chk_product_rating    CHECK (rating BETWEEN 0 AND 5)
);

-- "order" - зарезервированное слово, берём в кавычки (BR-13.1)
CREATE TABLE "order" (
    order_id           uuid             NOT NULL DEFAULT exts.uuid_generate_v4(),
    courier_id         uuid             NOT NULL,
    client_id          uuid             NOT NULL,
    address_id         uuid             NOT NULL,
    restaurant_id      uuid             NOT NULL,
    order_timestamp    timestamp        NOT NULL,
    delivery_timestamp timestamp        NULL,
    order_amount       numeric(12,2)    NOT NULL,
    commission         numeric(12,2)    NOT NULL GENERATED ALWAYS AS (round(order_amount * 0.10, 2)) STORED,
    total_amount       numeric(12,2)    NOT NULL GENERATED ALWAYS AS (round(order_amount * 1.10, 2)) STORED,
    status             order_status     NOT NULL,
    pay_status         order_pay_status NOT NULL,
    description        text             NULL,
    CONSTRAINT pk_order                PRIMARY KEY (order_id),
    CONSTRAINT fk_order_courier        FOREIGN KEY (courier_id)    REFERENCES courier(courier_id),
    CONSTRAINT fk_order_client         FOREIGN KEY (client_id)     REFERENCES client(client_id),
    CONSTRAINT fk_order_address        FOREIGN KEY (address_id)    REFERENCES address(address_id),
    CONSTRAINT fk_order_restaurant     FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT chk_order_min_amount    CHECK (order_amount >= 1000),
    CONSTRAINT chk_order_delivery_time CHECK (delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp)
);

CREATE TABLE courier_pay (
    year             int           NOT NULL,
    month            int           NOT NULL,
    courier_id       uuid          NOT NULL,
    amount           numeric(12,2) NOT NULL,
    coefficient_used numeric(3,2)  NOT NULL,
    CONSTRAINT pk_courier_pay         PRIMARY KEY (year, month, courier_id),
    CONSTRAINT fk_courier_pay_courier FOREIGN KEY (courier_id) REFERENCES courier(courier_id),
    CONSTRAINT chk_courier_pay_amount CHECK (amount >= 0),
    CONSTRAINT chk_courier_pay_month  CHECK (month BETWEEN 1 AND 12),
    CONSTRAINT chk_courier_pay_year   CHECK (year >= 2000),
    CONSTRAINT chk_courier_pay_coeff  CHECK (coefficient_used BETWEEN 0.1 AND 0.5)
);

CREATE TABLE payment (
    payment_id     uuid           NOT NULL DEFAULT exts.uuid_generate_v4(),
    order_id       uuid           NOT NULL,
    payment_type   payment_type   NOT NULL,
    amount         numeric(12,2)  NOT NULL,
    transaction_id varchar(200)   NOT NULL,
    paid_at        timestamp      NOT NULL,
    status         payment_status NOT NULL,
    CONSTRAINT pk_payment       PRIMARY KEY (payment_id),
    CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES "order"(order_id),
    CONSTRAINT uq_payment_txn   UNIQUE (transaction_id)
);

CREATE TABLE order_structure (
    order_id   uuid          NOT NULL,
    product_id uuid          NOT NULL,
    quantity   numeric(10,3) NOT NULL,
    CONSTRAINT pk_order_structure PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_os_order        FOREIGN KEY (order_id)   REFERENCES "order"(order_id),
    CONSTRAINT fk_os_product      FOREIGN KEY (product_id) REFERENCES product(product_id),
    CONSTRAINT chk_os_quantity    CHECK (quantity > 0)
);

-- entity_id полиморфный - FK не ставим, см. constraints.md
CREATE TABLE review (
    review_id        uuid               NOT NULL DEFAULT exts.uuid_generate_v4(),
    client_id        uuid               NOT NULL,
    review_timestamp timestamp          NOT NULL,
    entity_id        uuid               NOT NULL,
    entity_type      review_entity_type NOT NULL,
    order_id         uuid               NOT NULL,
    description      text               NOT NULL,
    photo_url        text               NULL,
    rating           int                NOT NULL,
    CONSTRAINT pk_review            PRIMARY KEY (review_id),
    CONSTRAINT fk_review_client     FOREIGN KEY (client_id) REFERENCES client(client_id),
    CONSTRAINT fk_review_order      FOREIGN KEY (order_id)  REFERENCES "order"(order_id),
    CONSTRAINT chk_review_rating    CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT uq_review_per_entity UNIQUE (order_id, entity_id, entity_type)
);
