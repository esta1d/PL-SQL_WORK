DECLARE
    V_D_DO_CONTAINER            NUMBER := &D_DO_CONTAINER_ID;
    V_SOBJECT_ID                NUMBER;
    v_count_all_rows            NUMBER;
    v_count_all_rows_usr_proc   NUMBER;
    V_D_RESERVATION_MAP_ID      NUMBER;
    V_D_DO_CONTAINER_POS_ID     NUMBER;

    e_message VARCHAR2(4000);
BEGIN
    BEGIN
        SELECT dp.sobject_id
          INTO V_SOBJECT_ID
          FROM WMS.D_DO_CONTAINER_POS  dp
               JOIN WMS.SOBJECT so ON so.SOBJECT_ID = dp.SOBJECT_ID
         WHERE dp.D_DO_CONTAINER_ID = V_D_DO_CONTAINER AND so.SOBJ_TYPE_ID = 1
         FETCH FIRST 1 ROWS ONLY;

        SELECT COUNT(*)
          INTO v_count_all_rows
          FROM WMS.D_RESERVATION_MAP dr
         WHERE     dr.D_DO_CONTAINER_ID = V_D_DO_CONTAINER
               AND dr.SOBJECT_ID = V_SOBJECT_ID
               AND dr.IS_CANCELED = 'N';

        SELECT COUNT(*)
          INTO v_count_all_rows_usr_proc
          FROM WMS.D_RESERVATION_MAP dr
         WHERE     dr.D_DO_CONTAINER_ID = V_D_DO_CONTAINER
               AND dr.SOBJECT_ID = V_SOBJECT_ID
               AND dr.IS_CANCELED = 'N'
               AND dr.USR_PROC IS NOT NULL;


        IF v_count_all_rows_usr_proc = v_count_all_rows THEN
            SELECT dr.D_RESERVATION_MAP_ID
              INTO V_D_RESERVATION_MAP_ID
              FROM WMS.D_RESERVATION_MAP dr
             WHERE     dr.D_DO_CONTAINER_ID = V_D_DO_CONTAINER
                   AND dr.SOBJECT_ID = V_SOBJECT_ID
                   AND dr.IS_CANCELED = 'N'
                   AND dr.USR_PROC IS NOT NULL
             FETCH FIRST 1 ROWS ONLY;

            UPDATE WMS.D_RESERVATION_MAP dr
               SET dr.USR_TAKE = NULL,
                   dr.DATE_TAKE = NULL,
                   dr.USR_PROC = NULL,
                   dr.DATE_PROC = NULL
             WHERE dr.D_RESERVATION_MAP_ID = V_D_RESERVATION_MAP_ID;
             
             DBMS_OUTPUT.PUT_LINE('��������� ����� � D_RESERVATION_MAP: ' || SQL%ROWCOUNT);

            UPDATE wms.smvm_tbl sm
               SET sm.SMVM_STATUS_ID = 0
             WHERE     sm.D_RESERVATION_MAP_ID = V_D_RESERVATION_MAP_ID
                   AND sm.SMVM_STATUS_ID IN (1, 0);
                   
             DBMS_OUTPUT.PUT_LINE('��������� ����� � SMVM_TBL: ' || SQL%ROWCOUNT);

            SELECT dp.D_DO_CONTAINER_POS_ID
              INTO V_D_DO_CONTAINER_POS_ID
              FROM WMS.D_DO_CONTAINER_POS_DETAIL dp
             WHERE     dp.D_DO_CONTAINER_ID = V_D_DO_CONTAINER
                   AND dp.D_RESERVATION_MAP_ID = V_D_RESERVATION_MAP_ID;

            DELETE FROM
                WMS.D_DO_CONTAINER_POS_DETAIL dp
                  WHERE     dp.D_DO_CONTAINER_ID = V_D_DO_CONTAINER
                        AND dp.D_RESERVATION_MAP_ID = V_D_RESERVATION_MAP_ID;

            UPDATE WMS.D_DO_CONTAINER_POS dp
               SET dp.QTY_FACT = dp.QTY_FACT - 1,
                   dp.WEIGHT_FACT =
                       dp.WEIGHT_FACT - (dp.WEIGHT_FACT / dp.QTY_FACT)
             WHERE     dp.D_DO_CONTAINER_ID = V_D_DO_CONTAINER
                   AND dp.D_DO_CONTAINER_POS_ID = V_D_DO_CONTAINER_POS_ID;
                   
                   
             DBMS_OUTPUT.PUT_LINE('��������� ����� � D_DO_CONTAINER_POS: ' || SQL%ROWCOUNT);

            UPDATE WMS.D_DO_CONTAINER dp
               SET dp.D_DO_CONTAINER_STATUS_ID = 2
             WHERE     dp.D_DO_CONTAINER_ID = V_D_DO_CONTAINER
                   AND dp.D_DO_CONTAINER_STATUS_ID = 3;
                   
                   
             DBMS_OUTPUT.PUT_LINE('��������� ����� � D_DO_CONTAINER: ' || SQL%ROWCOUNT);

            UPDATE D_DO_PACK dp
               SET dp.D_DO_PACK_STATUS_ID = 20
             WHERE     dp.D_DO_PACK_ID IN
                           (SELECT ddp.D_DO_PACK_ID
                             FROM WMS.D_DO_PACK_POS ddp
                            WHERE ddp.D_DO_CONTAINER_ID IN
                                      (SELECT d_do.D_DO_CONTAINER_ID
                                        FROM WMS.D_DO_CONTAINER d_do
                                       WHERE d_do.D_DO_CONTAINER_ID =
                                             V_D_DO_CONTAINER))
                   AND dp.D_DO_PACK_STATUS_ID = 30;
                   
                   
             DBMS_OUTPUT.PUT_LINE('��������� ����� � D_DO_PACK: ' || SQL%ROWCOUNT);

            DBMS_OUTPUT.PUT_LINE('��� ��!');
        ELSE
            DBMS_OUTPUT.PUT_LINE('�� ������ ���-�� �����');
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            e_message := SQLERRM;
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('������: ' || e_message);
    END;
END;
