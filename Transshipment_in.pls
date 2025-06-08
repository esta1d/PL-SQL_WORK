-- This is a PL/SQL file.
DECLARE
    sm             smvm%ROWTYPE;
    OUT_IS_ERROR   NUMBER;
    OUT_MESSAGE    VARCHAR2 (2000);
    cur_batch      NUMBER;
    cur_orde       NUMBER := 22520;
    cur_remain     NUMBER;
BEGIN
    FOR cur
        IN (SELECT so.sobject_id,
                   so.sobject_name                    tov_name,
                   so.SHELF_LIFE,
                   sp.splace_id,
                   (SELECT DISTINCT sobject_id
                     FROM sobj_Lnk l, sobject bo
                    WHERE     l.SOBJECT_ID_CHILD = so.SOBJECT_ID
                          AND l.SOBJ_LNK_TYPE_ID = 1
                          AND l.SOBJECT_ID_PARENT = bo.SOBJECT_ID
                          AND bo.SOBJ_TYPE_ID = 2)    box,
                   (SELECT DISTINCT l.QTY_COVERAGE
                     FROM sobj_Lnk l, sobject bo
                    WHERE     l.SOBJECT_ID_CHILD = so.SOBJECT_ID
                          AND l.SOBJ_LNK_TYPE_ID = 1
                          AND l.SOBJECT_ID_PARENT = bo.SOBJECT_ID
                          AND bo.SOBJ_TYPE_ID = 2)    qtybox,
                   (SELECT DISTINCT sobject_name
                     FROM sobj_Lnk l, sobject bo
                    WHERE     l.SOBJECT_ID_CHILD = so.SOBJECT_ID
                          AND l.SOBJ_LNK_TYPE_ID = 1
                          AND l.SOBJECT_ID_PARENT = bo.SOBJECT_ID
                          AND bo.SOBJ_TYPE_ID = 2)    box_name,
                   t.n01,
                   ROUND (t.n02 / t.n01, 10)          weight,
                   t.d02                              d01,
                   t.d02 + so.SHELF_LIFE              EXP,
                   (SELECT MAX (sb.BARCODE_VALUE)
                     FROM sobj_Lnk l, sobject bo, sobject_barcode sb
                    WHERE     l.SOBJECT_ID_CHILD = so.SOBJECT_ID
                          AND l.SOBJ_LNK_TYPE_ID = 1
                          AND bo.SOBJECT_ID = sb.SOBJECT_ID
                          AND sb.SOBJ_BARCODE_TYPE_ID = 2
                          AND l.SOBJECT_ID_PARENT = bo.SOBJECT_ID
                          AND bo.SOBJ_TYPE_ID = 2)    box_EAN,
                   t.v05
             FROM KSAS_ADM.TMP$TBL2 t, sobject so, splace sp
            WHERE     t.V03 = so.SOBJECT_CAG_ID(+)
                  AND t.V04 = sp.splace_code(+)
                  AND v03 IS NOT NULL)
    LOOP
        SELECT NVL (MAX (b.SOBJ_PROD_BATCH_ID), 0)
          INTO cur_batch
          FROM SOBJ_PROD_BATCH b
         WHERE     b.CAGENT_ID = 10
               AND b.DATE_EXPIRATION = cur.EXP
               AND b.DATE_PRODUCTION = cur.d01
               AND b.BATCH_CODE = '          '
               AND b.IS_PROD_BATCH = 0;

        IF cur_batch = 0
        THEN
            INSERT INTO SOBJ_PROD_BATCH b (b.BATCH_CODE,
                                           b.CAGENT_ID,
                                           b.IS_PROD_BATCH,
                                           b.DATE_EXPIRATION,
                                           b.DATE_PRODUCTION)
                 VALUES ('          ',
                         10,
                         0,
                         cur.EXP,
                         cur.d01)
              RETURNING b.SOBJ_PROD_BATCH_ID
                   INTO cur_batch;
        END IF;

        FOR i
            IN (SELECT cur.sobject_Id           sobj,
                       cur.tov_name             nam,
                       cur.n01 * cur.qtybox     qt,
                       cur_batch                sobj_prod,
                       cur.EXP                  ex,
                       1                        typ
                  FROM DUAL
                UNION
                SELECT cur.box       sobj,
                       cur.box_name,
                       cur.n01       qt,
                       cur_batch     sobj_prod,
                       cur.EXP       ex,
                       2
                  FROM DUAL)
        LOOP
            sm := NULL;
            sm.sobject_id := i.sobj;
            sm.qty := i.qt;
            sm.sobj_prod_batch_id := i.sobj_prod;
            sm.date_expiration := i.ex;
            sm.smvm_status_id := 2;
            sm.splace_id_Src := -100;
            sm.splace_id_dst := cur.splace_id;
            sm.smvm_type_id := -6;
            sm.weight := cur.weight * cur.n01;
            sm.p_order_id := cur_orde;
            PKG_SMVM.NEW_ (sm,
                           OUT_IS_ERROR,
                           OUT_MESSAGE,
                           0);

            IF i.typ = 1
            THEN
                INSERT INTO p_sobject p (p.SOBJECT_ID,
                                         p.P_ORDER_ID,
                                         p.P_SOBJECT_NAME,
                                         p.SOBJ_COVERAGE_ID,
                                         p.DATE_PRODUCTION,
                                         p.DATE_EXPIRATION,
                                         p.QTY_PLAN,
                                         p.QTY_FACT_WELL,
                                         p.WEIGHT_PLAN,
                                         p.WEIGHT_FACT)
                     VALUES (i.sobj,
                             cur_orde,
                             i.nam,
                             10,
                             cur.d01,
                             cur.EXP,
                             i.qt,
                             i.qt,
                             cur.weight * i.qt,
                             cur.weight * i.qt);
            END IF;
        END LOOP;

        UPDATE SPLACE_WEIGHT_CONTENT c
           SET c.QTY = c.qty + cur.n01
         WHERE     c.WEIGHT = cur.weight
               AND c.SOBJECT_ID = cur.box
               AND c.BARCODE_VALUE =
                      '(01)'
                   || cur.box_ean
                   || '(11)'
                   || TO_CHAR (cur.d01, 'yymmdd')
                   || '(3103)'
                   || CASE
                          WHEN LENGTH (TO_CHAR (cur.weight * 1000)) = 3
                          THEN
                              '000' || TO_CHAR (cur.weight * 1000)
                          WHEN LENGTH (TO_CHAR (cur.weight * 1000)) = 4
                          THEN
                              '0' || TO_CHAR (cur.weight * 1000)
                          WHEN LENGTH (TO_CHAR (cur.weight * 1000)) = 5
                          THEN
                              '0' || TO_CHAR (cur.weight * 1000)
                      END
               AND c.SPLACE_ID = cur.splace_Id
               AND c.SOBJ_PROD_BATCH_ID = cur_batch;

        IF SQL%ROWCOUNT = 0
        THEN
            INSERT INTO SPLACE_WEIGHT_CONTENT c (c.SPLACE_ID,
                                                 c.SOBJECT_ID,
                                                 c.SOBJ_PROD_BATCH_ID,
                                                 c.QTY,
                                                 c.WEIGHT,
                                                 c.BARCODE_VALUE)
                     VALUES (
                                cur.splace_id,
                                cur.box,
                                cur_batch,
                                cur.n01,
                                cur.weight,
                                   '(01)'
                                || cur.box_ean
                                || '(11)'
                                || TO_CHAR (cur.d01, 'yymmdd')
                                || '(3103)'
                                || CASE
                                       WHEN LENGTH (
                                                TO_CHAR (cur.weight * 1000)) =
                                            3
                                       THEN
                                              '000'
                                           || TO_CHAR (cur.weight * 1000)
                                       WHEN LENGTH (
                                                TO_CHAR (cur.weight * 1000)) =
                                            4
                                       THEN
                                              '00'
                                           || TO_CHAR (cur.weight * 1000)
                                       WHEN LENGTH (
                                                TO_CHAR (cur.weight * 1000)) =
                                            5
                                       THEN
                                           '0' || TO_CHAR (cur.weight * 1000)
                                   END);
        END IF;

        UPDATE SOBJ_WEIGHT_CONTENT c
           SET c.QTY = c.qty + cur.n01
         WHERE     c.WEIGHT = cur.weight
               AND c.SOBJECT_ID_CHILD = cur.box
               AND c.SOBJECT_ID_PARENT = REPLACE (cur.v05, 'PAL')
               AND c.BARCODE_VALUE =
                      '(01)'
                   || cur.box_ean
                   || '(11)'
                   || TO_CHAR (cur.d01, 'yymmdd')
                   || '(3103)'
                   || CASE
                          WHEN LENGTH (TO_CHAR (cur.weight * 1000)) = 3
                          THEN
                              '000' || TO_CHAR (cur.weight * 1000)
                          WHEN LENGTH (TO_CHAR (cur.weight * 1000)) = 4
                          THEN
                              '0' || TO_CHAR (cur.weight * 1000)
                          WHEN LENGTH (TO_CHAR (cur.weight * 1000)) = 5
                          THEN
                              '0' || TO_CHAR (cur.weight * 1000)
                      END
               AND c.SOBJ_PROD_BATCH_ID = cur_batch;

        IF SQL%ROWCOUNT = 0
        THEN
            INSERT INTO SOBJ_WEIGHT_CONTENT c (c.SOBJECT_ID_PARENT,
                                               c.SOBJECT_ID_CHILD,
                                               c.QTY,
                                               c.BARCODE_VALUE,
                                               c.SOBJ_PROD_BATCH_ID,
                                               c.WEIGHT)
                     VALUES (
                                REPLACE (cur.v05, 'PAL'),
                                cur.box,
                                cur.n01,
                                   '(01)'
                                || cur.box_ean
                                || '(11)'
                                || TO_CHAR (cur.d01, 'yymmdd')
                                || '(3103)'
                                || CASE
                                       WHEN LENGTH (
                                                TO_CHAR (cur.weight * 1000)) =
                                            3
                                       THEN
                                              '000'
                                           || TO_CHAR (cur.weight * 1000)
                                       WHEN LENGTH (
                                                TO_CHAR (cur.weight * 1000)) =
                                            4
                                       THEN
                                              '00'
                                           || TO_CHAR (cur.weight * 1000)
                                       WHEN LENGTH (
                                                TO_CHAR (cur.weight * 1000)) =
                                            5
                                       THEN
                                           '0' || TO_CHAR (cur.weight * 1000)
                                   END,
                                cur_batch,
                                cur.weight);
        END IF;

        UPDATE sobj_lnk l
           SET l.QTY = l.qty + cur.n01,
               l.QTY_COVERAGE = l.QTY_COVERAGE + cur.n01
         WHERE     l.SOBJECT_ID_PARENT = REPLACE (cur.v05, 'PAL')
               AND l.SOBJECT_ID_CHILD = cur.box
               AND l.SOBJ_LNK_TYPE_ID = 1;

        IF SQL%ROWCOUNT = 0
        THEN
            INSERT INTO sobj_lnk l (l.SOBJECT_ID_PARENT,
                                    l.SOBJECT_ID_CHILD,
                                    l.SOBJ_LNK_TYPE_ID,
                                    l.QTY,
                                    l.QTY_COVERAGE)
                 VALUES (REPLACE (cur.v05, 'PAL'),
                         cur.box,
                         1,
                         cur.n01,
                         cur.n01);
        END IF;

        SELECT NVL (SUM (v.QTY_AVAIL), 0)
          INTO cur_remain
          FROM WMS.VSINVENT v
         WHERE     v.SPLACE_ID = cur.splace_id
               AND v.SOBJECT_ID = REPLACE (cur.v05, 'PAL')
               AND v.QTY_AVAIL > 0;

        IF cur_remain = 0
        THEN
            BEGIN
                sm := NULL;
                sm.sobject_id := REPLACE (cur.v05, 'PAL');
                sm.qty := 1;
                sm.splace_id_src := -100;
                sm.splace_id_dst := cur.splace_id;
                sm.sobj_prod_batch_id := cur_batch;
                sm.date_expiration := cur.EXP;
                sm.smvm_type_id := -6;
                sm.smvm_status_id := 2;
                --sm.weight := case when i.sobject_id = 418630 then 391.5 else 394.5 end ;
                PKG_SMVM.NEW_ (sm,
                               OUT_IS_ERROR,
                               OUT_MESSAGE,
                               0);
            END;
        END IF;

        UPDATE wms.sobject so
           SET so.WEIGHT = NVL (so.weight, 0) + cur.weight * cur.n01,
               so.SOBJ_KEEP_MODE_ID = 1,
               so.SOBJ_SUB_GROUP_ID =
                   (SELECT box.SOBJ_SUB_GROUP_ID
                      FROM wms.sobject box
                     WHERE box.SOBJECT_ID = cur.box)
         WHERE so.sobject_id = REPLACE (cur.v05, 'PAL');


        SELECT NVL (SUM (v.QTY_AVAIL), 0)
          INTO cur_remain
          FROM WMS.VSINVENT v, sobject so
         WHERE     v.SPLACE_ID = cur.splace_id
               AND v.SOBJECT_ID = so.sobject_id
               AND so.sobj_type_id = 3
               AND so.sobject_id != REPLACE (cur.v05, 'PAL')
               AND v.QTY_AVAIL > 0;

        IF cur_remain != 0
        THEN
            FOR cur_pal
                IN (SELECT v.*
                     FROM WMS.VSINVENT v, sobject so
                    WHERE     v.SPLACE_ID = cur.splace_id
                          AND v.SOBJECT_ID = so.sobject_id
                          AND so.sobj_type_id = 3
                          AND so.sobject_id != REPLACE (cur.v05, 'PAL')
                          AND v.QTY_AVAIL > 0)
            LOOP
                sm := NULL;
                sm.sobject_id := cur_pal.sobject_id;
                sm.qty := 1;
                sm.splace_id_src := cur.splace_id;
                sm.splace_id_dst := -100;
                sm.sobj_prod_batch_id := cur_pal.sobj_prod_batch_id;
                sm.date_expiration := cur_pal.date_expiration;
                sm.smvm_type_id := -6;
                sm.smvm_status_id := 2;
                --sm.weight := case when i.sobject_id = 418630 then 391.5 else 394.5 end ;
                PKG_SMVM.NEW_ (sm,
                               OUT_IS_ERROR,
                               OUT_MESSAGE,
                               0);

                FOR cur_lnk
                    IN (SELECT *
                          FROM sobj_lnk l
                         WHERE l.SOBJECT_ID_PARENT = cur_pal.sobject_id)
                LOOP
                    UPDATE sobj_lnk l
                       SET l.QTY = l.qty + cur_lnk.qty,
                           l.QTY_COVERAGE =
                               l.QTY_COVERAGE + cur_lnk.QTY_COVERAGE
                     WHERE     l.SOBJECT_ID_CHILD = cur_lnk.sobject_id_child
                           AND l.SOBJECT_ID_PARENT = REPLACE (cur.v05, 'PAL');

                    IF SQL%ROWCOUNT = 0
                    THEN
                        INSERT INTO sobj_lnk l (l.SOBJECT_ID_PARENT,
                                                l.SOBJECT_ID_CHILD,
                                                l.SOBJ_LNK_TYPE_ID,
                                                l.QTY,
                                                l.QTY_COVERAGE)
                             VALUES (REPLACE (cur.v05, 'PAL'),
                                     cur_lnk.sobject_id_child,
                                     1,
                                     cur_lnk.qty,
                                     cur_lnk.QTY_COVERAGE);
                    END IF;
                END LOOP;

                FOR cur_wei
                    IN (SELECT *
                          FROM SOBJ_WEIGHT_CONTENT c
                         WHERE c.SOBJECT_ID_PARENT = cur_pal.sobject_id)
                LOOP
                    UPDATE SOBJ_WEIGHT_CONTENT c
                       SET c.QTY = c.qty + cur_wei.qty
                     WHERE     c.SOBJECT_ID_PARENT = REPLACE (cur.v05, 'PAL')
                           AND c.SOBJECT_ID_CHILD = cur_wei.sobject_id_child
                           AND c.SOBJ_PROD_BATCH_ID =
                               cur_wei.sobj_prod_batch_ID
                           AND c.BARCODE_VALUE = cur_wei.barcode_value;

                    IF SQL%ROWCOUNT = 0
                    THEN
                        INSERT INTO SOBJ_WEIGHT_CONTENT c (
                                        c.SOBJECT_ID_PARENT,
                                        c.SOBJECT_ID_CHILD,
                                        c.QTY,
                                        c.BARCODE_VALUE,
                                        c.SOBJ_PROD_BATCH_ID,
                                        c.WEIGHT)
                             VALUES (REPLACE (cur.v05, 'PAL'),
                                     cur_wei.sobject_id_child,
                                     cur_wei.qty,
                                     cur_wei.barcode_value,
                                     cur_wei.sobj_prod_batch_id,
                                     cur_wei.weight);
                    END IF;
                END LOOP;
            END LOOP;
        END IF;
    END LOOP;
END;



-- check
SELECT so.sobject_id,
       so.sobject_name                    tov_name,
       so.SHELF_LIFE,
       sp.splace_id,
       (SELECT DISTINCT sobject_id
         FROM sobj_Lnk l, sobject bo
        WHERE     l.SOBJECT_ID_CHILD = so.SOBJECT_ID
              AND l.SOBJ_LNK_TYPE_ID = 1
              AND l.SOBJECT_ID_PARENT = bo.SOBJECT_ID
              AND bo.SOBJ_TYPE_ID = 2)    box,
       (SELECT DISTINCT l.QTY_COVERAGE
         FROM sobj_Lnk l, sobject bo
        WHERE     l.SOBJECT_ID_CHILD = so.SOBJECT_ID
              AND l.SOBJ_LNK_TYPE_ID = 1
              AND l.SOBJECT_ID_PARENT = bo.SOBJECT_ID
              AND bo.SOBJ_TYPE_ID = 2)    qtybox,
       (SELECT DISTINCT sobject_name
         FROM sobj_Lnk l, sobject bo
        WHERE     l.SOBJECT_ID_CHILD = so.SOBJECT_ID
              AND l.SOBJ_LNK_TYPE_ID = 1
              AND l.SOBJECT_ID_PARENT = bo.SOBJECT_ID
              AND bo.SOBJ_TYPE_ID = 2)    box_name,
       t.n01,
       ROUND (t.n02 / t.n01, 10)          weight,
       t.d02                              d01,
       t.d02 + so.SHELF_LIFE              EXP,
       (SELECT MAX (sb.BARCODE_VALUE)
         FROM sobj_Lnk l, sobject bo, sobject_barcode sb
        WHERE     l.SOBJECT_ID_CHILD = so.SOBJECT_ID
              AND l.SOBJ_LNK_TYPE_ID = 1
              AND bo.SOBJECT_ID = sb.SOBJECT_ID
              AND sb.SOBJ_BARCODE_TYPE_ID = 2
              AND l.SOBJECT_ID_PARENT = bo.SOBJECT_ID
              AND bo.SOBJ_TYPE_ID = 2)    box_EAN,
       t.v05,
       LENGTH (t.v05)
  FROM KSAS_ADM.TMP$TBL2 t, sobject so, splace sp
 WHERE     t.V03 = so.SOBJECT_CAG_ID(+)
       AND t.V04 = sp.splace_code(+)
       AND v03 IS NOT NULL