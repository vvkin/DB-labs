CREATE DATABASE lazy_student; -- create database

-- create tables
CREATE TABLE accounts (
	account_id serial PRIMARY KEY,
	password varchar(128) NOT NULL
);

CREATE TABLE people (
	person_id serial PRIMARY KEY,
	account_id int REFERENCES accounts (account_id) NOT NULL,
	first_name varchar(60) NOT NULL,
	last_name varchar(60) NOT NULL,
	email varchar(255) UNIQUE,
	phone varchar(24) UNIQUE,
	address varchar(255) NOT NULL,
	card_number varchar(20) UNIQUE NOT NULL,
	CHECK (COALESCE(email, phone) IS NOT NULL)
);

CREATE TABLE tutors (
	tutor_id serial PRIMARY KEY,
	person_id int REFERENCES people (person_id) NOT NULL,
	salary_per_hour numeric(10, 4) NOT NULL,
	rating real DEFAULT 0
);

CREATE TABLE disciplines (
	discipline_id serial PRIMARY KEY,
	discipline_name varchar(255) NOT NULL
);

CREATE TABLE tutors_disciplines (
	record_id serial PRIMARY KEY,
	tutor_id int REFERENCES tutors (tutor_id) NOT NULL,
	discipline_id int REFERENCES disciplines (discipline_id) NOT NULL
);

CREATE TABLE clients (
	client_id serial PRIMARY KEY,
	person_id int REFERENCES people (person_id) NOT NULL,
	entered_date date
);

CREATE TABLE positions (
	position_id serial PRIMARY KEY,
	position_name varchar(100) NOT NULL
);

CREATE TABLE employees (
	employee_id serial PRIMARY KEY,
	person_id int REFERENCES people (person_id) NOT NULL,
	position_id int REFERENCES positions (position_id) NOT NULL
);

CREATE TABLE salaries (
	salary_id serial PRIMARY KEY,
	employee_id int REFERENCES employees (employee_id) NOT NULL,
	salary_value numeric (10, 6) NOT NULL,
	payed_at timestamp
);

CREATE TABLE companies (
	company_id serial PRIMARY KEY,
	company_name varchar(255) NOT NULL,
	contact_phone varchar(24) NOT NULL,
	contact_person varchar(255) NOT NULL,
	bank_account varchar(255) NOT NULL
);

CREATE TABLE vacancies (
	vacancy_id serial PRIMARY KEY,
	vacancy_name varchar(100) UNIQUE NOT NULL
);

CREATE TABLE companies_vacancies (
	record_id serial PRIMARY KEY,
	company_id int REFERENCES companies (company_id) NOT NULL,
	vacancy_id int REFERENCES vacancies (vacancy_id) NOT NULL
);

CREATE TABLE promotions (
	promotion_id serial PRIMARY KEY,
	companion_id int REFERENCES companies (company_id) NOT NULL,
	begin_date date NOT NULL,
	end_date date NOT NULL,
	description text
);

CREATE TABLE order_statuses (
	status_id serial PRIMARY KEY,
	status_name varchar(255) UNIQUE NOT NULL
);

CREATE TABLE orders (
	order_id serial PRIMARY KEY,
	client_id int REFERENCES clients (client_id) NOT NULL,
	employee_id int REFERENCES employees (employee_id) NOT NULL,
	tutors_disciplines_id int REFERENCES tutors_disciplines (record_id),
	companies_vacancies_id INT REFERENCES companies_vacancies (record_id),
	status_id int REFERENCES order_statuses (status_id) NOT NULL,
	price numeric(10, 4) NOT NULL,
	created_date date,
	closed_data date,
	discount real DEFAULT 0,
	CHECK ( (tutors_disciplines_id IS NULL) <> (companies_vacancies_id IS NULL) ) -- XOR CHECK
);

-- reports by date
CREATE OR REPLACE FUNCTION report_by_date(date, date) -- all orders from interval
RETURNS TABLE (LIKE orders) AS $$
BEGIN
	RETURN QUERY SELECT * 
	FROM orders
	WHERE created_date BETWEEN $1 AND $2
	  AND closed_date BETWEEN $1 AND $2;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION report_by_date_financial(date, date) -- only total price
RETURNS TABLE (
	begin_date date,
	end_date date,
	total_price numeric(10, 6)
) AS $$
BEGIN
	RETURN QUERY
	SELECT $1 AS begin_date,
	       $2 AS end_date,
		   COALESCE(0, sum((1 - discount) * price)) AS total_price
	FROM orders
	WHERE created_date BETWEEN $1 AND $2
	  AND closed_date BETWEEN $2 AND $2;
END
$$ LANGUAGE plpgsql;

-- reports by client
CREATE OR REPLACE FUNCTION report_by_client_id(int) -- all orders by client id
RETURNS TABLE (LIKE orders) AS $$
BEGIN
	RETURN QUERY SELECT * 
	FROM orders
	WHERE client_id = $1;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION report_by_client_id_financial(int) -- only total price by client_id
RETURNS TABLE (
	client_id int,
	total_price numeric(10, 6)
) AS $$
BEGIN
	RETURN QUERY 
	SELECT $1 AS client_id,
	       COALESCE(0, sum((1 - discount) * price)) AS total_price
	FROM orders
	WHERE orders.client_id = $1;
END
$$ LANGUAGE plpgsql;

-- reports by tutor
CREATE OR REPLACE FUNCTION report_by_tutor_id(int)
RETURNS TABLE (LIKE orders) AS $$
BEGIN
	RETURN QUERY
	SELECT * FROM orders
	WHERE EXISTS (
		SELECT 1
		FROM tutors_disciplines
		WHERE tutor_id = $1
		  AND tutors_disciplines_id = order_id
	);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION report_by_tutor_id_financial(int)
RETURNS TABLE (
	tutor_id int,
	total_price numeric(10, 6)
) AS $$
BEGIN
	RETURN QUERY
	SELECT $1 AS tutor_id,
	       COALESCE(0, sum((1 - discount) * price)) AS total_price
	FROM orders
	WHERE EXISTS (
		SELECT 1
		FROM tutors_disciplines td
		WHERE td.tutor_id = $1
		  AND tutors_disciplines_id = order_id
	);
END
$$ LANGUAGE plpgsql;

-- reports by company
CREATE OR REPLACE FUNCTION report_by_company_id(int)
RETURNS TABLE (LIKE orders) AS $$
BEGIN
	RETURN QUERY
	SELECT * FROM orders
	WHERE EXISTS (
		SELECT 1
		FROM companies_vacancies cv
		WHERE cv.company_id = $1
		  AND companies_vacancies_id = order_id
	);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION report_by_company_id_financial(int)
RETURNS TABLE (
	company_id int,
	total_price numeric(10, 6)
) AS $$
BEGIN
	RETURN QUERY
	SELECT $1 AS company_id,
	       COALESCE(0, sum((1 - discount) * price)) AS total_price
	FROM orders
	WHERE EXISTS (
		SELECT 1
		FROM companies_vacancies cv
		WHERE cv.company_id = $1
		  AND companies_vacancies_id = order_id
	);
END
$$ LANGUAGE plpgsql;

-- archiving
DO $$ DECLARE t_name text; -- create archive for each table
BEGIN
	FOR t_name IN (
        SELECT quote_ident(table_name)
		FROM   information_schema.tables
		WHERE  table_schema = 'public'
    )
    LOOP
	EXECUTE format(
		'CREATE TABLE IF NOT EXISTS archive_%s
		  (LIKE %s, deletion_datetime timestamp with time zone, deleted_by name)', 
		t_name, t_name
	);
    END LOOP;
END $$;

CREATE OR REPLACE FUNCTION set_deletion_log()  -- on delete trigger
RETURNS TRIGGER AS $$
BEGIN
	EXECUTE format('INSERT INTO archive_%s SELECT OLD.*, current_timestamp, current_user', TG_TABLE_NAME);
	RETURN NULL;
END $$ 
LANGUAGE plpgsql;

DO $$ DECLARE t_name text; -- set trigger for each table
BEGIN
	FOR t_name IN (
        SELECT quote_ident(table_name)
		FROM   information_schema.tables
		WHERE  table_schema = 'public'
		  AND table_name NOT LIKE 'archive[_]%'
    )
    LOOP
	EXECUTE format('CREATE TRIGGER tg_set_deletion_log AFTER DELETE ON
		         %s FOR EACH ROW EXECUTE PROCEDURE set_deletion_log()', t_name);
    END LOOP;
END $$;

-- discounts by registration date
CREATE OR REPLACE FUNCTION set_client_discount_by_time() 
RETURNS TRIGGER AS $$
  DECLARE age int;
BEGIN
	SELECT age(entered_date, current_date)::int 
	INTO age
	FROM clients
	WHERE client_id = NEW.client_id;
	
	SELECT CASE
		WHEN age > 4 THEN 0.15
		WHEN age = 3 THEN 0.11
		WHEN age = 2 THEN 0.08
		WHEN age = 1 THEN 0.05
		ELSE 0.0
	END INTO NEW.discount;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_set_client_discount BEFORE INSERT ON orders 
  FOR EACH ROW EXECUTE PROCEDURE set_client_discount_by_time();
  
-- manage permissions
CREATE ROLE admin;
GRANT ALL ON DATABASE lazy_student TO admin;
GRANT ALL ON SCHEMA "public" TO admin;
GRANT ALL ON ALL TABLES IN SCHEMA "public" TO admin;

CREATE ROLE manager;
GRANT CONNECT ON DATABASE lazy_student TO manager;
GRANT USAGE ON SCHEMA "public" TO manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA "public" TO manager;

CREATE ROLE employee;
GRANT CONNECT ON DATABASE lazy_student TO employee;
GRANT USAGE ON SCHEMA "public" TO employee;
GRANT INSERT, UPDATE, DELETE ON TABLE orders TO employee;

-- give employee SELECT permission to all tables, except archives
DO $$ DECLARE t_name text;
BEGIN
	FOR t_name IN (
        SELECT quote_ident(table_name)
		FROM   information_schema.tables
		WHERE  table_schema = 'public'
		  AND table_name NOT LIKE 'archive[_]%'
    )
    LOOP
	EXECUTE format('GRANT SELECT ON TABLE %s TO employee', t_name);
    END LOOP;
END $$;
