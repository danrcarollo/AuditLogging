/************************************************
DEMO:  Auditing Changes with manual INSERT/OUTPUT logic to separate *AUditLog table

***********************************************/

USE [<<Your Database>>]
GO

CREATE TABLE dbo.EmployeeTestNormal
(
  [EmployeeID] int NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
  , [Name] nvarchar(100) NOT NULL
  , [Position] nvarchar(100) NOT NULL
  , [Department] nvarchar(100) NOT NULL
  , [Address] nvarchar(1024) NOT NULL
  , [AnnualSalary] decimal (10,2) NOT NULL
  , [CreateDate] Datetime default(getdate())
  , [Modified] Datetime default(getdate())
 )
GO
CREATE INDEX IDX_EmployeeTestNormal_NAME ON EmployeeTestNormal (NAME)
GO
GO
 CREATE TABLE dbo.EmployeeTestNormalAuditLog
(
  [EmployeeID] int NOT NULL 
  , [Name] nvarchar(100)  NULL
  , [Position] nvarchar(100)  NULL
  , [Department] nvarchar(100)  NULL
  , [Address] nvarchar(1024)  NULL
  , [AnnualSalary] decimal (10,2)  NULL
  , [CreateDate] Datetime default(getdate())
  , [Modified] Datetime default(getdate())
 )
 GO
CREATE INDEX IDX_EmployeeTestNormalAuditLog_NAME ON EmployeeTestNormalAuditLog (NAME)
GO
CREATE INDEX IDX_EmployeeTestNormalAuditLog_CreateDate ON EmployeeTestNormalAuditLog (CreateDate)
GO
ALTER TABLE EmployeeTestNormalAuditLog REBUILD WITH (DATA_COMPRESSION=PAGE)
GO


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
CREATE OR ALTER PROC spAddEmployeeInfo_AuditLog 
@Name nvarchar(100), @position nvarchar(100) ,@Department nvarchar(100) ,
@Address nvarchar(1024) ,@AnnualSalary money
AS

DECLARE  @CurrentIdentity INT
SET @CurrentIdentity=IDENT_CURRENT('EmployeeTestNormal')

INSERT INTO EmployeeTestNormal
(Name,[Position],Department,Address,AnnualSalary)
OUTPUT
@CurrentIdentity,inserted.Name,inserted.[Position],inserted.Department,inserted.Address,inserted.AnnualSalary
,inserted.CreateDate,inserted.Modified
INTO EmployeeTestNormalAuditLog
SELECT @Name, @position,@Department ,@Address, @AnnualSalary

GO

CREATE OR ALTER PROC spUpdateEmployeeInfo_AuditLog 
@EmployeeID int, 
@position nvarchar(100)=NULL,
@Department nvarchar(100)=NULL,
@Address nvarchar(1024)=NULL ,
@AnnualSalary money=NULL
AS


UPDATE EmployeeTestNormal
SET 
Department=ISNULL(@Department,Department),
Position=ISNULL(@position,Position),
Address=ISNULL(@Address,Address),
AnnualSalary=ISNULL(@AnnualSalary,AnnualSalary),
MOdified=getdate()
OUTPUT 
Inserted.EmployeeID,
Inserted.Name,
Inserted.Position,
Inserted.Department,
Inserted.Address,
Inserted.AnnualSalary,
getdate()
INTO dbo.EmployeeTestNormalAuditLog (
	[EmployeeID],
	Name,
	Position,
	Department,
	Address,
	AnnualSalary,
	[Modified]
)
FROM EmployeeTestNormal
where EmployeeID=@EmployeeID
GO


--RUN TEST.  COPY/PASTE THE CODE BELOW INTO SEPARATE WINDOW OR STRESS TEST TOOL OF YOUR CHOICE
--BEGIN COPY...

		--RUN TEST: AuditLog Table Method
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
		EXEC spAddEmployeeInfo_AuditLog @FullName, @position, @Department, @LongString, @Salary


				SET @position=(SELECT TOP 1 Position from validPositions ORDER BY NEWID())
				SET @Department=(SELECT TOP 1 Department from validDepartments ORDER BY NEWID())

				SET @LongString=(
				SELECT REPLICATE(SUBSTRING(string_agg(value,'') WITHIN GROUP (ORDER BY NEWID()),1,abs(CHECKSUM(newid()))%1024),100)
				FROM string_split(@AlLChars,',')
				)

				SET @Salary=(SELECT abs(CHECKSUM(newid()))%1000000)

				SET @EmployeeID=(SELECT TOP 1 EmployeeID FROM EmployeeTestNormal ORDER BY NEWID())

		--Update Position
		EXEC spUpdateEmployeeInfo_AuditLog @EmployeeID,@position=@position

		--Update Department
		EXEC spUpdateEmployeeInfo_AuditLog @EmployeeID,@Department=@Department

		--Update Salary
		EXEC spUpdateEmployeeInfo_AuditLog @EmployeeID,@AnnualSalary=@Salary

		--Update Address
		EXEC spUpdateEmployeeInfo_AuditLog @EmployeeID,@Address=@LongString




--END COPY


--SEE THE RESULTS:

SELECT * FROM dbo.EmployeeTestNormal
SELECT * FROM dbo.EmployeeTestNormalAuditLog



exec sp_spaceused EmployeeTestNormalAuditLog

--CLEANUP
 DROP TABLE IF EXISTS   dbo.EmployeeTestNormalAuditLog
 DROP TABLE IF EXISTS   dbo.EmployeeTestNormal
 DROP TABLE IF EXISTS   dbo.validPositions
 DROP TABLE IF EXISTS	dbo.validDepartments