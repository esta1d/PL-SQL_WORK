-- This is a PL/SQL file.
DECLARE
    v_is_error NUMBER;
    v_message  VARCHAR2(4000);
BEGIN
    -- Вызов процедуры для добавления паллеты в ячейку
    WMS.replace_PALL_TO_SPLACE(
        IN_SPLACE      => 'FD1-03-30-50', 
        IN_PAL         => 'PAL6777330',    
        out_is_error   => v_is_error,
        out_message    => v_message
    );

    -- Проверка результатов
    IF v_is_error = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Операция выполнена успешно.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Ошибка: ' || v_message);
    END IF;
END;
/