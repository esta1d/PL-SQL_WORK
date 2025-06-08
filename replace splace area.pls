-- This is a PL/SQL file.
DECLARE
    v_floor    NUMBER;
    v_piece    NUMBER;
    v_column   NUMBER;
    v_row      NUMBER := 12210;                             
BEGIN
    FOR cur_pl
        IN (SELECT *
             FROM WMS.V_SPLACE_ALRFSC sp
            WHERE        sp.splace_Code LIKE 'VS1-14%-30'
                     AND SUBSTR (sp.splace_Code, 8, 2) BETWEEN 24 AND 62
                     AND MOD (SUBSTR (sp.splace_Code, 8, 2), 2) = 0
                  )
    LOOP
        SELECT COUNT (1)
          INTO v_floor
          FROM sfloor f
         WHERE f.SROW_ID = v_row AND f.SFLOOR_CODE = cur_pl.sfloor_code;

        IF v_floor = 0
        THEN
            INSERT INTO sfloor f (f.SFLOOR_ORDER,
                                  f.SROW_ID,
                                  f.SFLOOR_FACT,
                                  f.SFLOOR_CODE)
                 VALUES (cur_pl.sfloor_order,
                         v_row,
                         cur_pl.sfloor_fact,
                         cur_pl.sfloor_code)
              RETURNING sfloor_id
                   INTO v_floor;
                      DBMS_OUTPUT.put_line (
                   cur_pl.splace_Code
                || ' создали этаж!');
        ELSIF v_floor = 1
        THEN
            SELECT f.SFLOOR_ID
              INTO v_floor
              FROM sfloor f
             WHERE f.SROW_ID = v_row AND f.SFLOOR_CODE = cur_pl.sfloor_code;
           
        ELSE
            DBMS_OUTPUT.put_line (
                   cur_pl.splace_Code
                || ' Найдено несколько этажей!');
            ROLLBACK;
            RETURN;
        END IF;
        
        SELECT COUNT (1)
          INTO v_piece
          FROM SPIECE f
         WHERE f.SROW_ID = v_row AND f.SPIECE_CODE = cur_pl.SPIECE_CODE;

        IF v_piece = 0
        THEN
            INSERT INTO SPIECE f (f.SPIECE_ORDER,
                                  f.SROW_ID,
                                  f.SPIECE_CODE)
                 VALUES (cur_pl.SPIECE_ORDER,
                         v_row,
                         cur_pl.SPIECE_CODE)
              RETURNING SPIECE_ID
                   INTO v_piece;
                      DBMS_OUTPUT.put_line (
                   cur_pl.splace_Code
                || ' создали кусок!');
        ELSIF v_piece = 1
        THEN
            SELECT f.SPIECE_ID
              INTO v_piece
              FROM SPIECE f
             WHERE f.SROW_ID = v_row AND f.SPIECE_CODE = cur_pl.SPIECE_CODE;
          
        ELSE
            DBMS_OUTPUT.put_line (
                   cur_pl.splace_Code
                || ' Найдено несколько кусков!');
            ROLLBACK;
            RETURN;
        END IF;
        
        SELECT COUNT (1)
          INTO v_column
          FROM SCOLUMN f
         WHERE f.SROW_ID = v_row AND f.SCOLUMN_CODE = cur_pl.SCOLUMN_CODE;

        IF v_column = 0
        THEN
            INSERT INTO SCOLUMN f (f.SCOLUMN_ORDER,
                                  f.SROW_ID,
                                  f.SCOLUMN_CODE)
                 VALUES (cur_pl.SCOLUMN_ORDER,
                         v_row,
                         cur_pl.SCOLUMN_CODE)
              RETURNING f.scolumn_id
                   INTO v_column;
                     DBMS_OUTPUT.put_line (
                   cur_pl.splace_Code
                || ' создали колонну!');
        ELSIF v_column = 1
        THEN
            SELECT f.scolumn_id
              INTO v_column
              FROM SCOLUMN f
             WHERE f.SROW_ID = v_row AND f.SCOLUMN_CODE = cur_pl.SCOLUMN_CODE;
           
        ELSE
            DBMS_OUTPUT.put_line (
                   cur_pl.splace_Code
                || ' Найдено несколько колонн!');
            ROLLBACK;
            RETURN;
        END IF;
        
        update splace s set s.SFLOOR_ID = v_floor, s.SPIECE_ID = v_piece, s.SCOLUMN_ID = v_column where splace_id = cur_pl.splace_Id;
    END LOOP;
END;