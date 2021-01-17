-- 1. Додати себе як співробітника компанії на позицію Intern.
INSERT INTO employees ("EmployeeID", "LastName", "FirstName", "Title")
VALUES (10, 'Kinchur', 'Vadym', 'Intern');

-- 2. Змінити свою посаду на Director.
UPDATE employees 
SET "Title" = 'Director'
WHERE "EmployeeID" = 10

-- OR
-- ... WHERE "LastName" = 'Kinchur'
--       AND "FirstName" = "Vadym"
--       AND "Title" = 'Intern'
--       AND "EmployeeID" = 10

-- 3. Скопіювати таблицю Orders в таблицю OrdersArchive.
CREATE TABLE "OrdersArchive" AS 
TABLE orders
WITH NO DATA;

INSERT INTO "OrdersArchive"
SELECT * FROM orders;

-- OR
CREATE TABLE "OrdersArchive" AS
TABLE orders;

-- OR
SELECT * INTO "OrdersArchive"
FROM orders;

-- 4. Очистити таблицю OrdersArchive.
DELETE FROM "OrderArchive"; -- slower solution

-- If there are no special roles
TRUNCATE "OrdersArchive"; -- faster solution

-- 5. Не видаляючи таблицю OrdersArchive, наповнити її інформацією повторно.
INSERT INTO "OrdersArchive" 
SELECT * FROM orders;

-- 6. З таблиці OrdersArchive видалити десять замовлень, що були зроблені замовниками із Берліну.
DELETE FROM orders_archive oa
WHERE EXISTS (
  SELECT 1
  FROM customers c
  WHERE "City" = 'Berlin'
    AND oa."CustomerID" = c."CustomerID"
  LIMIT 10
);

-- 7. Внести в базу два продукти з власним іменем та іменем групи.
INSERT INTO products ("ProductID", "ProductName", "Discontinued") 
VALUES (78, 'Vadym', 0), (79, 'IP-91', 0);

-- 8. Помітити продукти, що не фігурують в замовленнях, як такі, що більше не виробляються.
UPDATE products
SET "Discontinued" = 1
WHERE "ProductID" NOT IN (
	SELECT "ProductID"
	FROM order_details
	GROUP BY "ProductID"
);

-- 9. Видалити таблицю OrdersArchive.
DROP TABLE "OrdersArchive";

-- 10. Видалити базу Northwind.
DROP DATABASE northwind;

