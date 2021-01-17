--1. Створити базу даних з ім’ям, що відповідає вашому прізвищу англійською мовою.
CREATE DATABASE kinchur;

--2. Створити в новій базі таблицю Student з атрибутами StudentId, SecondName, FirstName, Sex. 
--Обрати для них оптимальний тип даних в вашій СУБД.
CREATE TABLE student (
	student_id int NOT NULL,
	first_name varchar(255) NOT NULL,
	last_name varchar(255) NOT NULL,
	sex varchar(255) NOT NULL          -- today we have more than two genders :)
);
--OR:
--  ...
--  sex_id int REFERENCES genders (gender_id) 
--to enable choice option for users

--3. Модифікувати таблицю Student. Атрибут StudentId має стати первинним ключем.
ALTER TABLE student
ADD PRIMARY KEY (student_id);

--4. Модифікувати таблицю Student. Атрибут StudentId повинен заповнюватися автоматично починаючи з 1 і кроком в 1.
CREATE TABLE student_archive AS TABLE student;

DELETE FROM student;  -- clear all data and save all privilegies
-- OR TRUNCATE student if there are no custom privilegies on table

ALTER TABLE student
DROP COLUMN student_id,
ADD COLUMN student_id serial PRIMARY KEY;

INSERT INTO student
SELECT first_name, last_name, sex
FROM student_archive;

DROP TABLE student_archive;

-- OR simply add sequence as default value (not optimal if there are big student_id values)
CREATE SEQUENCE student_student_id_seq;
SELECT setval('student_student_id_seq', (SELECT max(student_id) FROM student)); -- to prevent unique pk conflict

ALTER TABLE student 
ALTER COLUMN student_id SET DEFAULT nextval('student_student_id_seq');

--5. Модифікувати таблицю Student. Додати необов’язковий атрибут BirthDate за відповідним типом даних.
ALTER TABLE student
ADD COLUMN birth_date date;

--6. Модифікувати таблицю Student. Додати атрибут CurrentAge, що генерується автоматично на базі існуючих в таблиці даних.
-- Latest PostgresSQL version doesn't support not stored generated columns
ALTER TABLE student
ADD COLUMN current_age int;

CREATE OR REPLACE FUNCTION set_age() RETURNS trigger
AS $$
  BEGIN
    IF NEW.birth_date IS NOT NULL THEN
	  NEW.current_age = date_part('year', age(NEW.birth_date))::int;
    END IF;
    RETURN NEW;
  END
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_age_tg BEFORE INSERT OR UPDATE ON student
  FOR EACH ROW EXECUTE PROCEDURE set_age();

--7. Реалізувати перевірку вставлення даних. Значення атрибуту Sex може бути тільки ‘m’ та ‘f’.
ALTER TABLE student
ADD CONSTRAINT student_valid_sex
CHECK (sex = 'm' OR sex = 'f');

--8. В таблицю Student додати себе та двох «сусідів» у списку групи.
INSERT INTO student (first_name, last_name, sex, birth_date)
VALUES ('Дарія', 'Карявка', 'f', '2002-01-01'),
       ('Вадим', 'Кінчур', 'm', '2002-04-02'),
       ('Ілля', 'Коробка', 'm', '2002-01-01');

--9. Створити представлення vMaleStudent та vFemaleStudent, що надають відповідну інформацію.
CREATE VIEW vMaleStudent AS
  SELECT * FROM student
  WHERE sex = 'm';

CREATE VIEW vFemaleStudent AS
  SELECT * FROM student
  WHERE sex = 'f';

--10. Змінити тип даних первинного ключа на TinyInt (або SmallInt) не втрачаючи дані.
BEGIN;
DROP VIEW vMaleStudent; -- drop views to allow column change
DROP VIEW vFemaleStudent;

CREATE TABLE students_archive AS
TABLE students;
TRUNCATE students;

ALTER TABLE students
ALTER COLUMN student_id SET DATA TYPE smallint;

INSERT INTO students  -- restore data in main table
SELECT * FROM students_archive;
DROP TABLE students_archive;

CREATE VIEW vMaleStudent AS -- recreate views
  SELECT * FROM student
  WHERE sex = 'm';

CREATE VIEW vFemaleStudent AS
  SELECT * FROM student
  WHERE sex = 'f';

COMMIT;

