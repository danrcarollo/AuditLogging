/**********************************
DEMO:  Auditing Changes with Temporal Tables
https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-tables?view=sql-server-ver16

************************************/

--Connect to your DB
USE [<<Your Database>>]
GO


--Create the base table and enable it for versioning
DROP TABLE IF EXISTS EmployeeTest
GO
CREATE TABLE dbo.EmployeeTest
(
  [EmployeeID] int NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
  , [Name] nvarchar(100) NOT NULL
  , [Position] varchar(100) NOT NULL
  , [Department] varchar(100) NOT NULL
  , [Address] nvarchar(1024) NOT NULL
  , [AnnualSalary] decimal (10,2) NOT NULL
  , [CreateDate] Datetime default(getdate())
  , [Modified] Datetime default(getdate())

  --required columns...
  , [ValidFrom] datetime2 GENERATED ALWAYS AS ROW START
  , [ValidTo] datetime2 GENERATED ALWAYS AS ROW END
  , PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
 )WITH (SYSTEM_VERSIONING = ON (

HISTORY_TABLE = dbo.EmployeeTestHistory,
HISTORY_RETENTION_PERIOD = 3 MONTHS
     )
);
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

--CREATE THE INSERT/UPDATE PROCS

CREATE OR ALTER PROC spAddEmployeeInfo_TemporalTable
@Name nvarchar(100), @position nvarchar(100) ,@Department nvarchar(100) ,
@Address nvarchar(1024) ,@AnnualSalary money
AS

INSERT INTO EmployeeTest (Name, Position, Department, Address, AnnualSalary)
SELECT @Name, @position,@Department ,@Address, @AnnualSalary

GO

CREATE OR ALTER PROC spUpdateEmployeeInfo_TemporalTable
@EmployeeID int, 
@position nvarchar(100)=NULL,
@Department nvarchar(100)=NULL,
@Address nvarchar(1024)=NULL ,
@AnnualSalary money=NULL
AS


UPDATE EmployeeTest
SET 
Department=ISNULL(@Department,Department),
Position=ISNULL(@position,Position),
Address=ISNULL(@Address,Address),
AnnualSalary=ISNULL(@AnnualSalary,AnnualSalary),
MOdified=getdate()

FROM EmployeeTest
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
		EXEC spAddEmployeeInfo_TemporalTable @FullName, @position, @Department, @LongString, @Salary

				SET @position=(SELECT TOP 1 Position from validPositions ORDER BY NEWID())
				SET @Department=(SELECT TOP 1 Department from validDepartments ORDER BY NEWID())

				SET @LongString=(
				SELECT REPLICATE(SUBSTRING(string_agg(value,'') WITHIN GROUP (ORDER BY NEWID()),1,abs(CHECKSUM(newid()))%1024),100)
				FROM string_split(@AlLChars,',')
				)

				SET @Salary=(SELECT abs(CHECKSUM(newid()))%1000000)

				SET @EmployeeID=(SELECT TOP 1 EmployeeID FROM EmployeeTest ORDER BY NEWID())

		--Update Position
		EXEC spUpdateEmployeeInfo_TemporalTable @EmployeeID,@position=@position

		--Update Department
		EXEC spUpdateEmployeeInfo_TemporalTable @EmployeeID,@Department=@Department

		--Update Salary
		EXEC spUpdateEmployeeInfo_TemporalTable @EmployeeID,@AnnualSalary=@Salary

		--Update Address
		EXEC spUpdateEmployeeInfo_TemporalTable @EmployeeID,@Address=@LongString

--END COPY


--Base Table
SELECT * FROM EmployeeTest

--History Table
ALTER TABLE EmployeeTestHistory REBUILD WITH (DATA_COMPRESSION=PAGE)

GO

SELECT * FROM EmployeeTestHistory

exec sp_spaceused EmployeeTestHistory


--State of Employee at previous re-org department change
---NOTE: BETWEEN is inclusive, so it will show TWO rows, since the SYSTEM_TIME will overlap two changes
SELECT * FROM EmployeeTest
  FOR SYSTEM_TIME
    BETWEEN '2023-03-30 23:10:10.5265971' AND '2023-03-30 23:10:47.6238468' 
      WHERE EmployeeID = 1 ORDER BY ValidFrom;


--CLEANUP
ALTER TABLE EmployeeTest SET (SYSTEM_VERSIONING = OFF)
DROP TABLE EmployeeTestHistory

DROP TABLE EmployeeTest
