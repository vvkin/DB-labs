--1. Створити збережену процедуру, що при виклику буде повертати ваше прізвище, ім’я та по-батькові.
CREATE OR REPLACE PROCEDURE get_my_name()
AS $$
    SELECT 'Kinchur' AS last_name,
	   'Vadym' AS first_name,
	   'Viktorovych' AS patronymic;
$$ LANGUAGE SQL;

--2. В контексті бази Northwind створити збережену процедуру, що приймає текстовий параметр
--мінімальної довжини. У разі виклику процедури з параметром ‘F’ на екран виводяться усі
--співробітники-жінки, у разі використання параметру ‘M’ – чоловікі. У протилежному випадку
--вивести на екран повідомлення про те, що параметр не розпізнано.
CREATE OR REPLACE FUNCTION get_employees_by_sex(sex varchar(1))
RETURNS TABLE (LIKE employees) AS $$
BEGIN
    IF sex = 'F' THEN 
        RETURN QUERY SELECT * FROM employees 
        WHERE "TitleOfCourtesy" IN ('Ms.', 'Mrs.');
    ELSIF sex = 'M' THEN
        RETURN QUERY SELECT * FROM employees
        WHERE "TitleOfCourtesy" = 'Mr.' OR "FirstName" = 'Andrew';
    ELSE RAISE EXCEPTION 'Unrecognized Sex %. Only ''F'' and ''M'' values are allowed!', sex;
    END IF;
END
$$ LANGUAGE plpgsql;

--3. В контексті бази Northwind створити збережену процедуру, що виводить усі замовлення за
--заданий період. В тому разі, якщо період не задано – вивести замовлення за поточний день.
CREATE OR REPLACE FUNCTION get_orders_by_period(start_date date, end_date date)
RETURNS TABLE (LIKE orders) AS $$
BEGIN
    IF (start_date IS NULL) OR (end_date is NULL) THEN
        RETURN QUERY SELECT * FROM orders 
	WHERE "OrderDate" = current_date;
    ELSE
	RETURN QUERY SELECT * FROM orders
	WHERE "OrderDate" BETWEEN start_date and end_date;
    END IF;
END
$$ LANGUAGE plpgsql;

--4. В контексті бази Northwind створити збережену процедуру, що в залежності від переданого
--параметру категорії виводить категорію та перелік усіх продуктів за цією категорією.
--Дозволити можливість використати від однієї до п’яти категорій.
CREATE OR REPLACE FUNCTION get_products_by_categories(VARIADIC category varchar(255)[]) 
RETURNS TABLE (
    category_name varchar(255),
    product_id smallint,
    product_name varchar(40),
    supplier_id smallint,
    category_id smallint,
    quantity_per_unit varchar(20),
    unit_price real,
    units_in_stock smallint,
    units_on_order smallint,
    reorder_level smallint,
    discontinued integer
) AS $$
BEGIN
    IF array_length(category, 1) < 5 THEN
        RETURN QUERY 
	SELECT category[i], products.* 
	FROM generate_subscripts(category, 1) g(i)  -- generate table of indices for input
	LEFT JOIN categories ON category[i] = "CategoryName" -- join by category_name
	LEFT JOIN products USING ("CategoryID"); -- search for category_name by category_id
    ELSE
	RAISE EXCEPTION 'Invalid number of parameters';
    END IF;
END
$$ LANGUAGE plpgsql;

--5. В контексті бази Northwind модифікувати збережену процедуру Ten Most Expensive Products
--для виводу всієї інформації з таблиці продуктів, а також імен постачальників та назви
--категорій.
CREATE OR REPLACE FUNCTION ten_most_expensive_products()
RETURNS TABLE (
    product_id smallint,
    product_name varchar(40),
    supplier_id smallint,
    category_id smallint,
    quantity_per_unit varchar(20),
    unit_price real,
    units_in_stock smallint,
    units_on_order smallint,
    reorder_level smallint,
    discontinued integer,
    supplier_name varchar(40),
    category_name varchar(15)
) AS $$
BEGIN
    RETURN QUERY
    SELECT products.*, "CompanyName", "CategoryName"
    FROM products JOIN categories USING ("CategoryID")
    JOIN suppliers USING ("SupplierID")
    ORDER BY "UnitPrice" DESC
    LIMIT 10;
END
$$ LANGUAGE plpgsql;

--6. В контексті бази Northwind створити функцію, що приймає три параметри (TitleOfCourtesy,
--FirstName, LastName) та виводить їх єдиним текстом.
CREATE OR REPLACE FUNCTION concat_values(title_of_courtesy varchar(255), first_name varchar(255), last_name varchar(255))
RETURNS text AS $$
    SELECT concat_ws(' ', $1,$2, $3);
$$ LANGUAGE SQL;

--Приклад: ‘Dr.’, ‘Yevhen’, ‘Nedashkivskyi’ –&gt; ‘Dr. Yevhen Nedashkivskyi’
--7. В контексті бази Northwind створити функцію, що приймає три параметри (UnitPrice, Quantity,
--Discount) та виводить кінцеву ціну.
CREATE OR REPLACE FUNCTION get_discounted_price(unit_price real, quantity int, discount real) 
RETURNS double precision AS $$
    SELECT (1 - discount) * quantity * unit_price;
$$ LANGUAGE SQL;

--8. Створити функцію, що приймає параметр текстового типу і приводить його до Pascal Case.
CREATE OR REPLACE FUNCTION to_pascal_case(string text)
RETURNS text AS $$
    SELECT REPLACE(INITCAP(string), ' ', '');
$$ LANGUAGE SQL;
--Приклад: Мій маленький поні –&gt; МійМаленькийПоні

--9. В контексті бази Northwind створити функцію, що в залежності від вказаної країни, повертає
--усі дані про співробітника у вигляді таблиці.
CREATE OR REPLACE FUNCTION get_employees_by_country(employee_country varchar(255)) 
RETURNS TABLE (LIKE employees) AS $$
    SELECT * FROM employees WHERE "Country" = employee_country;
$$ LANGUAGE SQL;

--10. В контексті бази Northwind створити функцію, що в залежності від імені транспортної компанії
--повертає список клієнтів, якою вони обслуговуються.
CREATE OR REPLACE FUNCTION get_customers_by_shipper(shipper_name varchar(255))
RETURNS TABLE (LIKE customers) AS $$
    SELECT * FROM customers c
    WHERE EXISTS (
        SELECT 1
        FROM shippers s
	JOIN orders o ON s."ShipperID" = o."ShipVia"
	WHERE c."CustomerID" = o."CustomerID" AND
	s."CompanyName" = shipper_name
    );
$$ LANGUAGE SQL;
