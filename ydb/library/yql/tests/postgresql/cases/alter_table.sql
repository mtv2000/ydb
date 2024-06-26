--
-- ALTER_TABLE
--
-- Clean up in case a prior regression run failed
SET client_min_messages TO 'warning';
RESET client_min_messages;
--
-- add attribute
--
CREATE TABLE attmp (initial int4);
INSERT INTO attmp (a, b, c, d, e, f, g,    i,    k, l, m, n, p, q, r, s, t,
	v, w, x, y, z)
   VALUES (4, 'name', 'text', 4.1, 4.1, 2, '(4.1,4.1,3.1,3.1)',
	'c',
	314159, '(1,1)', '512',
	'1 2 3 4 5 6 7 8', true, '(1.1,1.1)', '(4.1,4.1,3.1,3.1)',
	'(0,2,4.1,4.1,3.1,3.1)', '(4.1,4.1,3.1,3.1)',
	'epoch', '01:00:10', '{1.0,2.0,3.0,4.0}', '{1.0,2.0,3.0,4.0}', '{1,2,3,4}');
DROP TABLE attmp;
-- the wolf bug - schema mods caused inconsistent row descriptors
CREATE TABLE attmp (
	initial 	int4
);
INSERT INTO attmp (a, b, c, d, e, f, g,    i,   k, l, m, n, p, q, r, s, t,
	v, w, x, y, z)
   VALUES (4, 'name', 'text', 4.1, 4.1, 2, '(4.1,4.1,3.1,3.1)',
        'c',
	314159, '(1,1)', '512',
	'1 2 3 4 5 6 7 8', true, '(1.1,1.1)', '(4.1,4.1,3.1,3.1)',
	'(0,2,4.1,4.1,3.1,3.1)', '(4.1,4.1,3.1,3.1)',
	'epoch', '01:00:10', '{1.0,2.0,3.0,4.0}', '{1.0,2.0,3.0,4.0}', '{1,2,3,4}');
ALTER INDEX attmp_idx ALTER COLUMN 0 SET STATISTICS 1000;
DROP TABLE attmp;
--
-- rename - check on both non-temp and temp tables
--
CREATE TABLE attmp (regtable int);
CREATE TEMP TABLE attmp (attmptable int);
SELECT * FROM attmp;
--
-- check renaming to a table's array type's autogenerated name
-- (the array type's name should get out of the way)
--
CREATE TABLE attmp_array (id int);
CREATE TABLE attmp_array2 (id int);
DROP TABLE attmp_array;
-- renaming to table's own array type's name is an interesting corner case
CREATE TABLE attmp_array (id int);
-- rename statements with mismatching statement and object types
CREATE TABLE alter_idx_rename_test (a INT);
CREATE INDEX alter_idx_rename_test_idx ON alter_idx_rename_test (a);
CREATE INDEX alter_idx_rename_test_parted_idx ON alter_idx_rename_test_parted (a);
BEGIN;
COMMIT;
BEGIN;
COMMIT;
BEGIN;
COMMIT;
-- FOREIGN KEY CONSTRAINT adding TEST
CREATE TABLE attmp2 (a int primary key);
CREATE TABLE attmp3 (a int, b int);
CREATE TABLE attmp4 (a int, b int, unique(a,b));
CREATE TABLE attmp5 (a int, b int);
-- Insert rows into attmp2 (pktable)
INSERT INTO attmp2 values (1);
INSERT INTO attmp2 values (2);
INSERT INTO attmp2 values (3);
INSERT INTO attmp2 values (4);
-- Insert rows into attmp3
INSERT INTO attmp3 values (1,10);
INSERT INTO attmp3 values (1,20);
INSERT INTO attmp3 values (5,50);
INSERT INTO attmp3 values (5,50);
-- A NO INHERIT constraint should not be looked for in children during VALIDATE CONSTRAINT
create table parent_noinh_convalid (a int);
insert into parent_noinh_convalid values (1);
DROP TABLE attmp5;
DROP TABLE attmp4;
DROP TABLE attmp3;
DROP TABLE attmp2;
-- we leave nv_parent and children around to help test pg_dump logic
-- Foreign key adding test with mixed types
-- Note: these tables are TEMP to avoid name conflicts when this test
-- is run in parallel with foreign_key.sql.
CREATE TEMP TABLE PKTABLE (ptest1 int PRIMARY KEY);
INSERT INTO PKTABLE VALUES(42);
CREATE TEMP TABLE FKTABLE (ftest1 inet);
DROP TABLE FKTABLE;
-- This should succeed, even though they are different types,
-- because int=int8 exists and is a member of the integer opfamily
CREATE TEMP TABLE FKTABLE (ftest1 int8);
-- Check it actually works
INSERT INTO FKTABLE VALUES(42);		-- should succeed
DROP TABLE FKTABLE;
-- This should fail, because we'd have to cast numeric to int which is
-- not an implicit coercion (or use numeric=numeric, but that's not part
-- of the integer opfamily)
CREATE TEMP TABLE FKTABLE (ftest1 numeric);
DROP TABLE FKTABLE;
DROP TABLE PKTABLE;
-- On the other hand, this should work because int implicitly promotes to
-- numeric, and we allow promotion on the FK side
CREATE TEMP TABLE PKTABLE (ptest1 numeric PRIMARY KEY);
INSERT INTO PKTABLE VALUES(42);
CREATE TEMP TABLE FKTABLE (ftest1 int);
-- Check it actually works
INSERT INTO FKTABLE VALUES(42);		-- should succeed
DROP TABLE FKTABLE;
DROP TABLE PKTABLE;
CREATE TEMP TABLE PKTABLE (ptest1 int, ptest2 inet,
                           PRIMARY KEY(ptest1, ptest2));
-- This should fail, because we just chose really odd types
CREATE TEMP TABLE FKTABLE (ftest1 cidr, ftest2 timestamp);
DROP TABLE FKTABLE;
-- Again, so should this...
CREATE TEMP TABLE FKTABLE (ftest1 cidr, ftest2 timestamp);
DROP TABLE FKTABLE;
-- This fails because we mixed up the column ordering
CREATE TEMP TABLE FKTABLE (ftest1 int, ftest2 inet);
DROP TABLE FKTABLE;
DROP TABLE PKTABLE;
-- Test that ALTER CONSTRAINT updates trigger deferrability properly
CREATE TEMP TABLE PKTABLE (ptest1 int primary key);
CREATE TEMP TABLE FKTABLE (ftest1 int);
-- temp tables should go away by themselves, need not drop them.
-- test check constraint adding
create table atacc1 ( test int );
-- should succeed
insert into atacc1 (test) values (4);
drop table atacc1;
-- let's do one where the check fails when added
create table atacc1 ( test int );
-- insert a soon to be failing row
insert into atacc1 (test) values (2);
insert into atacc1 (test) values (4);
drop table atacc1;
-- let's do one where the check fails because the column doesn't exist
create table atacc1 ( test int );
drop table atacc1;
-- something a little more complicated
create table atacc1 ( test int, test2 int, test3 int);
-- should succeed
insert into atacc1 (test,test2,test3) values (4,4,5);
drop table atacc1;
-- inheritance related tests
create table atacc1 (test int);
create table atacc2 (test2 int);
insert into atacc2 (test2) values (3);
drop table atacc2;
drop table atacc1;
-- same things with one created with INHERIT
create table atacc1 (test int);
create table atacc2 (test2 int);
select test2 from atacc2;
drop table atacc1;
-- adding only to a parent is allowed as of 9.2
create table atacc1 (test int);
-- check constraint is not there on child
insert into atacc2 (test) values (-3);
insert into atacc1 (test) values (3);
drop table atacc2;
drop table atacc1;
-- test unique constraint adding
create table atacc1 ( test int ) ;
-- insert first value
insert into atacc1 (test) values (2);
-- should succeed
insert into atacc1 (test) values (4);
drop table atacc1;
-- let's do one where the unique constraint fails when added
create table atacc1 ( test int );
-- insert soon to be failing rows
insert into atacc1 (test) values (2);
insert into atacc1 (test) values (2);
insert into atacc1 (test) values (3);
drop table atacc1;
-- let's do one where the unique constraint fails
-- because the column doesn't exist
create table atacc1 ( test int );
drop table atacc1;
-- something a little more complicated
create table atacc1 ( test int, test2 int);
-- insert initial value
insert into atacc1 (test,test2) values (4,4);
-- should all succeed
insert into atacc1 (test,test2) values (4,5);
insert into atacc1 (test,test2) values (5,4);
insert into atacc1 (test,test2) values (5,5);
drop table atacc1;
-- lets do some naming tests
create table atacc1 (test int, test2 int, unique(test));
-- should fail for @@ second one @@
insert into atacc1 (test2, test) values (3, 3);
drop table atacc1;
-- test primary key constraint adding
create table atacc1 ( id serial, test int) ;
-- insert first value
insert into atacc1 (test) values (2);
-- should succeed
insert into atacc1 (test) values (4);
drop table atacc1;
-- let's do one where the primary key constraint fails when added
create table atacc1 ( test int );
-- insert soon to be failing rows
insert into atacc1 (test) values (2);
insert into atacc1 (test) values (2);
insert into atacc1 (test) values (3);
drop table atacc1;
-- let's do another one where the primary key constraint fails when added
create table atacc1 ( test int );
-- insert soon to be failing row
insert into atacc1 (test) values (NULL);
insert into atacc1 (test) values (3);
drop table atacc1;
-- let's do one where the primary key constraint fails
-- because the column doesn't exist
create table atacc1 ( test int );
drop table atacc1;
-- adding a new column as primary key to a non-empty table.
-- should fail unless the column has a non-null default value.
create table atacc1 ( test int );
insert into atacc1 (test) values (0);
drop table atacc1;
-- this combination used to have order-of-execution problems (bug #15580)
create table atacc1 (a int);
insert into atacc1 values(1);
drop table atacc1;
-- additionally, we've seen issues with foreign key validation not being
-- properly delayed until after a table rewrite.  Check that works ok.
create table atacc1 (a int primary key);
drop table atacc1;
-- we've also seen issues with check constraints being validated at the wrong
-- time when there's a pending table rewrite.
create table atacc1 (a bigint, b int);
insert into atacc1 values(1,1);
drop table atacc1;
-- same as above, but ensure the constraint violation is detected
create table atacc1 (a bigint, b int);
insert into atacc1 values(1,2);
drop table atacc1;
-- something a little more complicated
create table atacc1 ( test int, test2 int);
-- insert initial value
insert into atacc1 (test,test2) values (4,4);
-- should all succeed
insert into atacc1 (test,test2) values (4,5);
insert into atacc1 (test,test2) values (5,4);
insert into atacc1 (test,test2) values (5,5);
drop table atacc1;
-- lets do some naming tests
create table atacc1 (test int, test2 int, primary key(test));
-- only first should succeed
insert into atacc1 (test2, test) values (3, 3);
drop table atacc1;
-- test setting columns to null and not null and vice versa
-- test checking for null values and primary key
create table atacc1 (test int not null);
insert into atacc1 values (null);
drop table atacc1;
-- set not null verified by constraints
create table atacc1 (test_a int, test_b int);
insert into atacc1 values (null, 1);
insert into atacc1 values (2, null);
drop table atacc1;
-- test inheritance
create table parent (a int);
insert into parent values (NULL);
drop table parent;
-- test setting and removing default values
create table def_test (
	c1	int4 default 5,
	c2	text default 'initial_default'
);
drop table def_test;
-- test dropping columns
create table atacc1 (a int4 not null, b int4, c int4 not null, d int4);
insert into atacc1 values (1, 2, 3, 4);
select b,c,d from atacc1;
insert into atacc1 values (11, 12, 13);
insert into atacc1 (b,c,d) values (11,12,13);
-- try adding an oid column, should fail (not supported)
alter table atacc1 SET WITH OIDS;
create table atacc2 (id int4 unique);
drop table atacc2;
-- test create as and select into
insert into atacc1 values (21, 22, 23);
drop table atacc1;
-- test inheritance
create table parent (a int, b int, c int);
insert into parent values (1, 2, 3);
drop table parent;
-- check error cases for inheritance column merging
create table parent (a float8, b numeric(10,4), c text collate "C");
drop table parent;
-- test copy in/out
create table attest (a int4, b int4, c int4);
insert into attest values (1,2,3);
drop table attest;
-- test inheritance
create table dropColumn (a int, b int, e int);
create table renameColumn (a int);
-- Test corner cases in dropping of inherited columns
create table p1 (f1 int, f2 int);
create table p1 (f1 int, f2 int);
create table p1 (f1 int, f2 int);
create table p1 (f1 int, f2 int);
create table p1(id int, name text);
create table p2(id2 int, name text, height int);
-- IF EXISTS test
create table dropColumnExists ();
-- test attinhcount tracking with merged columns
create table depth0();
-- test renumbering of child-table columns in inherited operations
create table p1 (f1 int);
create temp table foo (f1 text, f2 mytype, f3 text);
-- Test index handling in alter table column type (cf. bugs #15835, #15865)
create table anothertab(f1 int primary key, f2 int unique,
                        f3 int, f4 int, f5 int);
create index on anothertab(f2,f3);
drop table anothertab;
-- test that USING expressions are parsed before column alter type / drop steps
create table another (f1 int, f2 text, f3 text);
insert into another values(1, 'one', 'uno');
insert into another values(2, 'two', 'due');
insert into another values(3, 'three', 'tre');
select * from another;
drop table another;
-- Create an index that skips WAL, then perform a SET DATA TYPE that skips
-- rewriting the index.
begin;
create table skip_wal_skip_rewrite_index (c varchar(10) primary key);
commit;
-- We disallow changing table's row type if it's used for storage
create table at_tab1 (a int, b text);
create table at_tab2 (x int, y at_tab1);
drop table at_tab2;
create table at_tab2 (x int, y at_tab1);
drop table at_tab1, at_tab2;
create table at_part_2 (b text, a int);
insert into at_part_2 values ('1.234', 1024);
create index on at_partitioned (b);
create index on at_partitioned (a);
-- disallow recursive containment of row types
create temp table recur1 (f1 int);
create temp table recur2 (f1 int, f2 recur1);
-- SET STORAGE may need to add a TOAST table
create table test_storage (a text);
-- test that SET STORAGE propagates to index correctly
create index test_storage_idx on test_storage (b, a);
-- ALTER COLUMN TYPE with different schema in children
-- Bug at https://postgr.es/m/20170102225618.GA10071@telsasoft.com
CREATE TABLE test_type_diff (f1 int);
CREATE TABLE test_type_diff2 (int_two int2, int_four int4, int_eight int8);
CREATE TABLE test_type_diff2_c1 (int_four int4, int_eight int8, int_two int2);
CREATE TABLE test_type_diff2_c2 (int_eight int8, int_two int2, int_four int4);
CREATE TABLE test_type_diff2_c3 (int_two int2, int_four int4, int_eight int8);
INSERT INTO test_type_diff2_c1 VALUES (1, 2, 3);
INSERT INTO test_type_diff2_c2 VALUES (4, 5, 6);
INSERT INTO test_type_diff2_c3 VALUES (7, 8, 9);
-- check for rollback of ANALYZE corrupting table property flags (bug #11638)
CREATE TABLE check_fk_presence_1 (id int PRIMARY KEY, t text);
BEGIN;
ROLLBACK;
-- check column addition within a view (bug #14876)
create table at_base_table(id int, stuff text);
insert into at_base_table values (23, 'skidoo');
