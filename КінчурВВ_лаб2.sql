--1.1 Необхідно знайти кількість рядків в таблиці, що містить більше ніж 2147483647 записів. Напишіть код для MS SQL Server та ще одніє СУБД (на власний вибір).
SELECT count_big(*) FROM some_big_table; --MSSQL
SELECT count(*) FROM some_big_table; --PostgreSQL

--1.2 Підрахувати довжину свого прізвища, імені та по-батькові за допомогою SQL. Результат вивести в три колонки.
SELECT char_length('Кінчур') AS last_name_len,
       char_length('Вадим')  AS first_name_len,
       char_length('Вікторович') AS patronymic_len;

--1.3 Взявши рядок з виконавцем та назвою пісні, яку ви слухали останньою, замінити пробіли на знаки нижнього підкреслювання.
SELECT regexp_replace('Victor Tsoi "Kukushka"', '\s+', '_', 'g'); 
--Query replace consecutive spaces with one _
--'a   b' = 'a_b' not 'a___b'

--1.4 Створити генератор імені електронної поштової скриньки, що шляхом конкатенації
--об’єднував би дві перші літери з колонки імені, та чотири перші літери з колонки прізвища
--користувача, що зберігаються в базі даних, а також домену з вашим прізвищем.
CREATE OR REPLACE FUNCTION generate_email(first_name text, last_name text)
RETURNS text AS $$
  SELECT concat(left(first_name, 2), left(last_name, 4), '@kinchur.com');
$$ LANGUAGE sql;

SELECT generate_email(first_name, last_name) AS email
FROM some_table;

--1.5 За допомогою SQL визначити, в який день тижня ви народилися.
SELECT extract(isodow FROM DATE '2002-02-04') AS day_num;

--2.1 Вивести усі данні по продуктам, їх категоріям, та постачальникам, навіть якщо останні з певних причин відсутні.
SELECT p.*, c.*, s.*
FROM products p
  LEFT JOIN categories c ON p."CategoryID" = c."CategoryID"
  LEFT JOIN suppliers s ON p."SupplierID" = s."SupplierID";

--2.2 Показати усі замовлення, що були зроблені в квітні 1998 року та не були відправлені.
SELECT *
FROM orders
WHERE date_trunc('month', "OrderDate") = '1998-04-01' 
  AND "ShippedDate" IS NULL; 

--2.3 Відібрати усіх працівників, що відповідають за південний регіон.
SELECT * 
FROM employees
WHERE "EmployeeID" IN (
    SELECT "EmployeeID"
    FROM employeeterritories
    WHERE "TerritoryID" IN (
	SELECT "TerritoryID"
	FROM territories
	WHERE "RegionID" IN (
	    SELECT "RegionID"
	    FROM region
	    WHERE "RegionDescription" = 'Western'
	)
    )
);

--2.4 Вирахувати загальну вартість з урахуванням знижки усіх замовлень, що були здійснені на непарну дату.
SELECT sum(discounted_price) AS total_price
FROM (
    SELECT "UnitPrice" * "Quantity" * (1 - "Discount") AS discounted_price
    FROM order_details
    WHERE "OrderID" IN (
        SELECT "OrderID"
        FROM orders
        WHERE extract('day' FROM "OrderDate")::int % 2 = 1
    ) 
) discounted_prices;

--2.5 Знайти адресу відправлення замовлення з найбільшою ціною позиції (враховуючи вартість товару, його кількість та наявність знижки). Якщо таких замовлень декілька -- - повернути найновіше.
SELECT "ShipAddress"
FROM (
  SELECT "ShipAddress",
         "UnitPrice" * "Quantity" * (1 - "Discount") AS discounted_price
  FROM order_details od
    JOIN orders o ON od."OrderID" = o."OrderID"
  ORDER BY discounted_price DESC, "ShipAddress" DESC
  LIMIT 1
) sub;

