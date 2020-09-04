--1.Вивести за допомогою команди SELECT своє прізвище, ім’я, по-батькові та групу на екран. Українською мовою.
SELECT 'Кінчур Вадим Вікторович ІП-91';
--2.Вибрати всі дані з таблиці Orders.
SELECT * FROM orders;
--3.Обрати всі назви товарів з таблиці Products, продаж яких не припинено.
SELECT *
FROM products
WHERE "Discontinued" = 0; --Here and further used quotes because of capital letters
--4.Вивести всі міста клієнтів уникаючи дублікатів.
SELECT DISTINCT "City"
FROM customers;
--5.Вибрати всі назви компаній-постачальників в порядку зворотному алфавітному.
SELECT "CompanyName"
FROM suppliers
ORDER BY "CompanyName" DESC;
--6.Отримати всі деталі замовлень, замінивши назви в назвах стовпчиків ID на Number.
SELECT "OrderID" AS "OrderNumber",
       "CustomerID" AS "CustomerNumber",
       "EmployeeID" AS "EmployeeNumber",
       "OrderDate",
       "RequiredDate",
       "ShippedDate",
       "ShipVia",
       "Freight",
       "ShipName",
       "ShipAddress",
       "ShipCity",
       "ShipRegion",
       "ShipPostalCode",
       "ShipCountry"
FROM orders;
--7.Знайти трьох постачальників з США. Вивести назву, адресу та телефон.
SELECT "CompanyName",
       "Address",
       "Phone"
FROM suppliers
WHERE "Country" = 'USA'
LIMIT 3;
--8.Вивести всі контактні імена клієнтів, що починаються з першої літери вашого прізвища, імені, по-батькові. Врахувати чутливість до регістру. 
SELECT "ContactName"
FROM customers
WHERE "ContactName" ~* '^[vk]';
--Using one ~* in average is faster than using ILIKE two times
--Explanation: WHERE "CustomerName" ILIKE 'v%' OR "CustomerName" ILIKE 'k%'
--Query ... WHERE "CustomerName" ILIKE '[vk]%' doesn't work correctly in PostgreSQL
--9.Показати усі замовлення, в адресах доставки яких немає крапок.
SELECT *
FROM orders
WHERE "ShipAddress" NOT LIKE '%.%';
--Also can be used (~! '\.') and (~ '[^\.]') but solution with NOT LIKE is faster
--10.Вивести назви тих продуктів, що починаються на знак % або _, а закінчуються на останню літеру вашого імені. Навіть якщо такі відсутні. 
SELECT *
FROM products
WHERE "ProductName" ~* '^[%_].*m$';
--Here used ~* because the last letter can be both 'M' and 'm'

