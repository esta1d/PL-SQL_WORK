-- This is a PL/SQL file.
DECLARE
    cur_order      NUMBER := 155010;
    cur_dsob       NUMBER;
    smv            smvm%ROWTYPE;
    OUT_IS_ERROR   NUMBER;
    OUT_MESSAGE    VARCHAR2 (2000);
    count_remain   NUMBER;

    sm             smvm%ROWTYPE;
BEGIN
    FOR cur
        IN (SELECT DISTINCT box.sobject_id     box,                     --test
                            tov.sobject_Id,
                            e.splace_id,
                            e.d01
              FROM (SELECT tov.sobject_Id,
                           sp.splace_Id,
                           (SELECT DISTINCT sobject_id
                             FROM sobj_Lnk l, sobject bo
                            WHERE     l.SOBJECT_ID_CHILD = tov.SOBJECT_ID
                                  AND l.SOBJ_LNK_TYPE_ID = 1
                                  AND l.SOBJECT_ID_PARENT = bo.SOBJECT_ID
                                  AND bo.SOBJ_TYPE_ID = 2)    box,
                           t.*
                      FROM KSAS_ADM.TMP$TBL2 t, sobject tov, splace sp
                     WHERE     t.V01 = sp.SPLACE_CODE(+)
                           AND tov.SOBJECT_CAG_ID(+) = t.v02) e,
                   sobj_lnk  l,
                   sobject   tov,
                   sobj_lnk  s,
                   sobject   box,
                   sobj_lnk  r
             WHERE     e.SOBJECT_ID = l.SOBJECT_ID_PARENT
                   AND e.box = s.sobject_id_parent
                   AND l.SOBJ_LNK_TYPE_ID = s.sobj_lnk_type_Id
                   AND l.SOBJ_LNK_TYPE_ID = 3
                   AND tov.sobject_Id = l.SOBJECT_ID_CHILD
                   AND box.sobject_Id = s.sobject_Id_child
                   AND tov.sobj_quality_id IN (5, 3, 2)
                   AND tov.SOBJ_QUALITY_REASON_ID NOT IN (6)
                   AND box.sobj_quality_id IN (5, 3, 2)
                   AND (box.SOBJ_QUALITY_REASON_ID NOT IN (6))
                   AND r.sobject_id_child = tov.sobject_id
                   AND r.SOBJECT_ID_PARENT = box.sobject_id
                   AND EXISTS
                           (SELECT 1
                              FROM vsinvent v, SOBJ_PROD_BATCH b
                             WHERE     v.SPLACE_ID = e.SPLACE_ID
                                   AND v.SOBJECT_ID = tov.SOBJECT_ID
                                   AND v.QTY_AVAIL > 0
                                   AND b.SOBJ_PROD_BATCH_ID =
                                       v.SOBJ_PROD_BATCH_ID
                                   AND b.DATE_PRODUCTION = e.d01)
            UNION ALL
            SELECT DISTINCT NULL,
                            tov.sobject_Id,
                            e.splace_id,
                            e.d01
              FROM (SELECT tov.sobject_Id,
                           sp.splace_Id,
                           (SELECT DISTINCT sobject_id
                             FROM sobj_Lnk l, sobject bo
                            WHERE     l.SOBJECT_ID_CHILD = tov.SOBJECT_ID
                                  AND l.SOBJ_LNK_TYPE_ID = 1
                                  AND l.SOBJECT_ID_PARENT = bo.SOBJECT_ID
                                  AND bo.SOBJ_TYPE_ID = 2)    box,
                           t.*
                      FROM KSAS_ADM.TMP$TBL2 t, sobject tov, splace sp
                     WHERE     t.V01 = sp.SPLACE_CODE(+)
                           AND tov.SOBJECT_CAG_ID(+) = t.v02) e,
                   sobj_lnk  l,
                   sobject   tov
             WHERE     e.SOBJECT_ID = l.SOBJECT_ID_PARENT
                   AND l.SOBJ_LNK_TYPE_ID = 3
                   AND tov.sobject_Id = l.SOBJECT_ID_CHILD
                   AND tov.sobj_quality_id IN (5, 3, 2)
                   AND tov.SOBJ_QUALITY_REASON_ID NOT IN (6)
                   AND EXISTS
                           (SELECT 1
                              FROM vsinvent v, SOBJ_PROD_BATCH b
                             WHERE     v.SPLACE_ID = e.SPLACE_ID
                                   AND v.SOBJECT_ID = tov.SOBJECT_ID
                                   AND v.QTY_AVAIL > 0
                                   AND b.SOBJ_PROD_BATCH_ID =
                                       v.SOBJ_PROD_BATCH_ID
                                   AND b.DATE_PRODUCTION = e.d01))     --check
    LOOP
        FOR i
            IN (SELECT v.*,
                       s.SOBJ_QUALITY_ID,
                       s.SOBJ_KEEP_MODE_ID,
                       s.SOBJECT_NAME,
                       b.DATE_PRODUCTION,
                       PKG_REPORT.GET_SPLACE_SOBJ_WEIGHT (
                           v.splace_id,
                           cur.sobject_id,
                           v.sobj_prod_batch_id)    weight
                 FROM wms.vsinvent v, WMS.SOBJECT s, sobj_prod_batch b
                WHERE     v.splace_id = cur.splace_id
                      AND v.QTY_AVAIL > 0
                      AND s.sobject_Id IN (cur.sobject_id, cur.box)
                      AND b.SOBJ_PROD_BATCH_ID = v.SOBJ_PROD_BATCH_ID
                      AND b.DATE_PRODUCTION = cur.d01
                      AND s.SOBJECT_ID = v.SOBJECT_ID
                      AND s.SOBJ_TYPE_ID = 1)
        LOOP
            INSERT INTO d_do_sobject d (d.SOBJECT_ID,
                                        d.DATE_PRODUCTION,
                                        d.DATE_EXPIRATION,
                                        d.SOBJ_PROD_BATCH_ID,
                                        d.SOBJ_QUALITY_ID,
                                        d.SOBJ_KEEP_MODE_ID,
                                        d.QTY_PLAN,
                                        d.QTY_FACT,
                                        d.D_SOBJECT_NAME,
                                        d.WEIGHT_FACT,
                                        d.WEIGHT_PLAN)
                 VALUES (i.sobject_Id,
                         i.DATE_PRODUCTION,
                         i.DATE_EXPIRATION,
                         i.SOBJ_PROD_BATCH_ID,
                         i.SOBJ_QUALITY_ID,
                         i.SOBJ_KEEP_MODE_ID,
                         i.qty_avail,
                         i.qty_avail,
                         i.sobject_name,
                         i.weight,
                         i.weight)
              RETURNING d.d_do_sobject_id
                   INTO cur_dsob;

            INSERT INTO wms.d_order_pos p (p.D_ORDER_ID, p.d_do_sobject_id)
                SELECT cur_order, cur_dsob FROM DUAL;

            FOR j
                IN (SELECT *
                     FROM wms.vsinvent v
                    WHERE     v.SPLACE_ID = cur.splace_id
                          AND v.SOBJ_PROD_BATCH_ID = i.SOBJ_PROD_BATCH_ID --03.03.2025
                          AND v.QTY_AVAIL > 0
                          AND v.sobject_Id IN (cur.sobject_id, cur.box))
            LOOP
                smv := NULL;
                smv.sobject_id := j.sobject_id;
                smv.splace_id_src := j.splace_Id;
                smv.splace_id_dst := -100;
                smv.smvm_type_Id := -5;
                smv.sobj_prod_batch_id := j.sobj_prod_batch_id;
                smv.smvm_status_id := 2;
                smv.date_expiration := j.date_expiration;
                smv.d_order_id := cur_order;
                smv.qty := j.qty_avail;
                smv.weight :=
                    CASE
                        WHEN j.sobject_id = cur.sobject_id
                        THEN
                            PKG_REPORT.GET_SPLACE_SOBJ_WEIGHT (
                                j.splace_id,
                                j.sobject_id,
                                j.sobj_prod_batch_id)
                        ELSE
                            0
                    END;
                PKG_SMVM.NEW_ (smv,
                               OUT_IS_ERROR,
                               OUT_MESSAGE,
                               0);
                DBMS_OUTPUT.put_line (OUT_MESSAGE);

                DELETE FROM
                    SPLACE_WEIGHT_CONTENT c
                      WHERE     c.SPLACE_ID = cur.splace_id
                            AND c.SOBJECT_ID IN (cur.box, cur.sobject_id);
            END LOOP;

            SELECT COUNT (1)
              INTO count_remain
              FROM wms.vsinvent v, sobject so
             WHERE     splace_id = cur.splace_id
                   AND so.SOBJECT_ID = v.SOBJECT_ID
                   AND v.QTY_AVAIL + v.QTY_RES > 0
                   AND so.SOBJ_TYPE_ID IN (1, 2);

            IF count_remain = 0
            THEN
                BEGIN
                    FOR i
                        IN (SELECT *
                             FROM wms.vsinvent
                            WHERE splace_id = cur.splace_id AND qty_avail > 0)
                    LOOP
                        sm := NULL;
                        sm.sobject_id := i.sobject_Id;
                        sm.qty := i.qty_avail;
                        sm.splace_id_src := i.splace_id;
                        sm.splace_id_dst := -100;
                        sm.sobj_prod_batch_id := i.sobj_prod_batch_id;
                        sm.date_expiration := i.DATE_EXPIRATION;
                        sm.smvm_type_id := -99;
                        sm.smvm_status_id := 2;
                        --sm.weight := case when i.sobject_id = 418630 then 391.5 else 394.5 end ;
                        PKG_SMVM.NEW_ (sm,
                                       OUT_IS_ERROR,
                                       OUT_MESSAGE,
                                       0);
                    END LOOP;
                END;
            END IF;
        END LOOP;
    END LOOP;
END;




--check
SELECT *
  FROM WMS.VSINVENT       vi,
       KSAS_ADM.TMP$TBL2  t2,
       WMS.SPLACE         sp,
       WMS.SOBJECT        so,
       WMS.SOBJECT        tov,
       WMS.SOBJ_LNK       lnk
 WHERE     vi.SPLACE_ID = sp.SPLACE_ID
       AND t2.V01 = sp.SPLACE_CODE
       AND t2.V02 = tov.SOBJECT_CAG_ID
       AND so.SOBJECT_ID = vi.SOBJECT_ID
       and lnk.SOBJECT_ID_PARENT=tov.SOBJECT_ID
       and lnk.SOBJ_LNK_TYPE_ID=3
       and lnk.SOBJECT_ID_CHILD=so.SOBJECT_ID
       AND vi.QTY_AVAIL + vi.QTY_RES > 0;


--checking cells for reserves before writing off
SELECT sp.splace_code, si.sobject_id
FROM WMS.SPLACE sp
JOIN wms.sinvent si ON si.SPLACE_ID = sp.SPLACE_ID 
WHERE EXISTS (SELECT 1 FROM KSAS_ADM.TMP$TBL2 kat WHERE kat.V01 = sp.splace_code) AND si.qty_res > 0;