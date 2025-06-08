-- This is a PL/SQL file.
-- Таблица отделов
/*
* department_id: уникальный идентификатор отдела (первичный ключ).
* name_dep: название отдела.
*/
CREATE TABLE departments (
    department_id NUMBER PRIMARY KEY,
    name_dep VARCHAR2(100) NOT NULL
);


-- Таблица офисов
/*
* office_id: уникальный идентификатор офиса (первичный ключ).
* number_office: номер офиса.
* capacity: вместимость офиса (кол-во рабочих мест).
*/
CREATE TABLE offices (
    office_id NUMBER PRIMARY KEY,
    number_office VARCHAR2(20),
    capacity NUMBER
);


-- Таблица должностей
/*
* position_id: уникальный идентификатор должности (первичный ключ).
* title_pos: название должности.
* default_salary: запланированная зарплата по умолчанию для данной должности.
*/
CREATE TABLE positions (
    position_id NUMBER PRIMARY KEY,
    title_pos VARCHAR2(50) NOT NULL,
    default_salary NUMBER(10, 2)
);


-- Таблица сотрудников
/*
* employee_id: уникальный идентификатор сотрудника (первичный ключ).
* first_name: имя сотрудника.
* last_name: фамилия сотрудника.
* middle_name: отчество сотрудника (необязательно).
* birth_date: дата рождения сотрудника.
* salary: зарплата сотрудника.
* manager_id: внешний ключ на руководителя (сотрудника, который является начальником данного сотрудника).
* department_id: внешний ключ на отдел, в котором работает сотрудник.
* office_id: внешний ключ на офис, где находится рабочее место сотрудника (может быть пустым, если сотрудник работает удалённо).
* position_id: внешний ключ на должность, которую занимает сотрудник.
*/
CREATE TABLE employees (
    employee_id NUMBER PRIMARY KEY,
    first_name VARCHAR2(50) NOT NULL,
    last_name VARCHAR2(50) NOT NULL,
    middle_name VARCHAR2(50),
    birth_date DATE,
    salary NUMBER(10, 2),
    manager_id NUMBER REFERENCES employees(employee_id),
    department_id NUMBER REFERENCES departments(department_id),
    office_id NUMBER REFERENCES offices(office_id),
    position_id NUMBER REFERENCES positions(position_id)
);



-- Процедуры --

----------------------------------------------------
--Процедура для добавления нового отдела (add_department)
/*
Процедура принимает один входной параметр p_name. Совпадает типу данных столбца name_dep в таблице departments.
*/
CREATE PROCEDURE add_department(
    p_name IN departments.name_dep%TYPE
) AS
BEGIN
    INSERT INTO departments (name_dep)
    VALUES (p_name);
END add_department;

----------------------------------------------------
--Процедура для добавления нового офиса (add_office)
/*
Процедура принимает два входных параметра:
p_number: Совпадает типу данных столбца number_office в таблице offices. 
p_capacity: Совпадает типу данных столбца capacity в таблице offices.
*/
CREATE PROCEDURE add_office(
    p_number IN offices.number_office%TYPE,
    p_capacity IN offices.capacity%TYPE
) AS
BEGIN
    INSERT INTO offices (number_office, capacity)
    VALUES (p_number, p_capacity);
END add_office;

----------------------------------------------------
--Процедура для добавления новой должности (add_position)
/*
Процедура принимает два входных параметра:
p_title: Соответствует типу данных столбца title_pos в таблице positions.
p_default_salary: Соответствует типу данных столбца default_salary в таблице positions.
*/
CREATE PROCEDURE add_position(
    p_title IN positions.title_pos%TYPE,
    p_default_salary IN positions.default_salary%TYPE
) AS
BEGIN
    INSERT INTO positions (title_pos, default_salary)
    VALUES (p_title, p_default_salary);
END add_position;

-----------------------------------------------------
-- Процедура для добавления нового сотрудника (add_employee)
/*
Процедуре передаётся несколько параметров, каждый из которых соответствует определённому полю в таблице employees:

p_first_name — имя сотрудника.
p_last_name — фамилия сотрудника.
p_middle_name — отчество сотрудника (по умолчанию NULL, поскольку оно необязательно).
p_birth_date — дата рождения сотрудника.
p_salary — зарплата сотрудника.
p_manager_id — идентификатор руководителя данного сотрудника (также необязателен, по умолчанию NULL).
p_department_id — идентификатор департамента, к которому относится сотрудник.
p_office_id — идентификатор офиса, где работает сотрудник (необязательно, по умолчанию NULL).
p_position_id — идентификатор должности сотрудника.

*/
CREATE PROCEDURE add_employee(
    p_first_name IN employees.first_name%TYPE,
    p_last_name IN employees.last_name%TYPE,
    p_middle_name IN employees.middle_name%TYPE DEFAULT NULL,
    p_birth_date IN employees.birth_date%TYPE,
    p_salary IN employees.salary%TYPE,
    p_manager_id IN employees.manager_id%TYPE DEFAULT NULL,
    p_department_id IN employees.department_id%TYPE,
    p_office_id IN employees.office_id%TYPE DEFAULT NULL,
    p_position_id IN employees.position_id%TYPE
) AS
BEGIN
    INSERT INTO employees (
        first_name, last_name, middle_name, birth_date, salary, manager_id, department_id, office_id, position_id
    ) VALUES (
        p_first_name, p_last_name, p_middle_name, p_birth_date, p_salary, p_manager_id, p_department_id, p_office_id, p_position_id
    );
END add_employee;






--Дополним процедуру проверкой
CREATE OR REPLACE PROCEDURE add_employee(
    p_first_name IN employees.first_name%TYPE,
    p_last_name IN employees.last_name%TYPE,
    p_middle_name IN employees.middle_name%TYPE DEFAULT NULL,
    p_birth_date IN employees.birth_date%TYPE,
    p_salary IN employees.salary%TYPE DEFAULT NULL,
    p_manager_id IN employees.manager_id%TYPE DEFAULT NULL,
    p_department_id IN employees.department_id%TYPE,
    p_office_id IN employees.office_id%TYPE DEFAULT NULL,
    p_position_id IN employees.position_id%TYPE
) AS
    v_capacity NUMBER;
    v_occupied_count NUMBER;
BEGIN
    -- Получаем вместимость офиса
    SELECT capacity INTO v_capacity FROM offices WHERE office_id = p_office_id;
    
    -- Считаем количество занятых мест в офисе
    SELECT COUNT(*) INTO v_occupied_count FROM employees WHERE office_id = p_office_id;
    
    IF (v_capacity IS NULL OR v_occupied_count >= v_capacity) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Нет свободных мест в офисе!');
    END IF;
    
    -- Если зарплата не указана, получаем значение по умолчанию для должности
    IF p_salary IS NULL THEN
        SELECT default_salary INTO p_salary FROM positions WHERE position_id = p_position_id;
    END IF;
    
    -- Добавление сотрудника
    INSERT INTO employees (
        first_name, last_name, middle_name, birth_date, salary, manager_id, department_id, office_id, position_id
    ) VALUES (
        p_first_name, p_last_name, p_middle_name, p_birth_date, p_salary, p_manager_id, p_department_id, p_office_id, p_position_id
    );
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'Указанная должность или офис не найдены!');
END add_employee;



--Удаление связи с сотрудником при его увольнении
CREATE PROCEDURE delete_employee(p_employee_id IN employees.employee_id%TYPE) AS
BEGIN
    -- Обновляем подчиненных, устанавливая их начальника в NULL
    UPDATE employees SET manager_id = NULL WHERE manager_id = p_employee_id;
    
    -- Удаляем сотрудника
    DELETE FROM employees WHERE employee_id = p_employee_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'Ошибка при удалении сотрудника.');
END delete_employee;




--ЗАНОСИМ ДАННЫЕ В ТАБЛИЦУ 
INSERT INTO departments (department_id, name_dep) VALUES (1, 'Бухгалтерия');
INSERT INTO departments (department_id, name_dep) VALUES (2, 'IT-отдел');
INSERT INTO departments (department_id, name_dep) VALUES (3, 'Маркетинг');
INSERT INTO departments (department_id, name_dep) VALUES (4, 'HR');

INSERT INTO offices (office_id, number_office, capacity) VALUES (1, '101', 10);
INSERT INTO offices (office_id, number_office, capacity) VALUES (2, '201', 15);
INSERT INTO offices (office_id, number_office, capacity) VALUES (3, '301', 8);

INSERT INTO positions (position_id, title_pos, default_salary) VALUES (1, 'Главный бухгалтер', 80000);
INSERT INTO positions (position_id, title_pos, default_salary) VALUES (2, 'Программист', 60000);
INSERT INTO positions (position_id, title_pos, default_salary) VALUES (3, 'Менеджер по маркетингу', 55000);
INSERT INTO positions (position_id, title_pos, default_salary) VALUES (4, 'HR-менеджер', 45000);

-- Главный бухгалтер (бухгалтерия, офис 101)
INSERT INTO employees (employee_id, first_name, last_name, middle_name, birth_date, salary, manager_id, department_id, office_id, position_id) 
VALUES (1, 'Иван', 'Иванов', 'Иванович', TO_DATE('1980-01-01', 'YYYY-MM-DD'), 80000, NULL, 1, 1, 1);

-- Программисты (IT-отдел, офис 201)
INSERT INTO employees (employee_id, first_name, last_name, middle_name, birth_date, salary, manager_id, department_id, office_id, position_id) 
VALUES (2, 'Сергей', 'Сергеев', 'Сергеевич', TO_DATE('1985-05-12', 'YYYY-MM-DD'), 60000, 1, 2, 2, 2);
INSERT INTO employees (employee_id, first_name, last_name, middle_name, birth_date, salary, manager_id, department_id, office_id, position_id) 
VALUES (3, 'Алексей', 'Алексеев', 'Алексеевич', TO_DATE('1990-08-25', 'YYYY-MM-DD'), 65000, 1, 2, 2, 2);
INSERT INTO employees (employee_id, first_name, last_name, middle_name, birth_date, salary, manager_id, department_id, office_id, position_id) 
VALUES (8, 'Дмитрий', 'Дмитриев', 'Дмитриевич', TO_DATE('1990-06-13', 'YYYY-MM-DD'), 62000, 1, 2, NULL, 2);
INSERT INTO employees (employee_id, first_name, last_name, middle_name, birth_date, salary, manager_id, department_id, office_id, position_id) 
VALUES (9, 'Виктор', 'Викторов', 'Викторович', TO_DATE('1988-03-27', 'YYYY-MM-DD'), 58000, 1, 2, NULL, 2);

-- Менеджеры по маркетингу (маркетинг, офис 301)
INSERT INTO employees (employee_id, first_name, last_name, middle_name, birth_date, salary, manager_id, department_id, office_id, position_id) 
VALUES (4, 'Анна', 'Пупкина', 'Анатольевна', TO_DATE('1992-11-30', 'YYYY-MM-DD'), 55000, 1, 3, 3, 3);
INSERT INTO employees (employee_id, first_name, last_name, middle_name, birth_date, salary, manager_id, department_id, office_id, position_id) 
VALUES (5, 'Елена', 'Весёлова', 'Васильевна', TO_DATE('1995-04-15', 'YYYY-MM-DD'), 53000, 1, 3, 3, 3);

-- HR-менеджеры (HR, офис 101)
INSERT INTO employees (employee_id, first_name, last_name, middle_name, birth_date, salary, manager_id, department_id, office_id, position_id) 
VALUES (6, 'Ольга', 'Широкова', 'Олеговна', TO_DATE('1987-07-19', 'YYYY-MM-DD'), 45000, 1, 4, 1, 4);
INSERT INTO employees (employee_id, first_name, last_name, middle_name, birth_date, salary, manager_id, department_id, office_id, position_id) 
VALUES (7, 'Татьяна', 'Кузнецова', 'Андреевна', TO_DATE('1990-09-22', 'YYYY-MM-DD'), 43000, 1, 4, 1, 4);









-- Количество сотрудников в каждом отделе (по убыванию количества)
SELECT d.name_dep AS department_name, COUNT(e.employee_id) AS employee_count
FROM employees e
JOIN departments d ON e.department_id = d.department_id
GROUP BY d.name
ORDER BY employee_count DESC;



--Сотрудники и их возраст (полных лет), а также день, месяц (словом) и год
SELECT 
    e.first_name || ' ' || e.last_name || COALESCE(' ' || e.middle_name, '') AS full_name,
    TRUNC(MONTHS_BETWEEN(SYSDATE, e.birth_date)/12) AS age_years,
    EXTRACT(DAY FROM e.birth_date) AS day_of_birth,
    TO_CHAR(e.birth_date, 'TMMonth', 'NLS_DATE_LANGUAGE=RUSSIAN') AS month_of_birth,
    EXTRACT(YEAR FROM e.birth_date) AS year_of_birth
FROM employees e;


--Сотрудники, у которых есть однофамильцы
WITH employee_list AS (
    SELECT 
        e.employee_id,
        e.first_name || ' ' || e.last_name || COALESCE(' ' || e.middle_name, '') AS full_name,
        e.last_name
    FROM employees e
)
SELECT 
    el.full_name AS main_employee,
    LISTAGG(el2.full_name, ', ') WITHIN GROUP (ORDER BY el2.full_name) AS coworkers_with_same_last_name
FROM employee_list el
JOIN employee_list el2 ON el.last_name = el2.last_name AND el.employee_id <> el2.employee_id
GROUP BY el.employee_id, el.full_name;





--Сотрудники, имеющие максимальный уровень заработной платы в своём отделе
WITH max_sal_by_dept AS (
    SELECT 
        department_id,
        MAX(salary) AS max_salary
    FROM employees
    GROUP BY department_id
)
SELECT 
    e.first_name || ' ' || e.last_name || COALESCE(' ' || e.middle_name, '') AS full_name,
    e.salary,
    d.name_dep AS department_name
FROM employees e
JOIN departments d ON e.department_id = d.department_id
JOIN max_sal_by_dept msbd ON e.department_id = msbd.department_id AND e.salary = msbd.max_salary;


--Список Год, Месяц, Количество дней рождений сотрудников в этом месяце
SELECT 
    EXTRACT(YEAR FROM e.birth_date) AS birth_year,
    TO_CHAR(e.birth_date, 'Month') AS birth_month,
    COUNT(*) AS count_of_birthdays_in_month
FROM employees e
GROUP BY EXTRACT(YEAR FROM e.birth_date), TO_CHAR(e.birth_date, 'Month')
ORDER BY birth_year, birth_month;


--Список офисов, в которых есть ещё свободные места. Отсортировать по убыванию количества мест
SELECT 
    o.office_id,
    o.number_office AS office_number,
    o.capacity AS total_capacity,
    o.capacity - COUNT(e.employee_id) AS free_places
FROM offices o
LEFT JOIN employees e ON o.office_id = e.office_id
GROUP BY o.office_id, o.number_office, o.capacity
HAVING o.capacity > COUNT(e.employee_id)
ORDER BY free_places DESC;