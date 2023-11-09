/********************************************************
--DEMO Auditing Table Changes using Change Data Capture
https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server?view=sql-server-2017 

*****************************************************/

USE [<<Your Database>>]

--NOTE: This will fail if the database has DELAYED_DURABILITY enabled. 
--Starting with CU20 for SQL Server, Microsoft makes you choose one or the other!
--Check first....   SHould be DISABLED

SELECT name, Delayed_durability_desc FROM sys.databases where name=db_name()
GO

--Enable CDC

EXEC sys.sp_cdc_enable_db
 
--Verify:
 
SELECT name, is_cdc_enabled FROM sys.databases where name=db_name()
GO

CREATE TABLE dbo.EmployeeTestCDC
(
  [EmployeeID] int NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
  , [Name] nvarchar(100) NOT NULL
  , [Position] varchar(100) NOT NULL
  , [Department] varchar(100) NOT NULL
  , [Address] nvarchar(1024) NOT NULL
  , [AnnualSalary] decimal (10,2) NOT NULL
  , [CreateDate] Datetime default(getdate())
  , [Modified] Datetime default(getdate())
 )

 GO

 DROP TABLE IF EXISTS validPositions
DROP TABLE IF EXISTS validDepartments

Create TABLE validPositions (Position nvarchar(100))
Create TABLE validDepartments (Department nvarchar(100))

INSERT validPositions values ('System Reliability Engineer')
INSERT validPositions values ('Database Reliability Engineer')
INSERT validPositions values ('FrontEnd Reliability Engineer')
INSERT validPositions values ('Random Reliability Engineer')
INSERT validPositions values ('Software Engineer')
INSERT validPositions values ('Data Engineer')
INSERT validPositions values ('Data Scientist')
INSERT validPositions values ('Random Engineer')
INSERT validPositions values ('Development Engineer')
INSERT validPositions values ('DBRE Manager')
INSERT validPositions values ('SRE Manager')
INSERT validPositions values ('Software Development Manager')

INSERT validDepartments values ('IT Department')
INSERT validDepartments values ('HelpDesk Department')
INSERT validDepartments values ('Data Science')
INSERT validDepartments values ('Big Business Department')
INSERT validDepartments values ('Marketing Department')
INSERT validDepartments values ('Sales Department')
INSERT validDepartments values ('Design Department')
INSERT validDepartments values ('Architecture Department')
INSERT validDepartments values ('Executives')

GO

--Enable CHange Data Capture
EXEC sys.sp_cdc_enable_table @source_schema = N'dbo', @role_name ='cdc_admin', @source_name= N'EmployeeTestCDC'
GO

----------------------------------------------
-- ***** STOP HERE:  WAIT UNTIL Capture Job Gets Created....
--Make Sure they're running in SQLAgent.. 

----------------------------------------------


--CREATE THE INSERT/UPDATE PROCS

CREATE OR ALTER PROC spAddEmployeeInfo_CDC
@Name nvarchar(100), @position nvarchar(100) ,@Department nvarchar(100) ,
@Address nvarchar(1024) ,@AnnualSalary money
AS

INSERT INTO EmployeeTestCDC (Name, Position, Department, Address, AnnualSalary)
SELECT @Name, @position,@Department ,@Address, @AnnualSalary

GO



CREATE OR ALTER PROC spUpdateEmployeeInfo_CDC
@EmployeeID int, 
@position nvarchar(100)=NULL,
@Department nvarchar(100)=NULL,
@Address nvarchar(1024)=NULL ,
@AnnualSalary money=NULL
AS


UPDATE EmployeeTestCDC
SET 
Department=ISNULL(@Department,Department),
Position=ISNULL(@position,Position),
Address=ISNULL(@Address,Address),
AnnualSalary=ISNULL(@AnnualSalary,AnnualSalary),
MOdified=getdate()

FROM EmployeeTestCDC
where EmployeeID=@EmployeeID
GO



--RUN TEST.  COPY/PASTE THE CODE BELOW INTO SEPARATE WINDOW OR STRESS TEST TOOL OF YOUR CHOICE
--BEGIN COPY...
		--Generate a random string of random length 
				DECLARE @AlLChars varchar(100) = 'a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z'
				DECLARE @EmployeeID INT
				DECLARE @FirstName varchar(100)
				DECLARE @LastName varchar(100)
				DECLARE @FullName varchar(300)
				DECLARE @LongString nvarchar(1024)
				DECLARE @Salary money
				DECLARE @position nvarchar(100)
				DECLARE @Department nvarchar(100) 

				SET @position=(SELECT TOP 1 Position from validPositions ORDER BY NEWID())
				SET @Department=(SELECT TOP 1 Department from validDepartments ORDER BY NEWID())


				SET @FirstName=(SELECT 
				SUBSTRING(string_agg(value,'') WITHIN GROUP (ORDER BY NEWID()),1,abs(CHECKSUM(newid()))%8+5)
				FROM string_split(@AlLChars,','))

				SET @LastName=(SELECT 
				SUBSTRING(string_agg(value,'') WITHIN GROUP (ORDER BY NEWID()),1,abs(CHECKSUM(newid()))%8+5)
				FROM string_split(@AlLChars,','))

				SELECT @FullName=UPPER(LEFT(@FirstName,1))+@FirstName+' '+UPPER(LEFT(@LastName,1))+@LastName

				SET @LongString=(
				SELECT REPLICATE(SUBSTRING(string_agg(value,'') WITHIN GROUP (ORDER BY NEWID()),1,abs(CHECKSUM(newid()))%1024),100)
				FROM string_split(@AlLChars,',')
				)

				SET @Salary=(SELECT abs(CHECKSUM(newid()))%1000000)

		--EXEC the INSERT proc!
		EXEC spAddEmployeeInfo_CDC @FullName, @position, @Department, @LongString, @Salary

		--Generate Random Data for the UpdaTE PROC...


				SET @position=(SELECT TOP 1 Position from validPositions ORDER BY NEWID())
				SET @Department=(SELECT TOP 1 Department from validDepartments ORDER BY NEWID())

				SET @LongString=(
				SELECT REPLICATE(SUBSTRING(string_agg(value,'') WITHIN GROUP (ORDER BY NEWID()),1,abs(CHECKSUM(newid()))%1024),100)
				FROM string_split(@AlLChars,',')
				)

				SET @Salary=(SELECT abs(CHECKSUM(newid()))%1000000)

				SET @EmployeeID=(SELECT TOP 1 EmployeeID FROM EmployeeTest ORDER BY NEWID())

		--Update Position
		EXEC spUpdateEmployeeInfo_CDC @EmployeeID,@position=@position

		--Update Department
		EXEC spUpdateEmployeeInfo_CDC @EmployeeID,@Department=@Department

		--Update Salary
		EXEC spUpdateEmployeeInfo_CDC @EmployeeID,@AnnualSalary=@Salary

		--Update Address
		EXEC spUpdateEmployeeInfo_CDC @EmployeeID,@Address=@LongString

--END COPY


--Query from the Change table
SELECT * FROM cdc.dbo_EmployeeTestCDC_CT

select * FROM cdc_jobs

ALTER TABLE cdc.dbo_EmployeeTestCDC_CT REBUILD WITH (DATA_COMPRESSION=PAGE)

exec sp_spaceused 'cdc.dbo_EmployeeTestCDC_CT'


--CLEANUP 

EXEC sys.sp_cdc_disable_table @source_schema = N'dbo', @source_name= N'EmployeeTestCDC', @capture_instance ='dbo_EmployeeTestCDC'
 
EXEC sys.sp_cdc_disable_db

DROP TABLE EmployeeTestCDC

\