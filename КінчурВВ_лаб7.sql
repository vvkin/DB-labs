--1. Вивести на екран перший рядок з усіх таблиць без прив’язки до конкретної бази даних.
DO $$ DECLARE t_name text; t_row record;
BEGIN
    FOR t_name IN (
        SELECT quote_ident(table_name)
	FROM   information_schema.tables
	WHERE  table_schema = 'public'
    )
    LOOP
	EXECUTE format('SELECT * FROM %s LIMIT 1', t_name) INTO t_row;
	RAISE NOTICE 'TABLE: %, ROW: %', t_name, t_row;
    END LOOP;
END $$;

--2. Видати дозвіл на читання бази даних Northwind усім користувачам вашої СУБД. Користувачі,
--що будуть створені після виконання запиту, доступ на читання отримати не повинні.
DO $$ DECLARE user_name text;
BEGIN
    FOR user_name IN (
        SELECT quote_ident(usename)
	FROM pg_catalog.pg_user
    )
    LOOP
	EXECUTE format('GRANT CONNECT ON DATABASE northwind TO %s', user_name); -- is not required by default
	EXECUTE format('GRANT USAGE ON SCHEMA public TO %s', user_name); -- is not required by default
	EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA public TO %s', user_name);
    END LOOP;
END $$

--3. За допомогою курсору заборонити користувачеві TestUser доступ до всіх таблиць поточної
--бази даних, імена котрих починаються на префікс ‘prod_’.
DO $$ DECLARE 
    t_names cursor
        FOR SELECT table_name
	FROM information_schema.tables
	WHERE table_schema = 'public'
	    AND table_name NOT LIKE 'prod[_]%';
BEGIN
    FOR t_name IN t_names LOOP
	EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE %s FROM TestUser', quote_ident(t_name.table_name));
    END LOOP;
END $$;

--4. В контексті бази Northwind створити збережену процедуру (або функцію), що приймає в якості
--параметра номер замовлення та виводить імена продуктів, їх кількість, та загальну суму по
--кожній позиції в залежності від вартості, кількості та наявності знижки. Запустити виконання
--збереженої процедури для всіх наявних замовлень.
CREATE OR REPLACE FUNCTION get_products_by_order_id(order_id int)
RETURNS TABLE (name varchar(40), quantity smallint, total_price double precision)
AS $$
BEGIN
    RETURN QUERY 
    SELECT "ProductName",
	   "Quantity",
           od."UnitPrice" * "Quantity" * (1 - "Discount") AS total_price
    FROM order_details od JOIN products USING ("ProductID")
    WHERE "OrderID" = order_id;
END
$$ LANGUAGE plpgsql;

SELECT get_products_by_order_id("OrderID")
FROM orders;

--5. Видаліть дані з усіх таблиць в усіх базах даних наявної СУБД. Код повинен бути незалежним
--від наявних імен об’єктів.
DO $$ DECLARE t_name text;
BEGIN
    FOR t_name IN (
        SELECT quote_ident(table_name)
	FROM   information_schema.tables
	WHERE  table_schema = 'public'
    )
    LOOP
	EXECUTE format('DELETE FROM %s ', t_name); --- OR ...('TRUNCATE %s', t_name)
    END LOOP;
END $$;

--6. Створити тригер на таблиці Customers, що при вставці нового телефонного номеру буде
--видаляти усі символи крім цифр.
CREATE OR REPLACE FUNCTION validate_phone()
RETURNS trigger AS $$
BEGIN
    NEW."Phone" := regexp_replace(NEW."Phone", '\D', '', 'g');
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_validate_phone 
    BEFORE INSERT OR UPDATE ON
    customers FOR EACH ROW EXECUTE PROCEDURE validate_phone();

--7. В контексті бази Northwind створити тригер який при вставці даних в таблицю Order Details
--нових записів буде перевіряти загальну вартість замовлення. Якщо загальна вартість
--перевищує 100 грошових одиниць – надати знижку в 3%, якщо перевищує 500 – 5%, більш ніж
--1000 – 8%.
CREATE OR REPLACE FUNCTION calculate_discount()
RETURNS trigger AS $$
DECLARE 
    total_price double precision;
    discount double precision := 0;
BEGIN
    SELECT sum("UnitPrice" * "Quantity" * (1 - "Discount"))
    INTO total_price
    FROM order_details
    WHERE "OrderID" = NEW."OrderID";
	
    IF total_price > 1000   THEN discount := 0.08;
    ELSIF total_price > 500 THEN discount := 0.05;
    ELSIF total_price > 100 THEN discount := 0.03; 
    END IF;
	
    UPDATE order_details
    SET "Discount" = discount
    WHERE "OrderID" = NEW."OrderID";

    NEW."Dicount" = discount;
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_set_discount BEFORE INSERT ON
    order_details FOR EACH ROW EXECUTE PROCEDURE calculate_discount();

--8. Створити таблицю Contacts (ContactId, LastName, FirstName, PersonalPhone, WorkPhone, Email,
--PreferableNumber). Створити тригер, що при вставці даних в таблицю Contacts вставить в
--якості PreferableNumber WorkPhone якщо він присутній, або PersonalPhone, якщо робочий
--номер телефона не вказано.
CREATE TABLE contacts (
    contact_id int,
    last_name varchar(255),
    first_name varchar(255),
    personal_phone varchar(24),
    work_phone varchar(24),
    preferable_number varchar(24),
    email varchar(255)
);

CREATE OR REPLACE FUNCTION set_phone()
RETURNS trigger AS $$
BEGIN
    NEW.preferable_number := COALESCE(NEW.work_phone, NEW.personal_phone);
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_set_phone BEFORE INSERT ON
    contacts FOR EACH ROW EXECUTE PROCEDURE set_phone();

--9. Створити таблицю OrdersArchive що дублює таблицію Orders та має додаткові атрибути
--DeletionDateTime та DeletedBy. Створити тригер, що при видаленні рядків з таблиці Orders
--буде додавати їх в таблицю OrdersArchive та заповнювати відповідні колонки.
CREATE TABLE orders_archive (
    LIKE orders,
    deletion_datetime timestamp with time zone,
    deleted_by name
)

CREATE OR REPLACE FUNCTION set_del_log()
RETURNS trigger AS $$
BEGIN
    INSERT INTO orders_archive 
	SELECT OLD.*,
	       current_timestamp AS deletetion_datetime, 
	       current_user AS deleted_by;
    RETURN NULL;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_set_del_log AFTER DELETE ON
    orders FOR EACH ROW EXECUTE PROCEDURE set_del_log();

--10. Створити три таблиці: TriggerTable1, TriggerTable2 та TriggerTable3. Кожна з таблиць має
--наступну структуру: TriggerId(int) – первинний ключ з автоінкрементом, TriggerDate(Date).
--Створити три тригера. Перший тригер повинен при будь-якому записі в таблицю TriggerTable1
--додати дату запису в таблицю TriggerTable2. Другий тригер повинен при будь-якому записі в
--таблицю TriggerTable2 додати дату запису в таблицю TriggerTable3. Третій тригер працює
--аналогічно за таблицями TriggerTable3 та TriggerTable1. Вставте один рядок в таблицю
--TriggerTable1. Напишіть, що відбулось в коментарі до коду. Чому це сталося?
CREATE TABLE trigger_table1 (
    trigger_id serial PRIMARY KEY,
    trigger_date date
);

CREATE TABLE trigger_table2 (
    trigger_id serial PRIMARY KEY,
    trigger_date date
);

CREATE TABLE trigger_table3 (
    trigger_id serial PRIMARY KEY,
    trigger_date date
);

CREATE OR REPLACE FUNCTION trigger1 ()
RETURNS trigger AS $$
BEGIN
    INSERT INTO trigger_table2 (trigger_date)
        VALUES (current_date);
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger2 ()
RETURNS trigger AS $$
BEGIN
    INSERT INTO trigger_table3 (trigger_date)
        VALUES (current_date);
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger3 ()
RETURNS trigger AS $$
BEGIN
    INSERT INTO trigger_table1 (trigger_date)
        VALUES (current_date);
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_trigger1 BEFORE INSERT ON
    trigger_table1 FOR EACH ROW EXECUTE PROCEDURE trigger1();
	
CREATE TRIGGER tg_trigger2 BEFORE INSERT ON
    trigger_table2 FOR EACH ROW EXECUTE PROCEDURE trigger2();

CREATE TRIGGER tg_trigger3 BEFORE INSERT ON
    trigger_table3 FOR EACH ROW EXECUTE PROCEDURE trigger3();
	
INSERT INTO trigger_table1 (trigger_date) VALUES (current_date);

-- ERROR:  stack depth limit exceeded (перевищено максимально допустиму глибину стеку)
-- При спробі виконати INSERT в таблицю trigger_table1 виникає SQL state: 54001
-- Згідно з офіційною документацією, це означає наступне:
-- Short Description: THE STATEMENT IS TOO LONG OR TOO COMPLEX
-- Отже, останній INSERT запустив ланцюг викликів, здійснюваних трігерами, що призвело
-- до нескіченного циклу. Однак, СУБД здатна опрацьовувати подібні ситуації, запобігаючи
-- операціям, які перевищують ліміт ресурсів, що здатна виділити система.
-- Інакше кажучи, відбулося переповнення стеку внаслідок значного числа колових викликів та
-- досягнення рекурсією критичної глибини, що стало причиною виникнення SQL state: 54001 та припинення
-- подальшого виконання даної операції.

