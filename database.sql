CREATE TYPE line_item_t;
CREATE TYPE purchase_order_t;
CREATE TYPE stock_info_t;

CREATE TYPE phone_list_t AS VARRAY(10) OF VARCHAR2(20);

CREATE TYPE address_t AS OBJECT (
  street  VARCHAR2(200),
  city    VARCHAR2(200),
  state   CHAR(2),
  zip     VARCHAR2(20)
);

CREATE TYPE customer_info_t AS OBJECT (
  custno     NUMBER,
  custname   VARCHAR2(200),
  address    address_t,
  phone_list phone_list_t,

  ORDER MEMBER FUNCTION
    cust_order(x IN customer_info_t) RETURN INTEGER,

  PRAGMA RESTRICT_REFERENCES (
    cust_order,  WNDS, WNPS, RNPS, RNDS)
);

CREATE TYPE line_item_t AS OBJECT (
  lineitemno NUMBER,
  STOCKREF   REF stock_info_t,
  quantity   NUMBER,
  discount   NUMBER
);

CREATE TYPE line_item_list_t AS TABLE OF line_item_t ;

CREATE TYPE purchase_order_t AS OBJECT (
  pono           NUMBER,
  custref        REF customer_info_t,
  orderdate      DATE,
  shipdate       DATE,
  line_item_list line_item_list_t,
  shiptoaddr     address_t,

  MAP MEMBER FUNCTION
    ret_value RETURN NUMBER,
    PRAGMA RESTRICT_REFERENCES (
      ret_value, WNDS, WNPS, RNPS, RNDS),

  MEMBER FUNCTION
    total_value RETURN NUMBER,
    PRAGMA RESTRICT_REFERENCES (total_value, WNDS, WNPS)
);

CREATE TYPE stock_info_t AS OBJECT (
  stockno    NUMBER,
  cost       NUMBER,
  tax_code   NUMBER
);

CREATE OR REPLACE TYPE BODY purchase_order_t AS
  MEMBER FUNCTION total_value RETURN NUMBER IS
    i          INTEGER;
    stock      stock_info_t;
    line_item  line_item_t;
    total      NUMBER := 0;
    cost       NUMBER;

  BEGIN
    FOR i IN 1..SELF.line_item_list.COUNT  LOOP

      line_item := SELF.line_item_list(i);
      SELECT DEREF(line_item.stockref) INTO stock FROM DUAL ;

      total := total + line_item.quantity * stock.cost ;

      END LOOP;
    RETURN total;
  END;

  MAP MEMBER FUNCTION ret_value RETURN NUMBER IS
  BEGIN
    RETURN pono;
  END;
END;

CREATE OR REPLACE TYPE BODY customer_info_t AS
  ORDER MEMBER FUNCTION
  cust_order (x IN customer_info_t) RETURN INTEGER IS
  BEGIN
    RETURN custno - x.custno;
  END;
END;

CREATE TYPE phone_list_t AS VARRAY(10) OF VARCHAR2(20);

CREATE TABLE stock_tab OF stock_info_t
 (stockno PRIMARY KEY);
 
CREATE TABLE purchase_tab OF purchase_order_t (
  PRIMARY KEY (pono),
  SCOPE FOR (custref) IS customer_tab
  )
  NESTED TABLE line_item_list STORE AS po_line_tab;

CREATE TYPE line_item_list_t AS TABLE OF line_item_t;
  
CREATE INDEX po_nested_in
  ON po_line_tab (NESTED_TABLE_ID);

CREATE UNIQUE INDEX po_nested
  ON po_line_tab (NESTED_TABLE_ID, lineitemno);
  
INSERT INTO stock_tab VALUES(1004, 6750.00, 2);
INSERT INTO stock_tab VALUES(1011, 4500.23, 2);
INSERT INTO stock_tab VALUES(1534, 2234.00, 2);
INSERT INTO stock_tab VALUES(1535, 3456.23, 2);

INSERT INTO customer_tab
  VALUES (
    1, 'Jean Nance',
    address_t('2 Avocet Drive', 'Redwood Shores', 'CA', '95054'),
    phone_list_t('415-555-1212')
    );

INSERT INTO customer_tab
  VALUES (
    2, 'John Nike',
    address_t('323 College Drive', 'Edison', 'NJ', '08820'),
    phone_list_t('609-555-1212','201-555-1212')
    );
    
INSERT INTO purchase_tab
  SELECT  1001, REF(C),
          SYSDATE,'10-MAY-1997',
          line_item_list_t(),
          NULL
   FROM   customer_tab C
   WHERE  C.custno = 1;
   
INSERT INTO THE (
  SELECT  P.line_item_list
   FROM   purchase_tab P
   WHERE  P.pono = 1001
  )
  SELECT  01, REF(S), 12, 0
   FROM   stock_tab S
   WHERE  S.stockno = 1534;

INSERT INTO purchase_tab
  SELECT  2001, REF(C),
          SYSDATE,'20-MAY-1997',
          line_item_list_t(),
          address_t('55 Madison Ave','Madison','WI','53715')
   FROM   customer_tab C
   WHERE  C.custno = 2;

INSERT INTO THE (
  SELECT  P.line_item_list
   FROM   purchase_tab P
   WHERE  P.pono = 1001
  )
  SELECT  02, REF(S), 10, 10
   FROM   stock_tab S
   WHERE  S.stockno = 1535;

INSERT INTO THE (
  SELECT  P.line_item_list
   FROM   purchase_tab P
   WHERE  P.pono = 2001
  )
  SELECT  10, REF(S), 1, 0
   FROM   stock_tab S
   WHERE  S.stockno = 1004;

INSERT INTO THE (
  SELECT  P.line_item_list
   FROM   purchase_tab P
   WHERE  P.pono = 2001
  )
  VALUES( line_item_t(11, NULL, 2, 1) );
  
UPDATE THE (
  SELECT  P.line_item_list
   FROM   purchase_tab P
   WHERE  P.pono = 2001
  ) plist

  SET plist.stockref =
   (SELECT REF(S)
     FROM  stock_tab S
     WHERE S.stockno = 1011
     )

  WHERE plist.lineitemno = 11;
  
SELECT  DEREF(p.custref), p.shiptoaddr, p.pono, 
        p.orderdate, line_item_list
 FROM   purchase_tab p
 WHERE  p.pono = 1001;
 
SELECT   p.pono, p.total_value()
 FROM    purchase_tab p; 
 
SELECT   po.pono, po.custref.custno,
         CURSOR (
           SELECT  *
            FROM   TABLE (po.line_item_list) L
            WHERE  L.stockref.stockno = 1004
           )
 FROM    purchase_tab po; 

