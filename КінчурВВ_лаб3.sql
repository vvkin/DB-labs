--Завдання 1
--1. Використовуючи SELECT без FROM, поверніть набір з п’яти рядків, що включають дві колонки з вашими улюбленими виконавцями та піснями.
SELECT 'Gorillaz' AS author, 'Feel Good Inc.' AS song
UNION
SELECT 'System Of A Down' AS author, 'Holy Mountains' AS song
UNION
SELECT 'Oliver Tree' AS author, 'Hurt' AS song
UNION
SELECT 'Author' AS author, 'Song' AS song
UNION
SELECT 'Another Author' AS author, 'Another Song' AS song
;

--2. Порівнявши власний порядковий номер в групі з набором із всіх номерів в групі, вивести наекран ;-) якщо він менший за усі з них, або :-D в протилежному випадку.
SELECT 
    CASE
	WHEN 10 < ALL(SELECT generate_series(1, 27)) THEN ';-)'
	ELSE ':-D'
    END;
 
--3. Не використовуючи таблиці, вивести на екран прізвище та ім’я усіх дівчат своєї групи за винятком тих, хто має спільне ім’я з студентками іншої групи.
(
	SELECT 'Єлизавета' AS first_name, 'Дубогриз' AS last_name
	UNION
	SELECT 'Дарія' AS first_name, 'Карявка' AS last_name
	UNION
	SELECT 'Дарина' AS first_name, 'Лічман' AS last_name
	UNION
	SELECT 'Єлизавета' AS first_name, 'Тімченко' AS last_name
	UNION
	SELECT 'Дар''я' AS first_name, 'Шаховська' AS last_name
	UNION
	SELECT 'Юлія' AS first_name, 'Ярмак' AS last_name
)
EXCEPT
(
	SELECT 'Еліза' AS first_name, 'Бераудо' AS last_name
	UNION
	SELECT 'Ірина' AS first_name, 'Колбун' AS last_name
	UNION
	SELECT 'Вікторія' AS first_name, 'Ткаченко' AS last_name
);

--4. Вивести усі рядки з таблиці Numbers (Number INT). Замінити цифру від 0 до 9 на її назву літерами. Якщо цифра більше, або менша за названі, залишити її без змін.
SELECT CASE
		WHEN number = '0' THEN 'zero'
		WHEN number = '1' THEN 'one'
		WHEN number = '2' THEN 'two'
		WHEN number = '3' THEN 'three'
		WHEN number = '4' THEN 'four'
		WHEN number = '5' THEN 'five'
		WHEN number = '6' THEN 'six'
		WHEN number = '7' THEN 'seven'
		WHEN number = '8' THEN 'eight'
		WHEN number = '9' THEN 'nine'
		ELSE number::text
	END AS number
FROM "Numbers";

-- OR

SELECT COALESCE(
	('{"zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"}'::text[])[number + 1],
	number::text
	) AS number
FROM "Numbers";

--5. Навести приклад синтаксису декартового об’єднання для вашої СУБД.
SELECT * FROM first_table CROSS JOIN second_table;

--Завдання 2
--6. Вивести усі замовлення та їх службу доставки. В результуючому наборі в залежності від ідентифікатора, перейменувати одну із служб на таку, що відповідає вашому імені, прізвищу, або по-батькові.
SELECT o.*,
	   s."ShipperID",
	   CASE
		   WHEN s."ShipperID" = 1 THEN 'Kinchur'
		   ELSE s."CompanyName"
	   END AS "CompanyName",
	   s."Phone"
FROM orders o
  JOIN shippers s ON o."ShipVia" = s."ShipperID"
	
--7.Вивести в алфавітному порядку усі країни, що фігурують в адресах клієнтів, працівників, та місцях доставки замовлень.
WITH countries AS (
	SELECT o."ShipCountry" AS ship_country,
	       c."Country" AS customer_country,
	       e."Country" AS employee_country
	FROM orders o
	  JOIN customers c USING("CustomerID")
	  JOIN employees e USING("EmployeeID")
)

SELECT ship_country AS country FROM countries
UNION
SELECT customer_country AS country FROM countries
UNION
SELECT employee_country AS country FROM countries
ORDER BY country;

--8.Вивести прізвище та ім’я працівника, а також кількість замовлень, що він обробив за перший квартал 1998 року.
SELECT "FirstName",
       "LastName",
        count("OrderID") AS "OrderNumber"
FROM orders JOIN employees USING("EmployeeID")
WHERE extract('year' FROM "OrderDate") = 1998
  AND extract('quarter' FROM "OrderDate") = 1
GROUP BY "FirstName", "LastName";

--9.Використовуючи СTE знайти усі замовлення, в які входять продукти, яких на складі більше 80 одиниць, проте по яким немає максимальних знижок.
WITH suitable_orders AS ( -- ID of orders with maximal "Discount" value
    SELECT "OrderID"
    FROM (
        SELECT "OrderID",
                rank() OVER (ORDER BY "Discount" DESC) -- numbering by "Discount" (or dense_rank)
        FROM order_details
        WHERE "ProductID" IN (
            SELECT "ProductID" 
            FROM products
            WHERE "UnitsInStock" > 80
        )
    ) sub
    WHERE RANK <> 1 -- only rows with maximal "Discount" will have RANK = 1
)

SELECT * FROM orders
WHERE "OrderID" IN (
    SELECT * FROM suitable_orders
);

-- Or simply
-- ... SELECT "OrderID" FROM order_details
--     WHERE "Discount" = 0.25 ...
-- But "Discount" value can be changed further, so
-- solution with window function is more universal

--10. Знайти назви усіх продуктів, що не продаються в південному регіоні.
SELECT DISTINCT products."ProductName"
FROM orders
  JOIN order_details USING ("OrderID")
  JOIN employeeterritories USING ("EmployeeID")
  JOIN territories USING ("TerritoryID")
  JOIN region USING("RegionID")
  JOIN products USING ("ProductID")
WHERE "RegionDescription" <> 'Southern'

