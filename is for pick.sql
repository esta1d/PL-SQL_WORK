SELECT u.SOBJECT_NAME "Товар",
       u.QTY_PLAN_SKU "Планово в эквиваленте штук",
       u.QTY_PLAN_BOX "Планово в эквиваленте коробов",
       u.QTY_SKU_PICK "Штук в пикинге",
       u.qty_box_pick "Коробов в пикинге",
       u.SPLACE_SKU_STORE "Места с товаром в хранении (штук)",
       u.SPLACE_BOX_STORE "Место с товаро в хранении (коробов)",
       u.qty_plan_sku - nvl(u.qty_sku_pick,0) "К спуску в штуках",
       u.qty_plan_box - nvl(u.qty_box_pick,0) "К спуску в коробах"
  FROM (
  SELECT r.SOBJECT_NAME,
               r.QTY_PLAN_SKU,
               CEIL (r.QTY_PLAN_SKU / NVL (r.QTY_IN_BOX, 1))
                   qty_plan_box,
               (SELECT LISTAGG (
                           DISTINCT splace_code || '(' || qty_avail || ')',
                           ' ,')
                       WITHIN GROUP (ORDER BY splace_code)
                  FROM vsinvent v, V_SPLACE_ALRFSC sp, sarea sa
                 WHERE     v.SPLACE_ID = sp.SPLACE_ID
                       AND sa.SAREA_ID = sp.SAREA_ID
                       AND v.QTY_AVAIL > 0
                       AND sa.IS_FOR_INCOME = 'Y'
                       AND v.SOBJECT_ID = r.sobject_id)
                   splace_sku_store,
               (SELECT SUM (qty_avail)
                 FROM vsinvent v, V_SPLACE_ALRFSC sp, sarea sa
                WHERE     v.SPLACE_ID = sp.SPLACE_ID
                      AND sa.SAREA_ID = sp.SAREA_ID
                      AND v.QTY_AVAIL > 0
                      AND sa.IS_FOR_PICK = 'Y'
                      AND v.SOBJECT_ID = r.sobject_id)
                   qty_sku_pick,
                   (SELECT SUM (qty_avail)
                 FROM vsinvent v, V_SPLACE_ALRFSC sp, sarea sa
                WHERE     v.SPLACE_ID = sp.SPLACE_ID
                      AND sa.SAREA_ID = sp.SAREA_ID
                      AND v.QTY_AVAIL > 0
                      AND sa.IS_FOR_PICK = 'Y'
                      AND v.SOBJECT_ID = r.box)
                   qty_box_pick,
               (SELECT LISTAGG (
                           DISTINCT splace_code || '(' || qty_avail || ')',
                           ' ,')
                       WITHIN GROUP (ORDER BY splace_code)
                 FROM vsinvent v, V_SPLACE_ALRFSC sp, sarea sa
                WHERE     v.SPLACE_ID = sp.SPLACE_ID
                      AND sa.SAREA_ID = sp.SAREA_ID
                      AND v.QTY_AVAIL > 0
                      AND sa.IS_FOR_INCOME = 'Y'
                      AND v.SOBJECT_ID = r.box)
                   splace_box_store
          FROM (SELECT e.*,
                       (SELECT MAX (qty_coverage)
                         FROM sobj_lnk l
                        WHERE     l.SOBJ_LNK_TYPE_ID = 1
                              AND l.SOBJECT_ID_CHILD = e.sobject_id
                              AND l.SOBJECT_ID_PARENT = box)    qty_in_box
                  FROM (SELECT t.*,
                               (SELECT MAX (box.sobject_id)
                                 FROM sobject box, sobj_lnk l
                                WHERE     l.SOBJ_LNK_TYPE_ID = 1
                                      AND l.SOBJECT_ID_CHILD = t.sobject_id
                                      AND l.SOBJECT_ID_PARENT =
                                          box.sobject_id
                                      AND box.sobj_type_id = 2)    box
                          FROM (  SELECT q.SOBJECT_NAME,
                                         q.SOBJECT_ID,
                                         SUM (q.QTY_PLAN_SKU)     qty_plan_sku
                                    FROM ( 
                                     SELECT so.sobject_name,
                                                   so.sobject_id,
                                                   SUM (
                                                         ds.QTY_PLAN
                                                       * NVL (c.qty, 1))    qty_plan_sku
                                              FROM wms.d_order        do,
                                                   d_order_cur_status dcs,
                                                   d_order_pos        pos,
                                                   D_DO_SOBJECT       ds,
                                                   sobject            so,
                                                   SOBJ_COVERAGE_CONTENT c
                                             WHERE     do.D_ORDER_ID =
                                                       dcs.D_ORDER_ID
                                                   AND dcs.D_ORDER_STATUS_ID = 1
                                                   and dcs.d_order_status_id !=1
                                                   AND c.SOBJ_COVERAGE_ID(+) =
                                                       ds.SOBJ_COVERAGE_ID
                                                   AND c.SOBJECT_ID(+) =
                                                       ds.SOBJECT_ID
                                                   AND NOT EXISTS
                                                           (SELECT 1
                                                              FROM D_DO_SOBJECT_COVER_MAP
                                                                   m
                                                             WHERE m.D_ORDER_ID =
                                                                   dcs.D_ORDER_ID)
                                                   AND so.sobject_id =
                                                       ds.SOBJECT_ID
                                                   AND pos.D_ORDER_ID =
                                                       do.d_order_id
                                                   AND ds.D_DO_SOBJECT_ID =
                                                       pos.D_DO_SOBJECT_ID
                                                   AND so.SOBJ_KEEP_MODE_ID = :kep
                                          GROUP BY so.sobject_name,
                                                   so.sobject_id
                                          UNION ALL
                                            SELECT so.sobject_name,
                                                   so.sobject_id,
                                                   SUM (
                                                         (  mp.QTY_PLAN_TOTAL
                                                          - mp.QTY_FOUND_IN_PICK)
                                                       * NVL (c.qty, 1))    qty_plan_sku
                                              FROM wms.d_order         do,
                                                   d_order_cur_status  dcs,
                                                   d_order_pos         pos,
                                                   D_DO_SOBJECT        ds,
                                                   sobject             so,
                                                   SOBJ_COVERAGE_CONTENT c,
                                                   D_DO_SOBJECT_COVER_MAP mp
                                             WHERE     do.D_ORDER_ID =
                                                       dcs.D_ORDER_ID
                                                   AND dcs.D_ORDER_STATUS_ID in (1,2,8)
                                                   AND c.SOBJ_COVERAGE_ID(+) =
                                                       mp.SOBJ_COVERAGE_ID_PICKING
                                                   AND c.SOBJECT_ID(+) =
                                                       ds.SOBJECT_ID
                                                   AND mp.D_DO_SOBJECT_ID =
                                                       ds.D_DO_SOBJECT_ID
                                                   AND so.sobject_id =
                                                       ds.SOBJECT_ID
                                                   AND pos.D_ORDER_ID =
                                                       do.d_order_id
                                                   AND ds.D_DO_SOBJECT_ID = pos.D_DO_SOBJECT_ID
                                                   AND so.SOBJ_KEEP_MODE_ID = :kep
                                                   --AND mp.QTY_FOUND_IN_REPL = 0
                                                   AND mp.QTY_PLAN_TOTAL >
                                                         mp.QTY_FOUND_IN_PICK
                                                       + mp.QTY_FOUND_IN_REPL
                                          GROUP BY so.sobject_name,
                                                   so.sobject_id
                                                   ) q
                                GROUP BY q.SOBJECT_NAME, q.SOBJECT_ID) t) e)
               r) u
 WHERE     --u.qty_plan_sku > NVL (qty_sku_pick, 0)
     -- AND
       u.splace_sku_store IS NOT NULL;