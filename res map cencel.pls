-- This is a PL/SQL file.
DECLARE
    v_cnt          NUMBER;
    OUT_IS_ERROR   NUMBER;
    out_message    VARCHAR2 (2000);
BEGIN
    -- цикл по заказам
    FOR cur_ord
        IN (SELECT *
             FROM d_order
            WHERE     date_shipment_plan > TRUNC (SYSDATE - 3)
                  AND d_order_number IN ('АТ00-071830'))
    LOOP
        IF PKG_D_ORDER.D_ORDER_GET_CUR_STATUS (cur_ord.d_order_id) NOT IN (1,
                                                                           2,
                                                                           3,
                                                                           8)
        THEN
            DBMS_OUTPUT.put_line (
                   cur_ord.D_order_number
                || ' Заказ в неподходящем статусе');
            CONTINUE;
        END IF;

        SELECT COUNT (1)
          INTO v_cnt
          FROM D_RESERVATION_MAP mp, D_DO_CONTAINER dc
         WHERE     mp.D_DO_CONTAINER_ID = dc.D_DO_CONTAINER_ID
               AND dc.D_DO_CONTAINER_STATUS_ID != 0
               AND mp.IS_CANCELED = 'N'
               AND dc.D_ORDER_ID = cur_ord.d_order_id
               AND EXISTS
                       (SELECT 1
                          FROM smvm m
                         WHERE     m.D_RESERVATION_MAP_ID =
                                   mp.D_RESERVATION_MAP_ID
                               AND m.SMVM_STATUS_ID = 0)
               AND mp.USR_TAKE IS NOT NULL;

        IF v_cnt > 0
        THEN
            DBMS_OUTPUT.put_line (
                cur_ord.D_order_number || ' заказ в работе');
            CONTINUE;
        END IF;

        --удаляем из волны
        DELETE FROM d_wave_content v
              WHERE v.D_ORDER_ID = cur_ord.d_order_id;

        --отменяем все резервы по заказу
        FOR cur_res
            IN (SELECT DISTINCT d_reservation_map_id
                 FROM smvm m
                WHERE     m.SMVM_STATUS_ID = 0
                      AND m.D_ORDER_ID = cur_ord.d_order_id)
        LOOP
            PKG_D_ORDER.D_RESERVATION_MAP_CANCEL (
                cur_res.d_reservation_map_id,
                out_is_error,
                out_message,
                0);

            IF out_is_error != 0
            THEN
                DBMS_OUTPUT.put_line (
                       cur_ord.D_order_number
                    || ' Не получилось отменить резерв');
                CONTINUE;
            END IF;

            UPDATE D_RESERVATION_MAP m
               SET m.D_DO_SOBJECT_COVER_MAP_ID = NULL
             WHERE m.D_RESERVATION_MAP_ID = cur_res.d_reservation_map_id;
        END LOOP;
        
         --ставит нулл на отмененных позициях
            UPDATE D_RESERVATION_MAP m
               SET m.D_DO_SOBJECT_COVER_MAP_ID = NULL
             WHERE m.d_do_container_id in (select dc.d_do_container_id from d_do_container dc where dc.d_order_id =cur_ord.d_order_id )
             and m.IS_CANCELED = 'Y';
             
        --Удаляем d_do_sobject_cover_map
        FOR cur_map IN (SELECT *
                          FROM d_do_sobject_cover_map ma
                         WHERE ma.d_order_id = cur_ord.d_order_id)
        LOOP
            DELETE FROM
                D_DO_SOBJECT_COVER_MAP_REPL r
                  WHERE r.D_DO_SOBJECT_COVER_MAP_ID =
                        cur_map.D_DO_SOBJECT_COVER_MAP_ID;

            DELETE FROM
                D_LOST_LOG l
                  WHERE l.D_DO_SOBJECT_COVER_MAP_ID =
                        cur_map.D_DO_SOBJECT_COVER_MAP_ID;

            DELETE FROM
                D_DO_SOBJECT_COVER_MAP m
                  WHERE m.D_DO_SOBJECT_COVER_MAP_ID =
                        cur_map.D_DO_SOBJECT_COVER_MAP_ID;
        END LOOP;

        PKG_D_ORDER.D_ORDER_SET_STATUS (cur_ord.d_order_id,
                                        1,
                                        OUT_IS_ERROR,
                                        OUT_MESSAGE,
                                        0);

        UPDATE d_do_sobject ds
           SET ds.QTY_FACT = 0, ds.QTY_RESERVED = 0
         WHERE ds.D_DO_SOBJECT_ID IN
                   (SELECT pos.d_do_sobject_id
                      FROM d_order_pos pos
                     WHERE pos.d_order_id = cur_ord.d_order_id);
    END LOOP;
END;