-- FOOD-109

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'inspector') THEN
        CREATE ROLE inspector WITH LOGIN PASSWORD 'NetoSQL2025';
    END IF;
END;
$$;

GRANT USAGE  ON SCHEMA shein_food TO inspector;
GRANT CREATE ON SCHEMA shein_food TO inspector;

GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA shein_food TO inspector;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA shein_food TO inspector;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA shein_food TO inspector;
GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA shein_food TO inspector;

GRANT SELECT ON how_much_money TO inspector;

GRANT USAGE ON SCHEMA exts TO inspector;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA exts TO inspector;

-- по умолчанию PUBLIC имеет доступ, явно выдаём на случай если отозвано
GRANT USAGE ON SCHEMA information_schema TO inspector;
GRANT USAGE ON SCHEMA pg_catalog        TO inspector;
