
CREATE DATABASE UniversityEnrollmentSystem;
GO
USE UniversityEnrollmentSystem;
GO


IF OBJECT_ID('trg_AuditEnrollmentChanges',   'TR') IS NOT NULL DROP TRIGGER trg_AuditEnrollmentChanges;
IF OBJECT_ID('trg_UpdateSectionEnrollment',  'TR') IS NOT NULL DROP TRIGGER trg_UpdateSectionEnrollment;
GO

IF OBJECT_ID('vw_SectionAvailability', 'V') IS NOT NULL DROP VIEW vw_SectionAvailability;
IF OBJECT_ID('vw_FacultyWorkload',     'V') IS NOT NULL DROP VIEW vw_FacultyWorkload;
IF OBJECT_ID('vw_StudentTranscript',   'V') IS NOT NULL DROP VIEW vw_StudentTranscript;
GO
-- Drop tables (reverse dependency order)
IF OBJECT_ID('EnrollmentAudit', 'U') IS NOT NULL DROP TABLE EnrollmentAudit;
IF OBJECT_ID('Enrollment',      'U') IS NOT NULL DROP TABLE Enrollment;
IF OBJECT_ID('StudentPhone',    'U') IS NOT NULL DROP TABLE StudentPhone;
IF OBJECT_ID('CourseSection',   'U') IS NOT NULL DROP TABLE CourseSection;
IF OBJECT_ID('Student',         'U') IS NOT NULL DROP TABLE Student;
IF OBJECT_ID('Course',          'U') IS NOT NULL DROP TABLE Course;
IF OBJECT_ID('Semester',        'U') IS NOT NULL DROP TABLE Semester;
-- Resolve circular FK: Department.HeadFacultyID -> Faculty
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Dept_HeadFaculty')
    ALTER TABLE Department DROP CONSTRAINT FK_Dept_HeadFaculty;
IF OBJECT_ID('Faculty',         'U') IS NOT NULL DROP TABLE Faculty;
IF OBJECT_ID('Department',      'U') IS NOT NULL DROP TABLE Department;
IF OBJECT_ID('Person',          'U') IS NOT NULL DROP TABLE Person;
GO
PRINT '>> Cleanup complete.';
GO


CREATE TABLE Department (
    DeptID        INT            IDENTITY(1,1) PRIMARY KEY,
    DeptName      NVARCHAR(100)  NOT NULL UNIQUE,
    DeptCode      CHAR(6)        NOT NULL UNIQUE,
    Location      NVARCHAR(100)  NOT NULL,
    Budget        DECIMAL(14,2)  NOT NULL DEFAULT 0.00 CHECK (Budget >= 0),
    HeadFacultyID INT            NULL       -- FK added after Faculty table
);
GO

CREATE TABLE Person (
    PersonID    INT            IDENTITY(1,1) PRIMARY KEY,
    FirstName   NVARCHAR(50)   NOT NULL,
    LastName    NVARCHAR(50)   NOT NULL,
    DateOfBirth DATE           NOT NULL,
    Gender      CHAR(1)        NOT NULL CHECK (Gender IN ('M','F','O')),
    Email       NVARCHAR(100)  NOT NULL UNIQUE,
    
    Street      NVARCHAR(150)  NOT NULL,
    City        NVARCHAR(50)   NOT NULL,
    [State]     NVARCHAR(50)   NOT NULL,
    ZipCode     CHAR(10)       NOT NULL
);
GO

CREATE TABLE Faculty (
    FacultyID   INT            PRIMARY KEY,
    HireDate    DATE           NOT NULL,
    Salary      DECIMAL(12,2)  NOT NULL CHECK (Salary > 0),
    Rank        NVARCHAR(30)   NOT NULL
                CHECK (Rank IN ('Lecturer','Assistant Professor','Associate Professor','Professor')),
    DeptID      INT            NOT NULL,
    CONSTRAINT FK_Faculty_Person FOREIGN KEY (FacultyID) REFERENCES Person(PersonID) ON DELETE CASCADE,
    CONSTRAINT FK_Faculty_Dept   FOREIGN KEY (DeptID)    REFERENCES Department(DeptID)
);
GO

ALTER TABLE Department
    ADD CONSTRAINT FK_Dept_HeadFaculty
    FOREIGN KEY (HeadFacultyID) REFERENCES Faculty(FacultyID)
    ON DELETE SET NULL;
GO

CREATE TABLE Student (
    StudentID      INT            PRIMARY KEY,
    EnrollmentDate DATE           NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    CGPA           DECIMAL(4,2)   NOT NULL DEFAULT 0.00
                   CHECK (CGPA >= 0.00 AND CGPA <= 4.00),
    ProgramType    NVARCHAR(20)   NOT NULL
                   CHECK (ProgramType IN ('Undergraduate','Graduate')),
    AdvisorID      INT            NULL,
    CONSTRAINT FK_Student_Person  FOREIGN KEY (StudentID) REFERENCES Person(PersonID) ON DELETE CASCADE,
    CONSTRAINT FK_Student_Advisor FOREIGN KEY (AdvisorID) REFERENCES Faculty(FacultyID) ON DELETE SET NULL
);
GO

CREATE TABLE StudentPhone (
    PhoneID     INT            IDENTITY(1,1) PRIMARY KEY,
    StudentID   INT            NOT NULL,
    PhoneNumber NVARCHAR(20)   NOT NULL,
    PhoneType   NVARCHAR(10)   NOT NULL CHECK (PhoneType IN ('Mobile','Home','Work')),
    CONSTRAINT FK_Phone_Student FOREIGN KEY (StudentID) REFERENCES Student(StudentID) ON DELETE CASCADE,
    CONSTRAINT UQ_StudentPhone  UNIQUE (StudentID, PhoneNumber)
);
GO


CREATE TABLE Course (
    CourseID       INT            IDENTITY(1,1) PRIMARY KEY,
    CourseCode     NVARCHAR(10)   NOT NULL UNIQUE,
    CourseName     NVARCHAR(100)  NOT NULL,
    Credits        TINYINT        NOT NULL CHECK (Credits BETWEEN 1 AND 6),
    DeptID         INT            NOT NULL,
    PrereqCourseID INT            NULL,
    CONSTRAINT FK_Course_Dept   FOREIGN KEY (DeptID)         REFERENCES Department(DeptID),
    CONSTRAINT FK_Course_Prereq FOREIGN KEY (PrereqCourseID) REFERENCES Course(CourseID)
);
GO

CREATE TABLE Semester (
    SemesterID   INT            IDENTITY(1,1) PRIMARY KEY,
    SemesterName NVARCHAR(10)   NOT NULL CHECK (SemesterName IN ('Fall','Spring','Summer')),
    [Year]       SMALLINT       NOT NULL CHECK ([Year] BETWEEN 2000 AND 2100),
    StartDate    DATE           NOT NULL,
    EndDate      DATE           NOT NULL,
    CONSTRAINT UQ_Semester       UNIQUE (SemesterName, [Year]),
    CONSTRAINT CK_SemDates       CHECK  (EndDate > StartDate)
);
GO

CREATE TABLE CourseSection (
    SectionID         INT            IDENTITY(1,1) PRIMARY KEY,
    CourseID          INT            NOT NULL,
    SemesterID        INT            NOT NULL,
    FacultyID         INT            NOT NULL,
    Room              NVARCHAR(20)   NOT NULL,
    Schedule          NVARCHAR(60)   NOT NULL,
    MaxCapacity       TINYINT        NOT NULL CHECK (MaxCapacity > 0),
    CurrentEnrollment TINYINT        NOT NULL DEFAULT 0 CHECK (CurrentEnrollment >= 0),
    CONSTRAINT FK_Sec_Course    FOREIGN KEY (CourseID)   REFERENCES Course(CourseID),
    CONSTRAINT FK_Sec_Semester  FOREIGN KEY (SemesterID) REFERENCES Semester(SemesterID),
    CONSTRAINT FK_Sec_Faculty   FOREIGN KEY (FacultyID)  REFERENCES Faculty(FacultyID),
    CONSTRAINT UQ_Section       UNIQUE (CourseID, SemesterID, FacultyID, Room)
);
GO

CREATE TABLE Enrollment (
    EnrollmentID   INT            IDENTITY(1,1) PRIMARY KEY,
    StudentID      INT            NOT NULL,
    SectionID      INT            NOT NULL,
    EnrollmentDate DATE           NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    Grade          DECIMAL(4,2)   NULL CHECK (Grade BETWEEN 0.00 AND 4.00),
    Status         NVARCHAR(15)   NOT NULL
                   CHECK (Status IN ('Enrolled','Completed','Dropped','Withdrawn')),
    CONSTRAINT FK_Enroll_Student FOREIGN KEY (StudentID) REFERENCES Student(StudentID),
    CONSTRAINT FK_Enroll_Section FOREIGN KEY (SectionID) REFERENCES CourseSection(SectionID),
    CONSTRAINT UQ_Enrollment     UNIQUE (StudentID, SectionID)
);
GO

CREATE TABLE EnrollmentAudit (
    AuditID      INT            IDENTITY(1,1) PRIMARY KEY,
    EnrollmentID INT            NOT NULL,
    StudentID    INT            NOT NULL,
    SectionID    INT            NOT NULL,
    ActionType   NVARCHAR(10)   NOT NULL CHECK (ActionType IN ('INSERT','UPDATE','DELETE')),
    OldStatus    NVARCHAR(15)   NULL,
    NewStatus    NVARCHAR(15)   NULL,
    OldGrade     DECIMAL(4,2)   NULL,
    NewGrade     DECIMAL(4,2)   NULL,
    ChangedBy    NVARCHAR(128)  NOT NULL DEFAULT SYSTEM_USER,
    ChangedAt    DATETIME       NOT NULL DEFAULT GETDATE()
);
GO
PRINT '>> All tables created successfully.';
GO

CREATE TRIGGER trg_UpdateSectionEnrollment
ON Enrollment
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM   CourseSection cs
        INNER JOIN inserted i ON cs.SectionID = i.SectionID
        WHERE  i.Status = 'Enrolled'
        AND    NOT EXISTS (SELECT 1 FROM deleted d WHERE d.EnrollmentID = i.EnrollmentID)
        AND    cs.CurrentEnrollment >= cs.MaxCapacity
    )
    BEGIN
        RAISERROR ('Enrollment rejected: Section has reached maximum capacity.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    UPDATE cs
    SET    cs.CurrentEnrollment = cs.CurrentEnrollment + 1
    FROM   CourseSection cs
    INNER JOIN inserted i ON cs.SectionID = i.SectionID
    WHERE  i.Status = 'Enrolled'
    AND    NOT EXISTS (SELECT 1 FROM deleted d WHERE d.EnrollmentID = i.EnrollmentID);

    -- ===  PURE DELETE (rows in DELETED but not INSERTED)  ===
    UPDATE cs
    SET    cs.CurrentEnrollment = cs.CurrentEnrollment - 1
    FROM   CourseSection cs
    INNER JOIN deleted d ON cs.SectionID = d.SectionID
    WHERE  d.Status = 'Enrolled'
    AND    NOT EXISTS (SELECT 1 FROM inserted i WHERE i.EnrollmentID = d.EnrollmentID)
    AND    cs.CurrentEnrollment > 0;

    -- ===  UPDATE — status changed FROM 'Enrolled' TO other  ===
    UPDATE cs
    SET    cs.CurrentEnrollment = cs.CurrentEnrollment - 1
    FROM   CourseSection cs
    INNER JOIN deleted   d ON cs.SectionID  = d.SectionID
    INNER JOIN inserted  i ON i.EnrollmentID = d.EnrollmentID
    WHERE  d.Status = 'Enrolled' AND i.Status <> 'Enrolled'
    AND    cs.CurrentEnrollment > 0;

    -- ===  UPDATE — status changed FROM other TO 'Enrolled'  ===
    IF EXISTS (
        SELECT 1
        FROM   CourseSection cs
        INNER JOIN inserted  i ON cs.SectionID  = i.SectionID
        INNER JOIN deleted   d ON d.EnrollmentID = i.EnrollmentID
        WHERE  d.Status <> 'Enrolled' AND i.Status = 'Enrolled'
        AND    cs.CurrentEnrollment >= cs.MaxCapacity
    )
    BEGIN
        RAISERROR ('Re-enrollment rejected: Section has reached maximum capacity.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    UPDATE cs
    SET    cs.CurrentEnrollment = cs.CurrentEnrollment + 1
    FROM   CourseSection cs
    INNER JOIN inserted  i ON cs.SectionID  = i.SectionID
    INNER JOIN deleted   d ON d.EnrollmentID = i.EnrollmentID
    WHERE  d.Status <> 'Enrolled' AND i.Status = 'Enrolled';

END;
GO


CREATE TRIGGER trg_AuditEnrollmentChanges
ON Enrollment
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Log INSERTs
    INSERT INTO EnrollmentAudit (EnrollmentID, StudentID, SectionID, ActionType, OldStatus, NewStatus, OldGrade, NewGrade)
    SELECT i.EnrollmentID, i.StudentID, i.SectionID, 'INSERT', NULL, i.Status, NULL, i.Grade
    FROM   inserted i
    WHERE  NOT EXISTS (SELECT 1 FROM deleted d WHERE d.EnrollmentID = i.EnrollmentID);

    -- Log UPDATEs
    INSERT INTO EnrollmentAudit (EnrollmentID, StudentID, SectionID, ActionType, OldStatus, NewStatus, OldGrade, NewGrade)
    SELECT i.EnrollmentID, i.StudentID, i.SectionID, 'UPDATE', d.Status, i.Status, d.Grade, i.Grade
    FROM   inserted i
    INNER JOIN deleted d ON i.EnrollmentID = d.EnrollmentID;

    -- Log DELETEs
    INSERT INTO EnrollmentAudit (EnrollmentID, StudentID, SectionID, ActionType, OldStatus, NewStatus, OldGrade, NewGrade)
    SELECT d.EnrollmentID, d.StudentID, d.SectionID, 'DELETE', d.Status, NULL, d.Grade, NULL
    FROM   deleted d
    WHERE  NOT EXISTS (SELECT 1 FROM inserted i WHERE i.EnrollmentID = d.EnrollmentID);

END;
GO
PRINT '>> Triggers created successfully.';
GO


INSERT INTO Department (DeptName, DeptCode, Location, Budget) VALUES
('Computer Science',        'CS0001', 'Block A, Ground Floor',   15000000.00),
('Electrical Engineering',  'EE0001', 'Block B, First Floor',    18000000.00),
('Mathematics',             'MT0001', 'Block C, Second Floor',   10000000.00),
('Business Administration', 'BA0001', 'Block D, Ground Floor',   12000000.00),
('Software Engineering',    'SE0001', 'Block A, Second Floor',   14000000.00),
('Physics',                 'PH0001', 'Block C, Ground Floor',    9000000.00),
('Civil Engineering',       'CE0001', 'Block E, First Floor',    11000000.00),
('Mechanical Engineering',  'ME0001', 'Block E, Second Floor',   13000000.00),
('Artificial Intelligence', 'AI0001', 'Block F, Ground Floor',   16000000.00),
('Cyber Security',          'CY0001', 'Block F, First Floor',    14500000.00),
('Information Technology',  'IT0001', 'Block G, Ground Floor',   11500000.00),
('Data Science',            'DS0001', 'Block G, First Floor',    13500000.00),
('Chemical Engineering',    'CH0001', 'Block H, Ground Floor',   10500000.00),
('Economics',               'EC0001', 'Block D, First Floor',     8500000.00),
('English & Humanities',    'EN0001', 'Block D, Second Floor',    7000000.00);
GO


INSERT INTO Person (FirstName, LastName, DateOfBirth, Gender, Email, Street, City, [State], ZipCode) VALUES
('Ahmed',    'Ali',       '1975-03-12', 'M', 'ahmed.ali@nutech.edu.pk',      'House 15, Street 4, F-8/1',   'Islamabad', 'Islamabad Capital',  '44000'),
('Sana',     'Malik',     '1988-07-22', 'F', 'sana.malik@nutech.edu.pk',     'Flat 3B, I-8 Markaz',         'Islamabad', 'Islamabad Capital',  '44000'),
('Tariq',    'Hassan',    '1971-11-05', 'M', 'tariq.hassan@nutech.edu.pk',   'House 22, G-10/2',            'Islamabad', 'Islamabad Capital',  '44000'),
('Usman',    'Khan',      '1985-04-18', 'M', 'usman.khan@nutech.edu.pk',     'House 7, E-7',                'Islamabad', 'Islamabad Capital',  '44000'),
('Nadia',    'Hussain',   '1969-09-30', 'F', 'nadia.hussain@nutech.edu.pk',  'House 45, DHA Phase 2',       'Islamabad', 'Islamabad Capital',  '44000'),
('Ayesha',   'Raza',      '1991-02-14', 'F', 'ayesha.raza@nutech.edu.pk',    'Flat 12, Blue Area',          'Islamabad', 'Islamabad Capital',  '44000'),
('Bilal',    'Chaudhry',  '1980-06-25', 'M', 'bilal.chaudhry@nutech.edu.pk', 'House 33, F-6/3',             'Islamabad', 'Islamabad Capital',  '44000'),
('Zain',     'Ahmed',     '1990-01-08', 'M', 'zain.ahmed@nutech.edu.pk',     'House 19, G-9/1',             'Islamabad', 'Islamabad Capital',  '44000'),
('Fatima',   'Iqbal',     '1968-12-01', 'F', 'fatima.iqbal@nutech.edu.pk',   'House 5, F-10/1',             'Islamabad', 'Islamabad Capital',  '44000'),
('Hina',     'Shahid',    '1993-08-17', 'F', 'hina.shahid@nutech.edu.pk',    'Apartment 8B, G-11',          'Islamabad', 'Islamabad Capital',  '44000'),
('Imran',    'Butt',      '1978-05-20', 'M', 'imran.butt@nutech.edu.pk',     'House 11, H-12',              'Islamabad', 'Islamabad Capital',  '44000'),
('Rabia',    'Sheikh',    '1983-03-09', 'F', 'rabia.sheikh@nutech.edu.pk',   'Street 6, G-7/2',             'Islamabad', 'Islamabad Capital',  '44000'),
('Adnan',    'Mirza',     '1976-10-14', 'M', 'adnan.mirza@nutech.edu.pk',    'House 8, F-11/2',             'Islamabad', 'Islamabad Capital',  '44000'),
('Saima',    'Javed',     '1987-07-03', 'F', 'saima.javed@nutech.edu.pk',    'House 27, I-9/4',             'Islamabad', 'Islamabad Capital',  '44000'),
('Khalid',   'Qureshi',   '1973-12-28', 'M', 'khalid.qureshi@nutech.edu.pk', 'House 3, E-8/3',              'Islamabad', 'Islamabad Capital',  '44000'),
-- Students (PersonID 16-30)
('Muhammad', 'Raza',      '2002-05-15', 'M', 'muhammad.raza@student.nutech.edu.pk',    'House 8, G-8/4',        'Islamabad', 'Islamabad Capital',  '44000'),
('Sara',     'Khan',      '2003-01-22', 'F', 'sara.khan@student.nutech.edu.pk',        'House 22, F-7/2',       'Islamabad', 'Islamabad Capital',  '44000'),
('Ali',      'Hassan',    '2001-11-30', 'M', 'ali.hassan@student.nutech.edu.pk',       'Sector I-9, House 14',  'Islamabad', 'Islamabad Capital',  '44000'),
('Zara',     'Malik',     '2004-03-10', 'F', 'zara.malik@student.nutech.edu.pk',       'Street 7, G-7/3',       'Islamabad', 'Islamabad Capital',  '44000'),
('Omar',     'Sheikh',    '2002-08-05', 'M', 'omar.sheikh@student.nutech.edu.pk',      'House 30, H-10',        'Islamabad', 'Islamabad Capital',  '44000'),
('Maryam',   'Siddiqui',  '2003-12-18', 'F', 'maryam.siddiqui@student.nutech.edu.pk', 'Flat 4A, E-11',         'Islamabad', 'Islamabad Capital',  '44000'),
('Hassan',   'Tariq',     '2001-06-27', 'M', 'hassan.tariq@student.nutech.edu.pk',    'House 5, F-8/3',        'Islamabad', 'Islamabad Capital',  '44000'),
('Aisha',    'Nawaz',     '2004-02-14', 'F', 'aisha.nawaz@student.nutech.edu.pk',     'Street 2, G-10/3',      'Islamabad', 'Islamabad Capital',  '44000'),
('Bilal',    'Akhtar',    '2002-09-03', 'M', 'bilal.akhtar@student.nutech.edu.pk',    'House 11, H-8',         'Islamabad', 'Islamabad Capital',  '44000'),
('Fatima',   'Riaz',      '2003-07-20', 'F', 'fatima.riaz@student.nutech.edu.pk',     'House 26, G-6/4',       'Islamabad', 'Islamabad Capital',  '44000'),
('Kamran',   'Butt',      '2001-04-12', 'M', 'kamran.butt@student.nutech.edu.pk',     'Sector F-9, Block 3',   'Islamabad', 'Islamabad Capital',  '44000'),
('Hira',     'Javed',     '2004-10-08', 'F', 'hira.javed@student.nutech.edu.pk',      'House 17, I-8/2',       'Islamabad', 'Islamabad Capital',  '44000'),
('Asad',     'Anwar',     '2002-03-25', 'M', 'asad.anwar@student.nutech.edu.pk',      'Street 9, F-10/3',      'Islamabad', 'Islamabad Capital',  '44000'),
('Noor',     'Ahmed',     '2003-11-14', 'F', 'noor.ahmed@student.nutech.edu.pk',      'House 38, G-13',        'Islamabad', 'Islamabad Capital',  '44000'),
('Talha',    'Mehmood',   '2001-07-01', 'M', 'talha.mehmood@student.nutech.edu.pk',   'House 6, E-7/3',        'Islamabad', 'Islamabad Capital',  '44000');
GO


INSERT INTO Faculty (FacultyID, HireDate, Salary, Rank, DeptID) VALUES
(1,  '2005-08-15', 250000.00, 'Professor',              1),
(2,  '2015-01-10', 120000.00, 'Lecturer',               1),
(3,  '2000-03-22', 220000.00, 'Associate Professor',    2),
(4,  '2012-07-01', 150000.00, 'Assistant Professor',    3),
(5,  '1998-09-05', 280000.00, 'Professor',              4),
(6,  '2018-02-20', 110000.00, 'Lecturer',               6),
(7,  '2008-11-14', 190000.00, 'Associate Professor',    5),
(8,  '2016-04-30', 140000.00, 'Assistant Professor',    1),
(9,  '1995-06-12', 290000.00, 'Professor',              3),
(10, '2020-08-01', 105000.00, 'Lecturer',               5),
(11, '2010-03-17', 175000.00, 'Assistant Professor',    9),
(12, '2014-09-22', 160000.00, 'Assistant Professor',   10),
(13, '2007-01-30', 200000.00, 'Associate Professor',   11),
(14, '2019-06-15', 130000.00, 'Lecturer',              12),
(15, '2003-08-20', 240000.00, 'Professor',              7);
GO

-- Update Department heads (after Faculty table is populated)
UPDATE Department SET HeadFacultyID =  1 WHERE DeptID =  1;
UPDATE Department SET HeadFacultyID =  3 WHERE DeptID =  2;
UPDATE Department SET HeadFacultyID =  9 WHERE DeptID =  3;
UPDATE Department SET HeadFacultyID =  5 WHERE DeptID =  4;
UPDATE Department SET HeadFacultyID =  7 WHERE DeptID =  5;
UPDATE Department SET HeadFacultyID =  6 WHERE DeptID =  6;
UPDATE Department SET HeadFacultyID = 15 WHERE DeptID =  7;
UPDATE Department SET HeadFacultyID = NULL WHERE DeptID = 8;
UPDATE Department SET HeadFacultyID = 11 WHERE DeptID =  9;
UPDATE Department SET HeadFacultyID = 12 WHERE DeptID = 10;
UPDATE Department SET HeadFacultyID = 13 WHERE DeptID = 11;
UPDATE Department SET HeadFacultyID = 14 WHERE DeptID = 12;
GO


INSERT INTO Student (StudentID, EnrollmentDate, CGPA, ProgramType, AdvisorID) VALUES
(16, '2022-09-01', 3.45, 'Undergraduate',  1),
(17, '2023-02-01', 3.78, 'Undergraduate',  2),
(18, '2021-09-01', 3.20, 'Undergraduate',  8),
(19, '2023-09-01', 3.90, 'Graduate',       1),
(20, '2022-02-01', 2.95, 'Undergraduate',  7),
(21, '2023-09-01', 3.55, 'Undergraduate',  7),
(22, '2021-02-01', 3.10, 'Undergraduate',  8),
(23, '2024-02-01', 0.00, 'Undergraduate',  2),
(24, '2022-09-01', 3.30, 'Graduate',       9),
(25, '2023-02-01', 3.65, 'Undergraduate',  4),
(26, '2021-09-01', 2.80, 'Undergraduate',  9),
(27, '2024-02-01', 0.00, 'Undergraduate',  2),
(28, '2022-09-01', 3.50, 'Graduate',      11),
(29, '2023-09-01', 3.72, 'Undergraduate',  7),
(30, '2021-02-01', 3.15, 'Undergraduate',  8);
GO


INSERT INTO StudentPhone (StudentID, PhoneNumber, PhoneType) VALUES
(16, '0300-1234567', 'Mobile'),
(16, '051-2345678',  'Home'),
(17, '0311-2345678', 'Mobile'),
(18, '0321-3456789', 'Mobile'),
(18, '051-3456789',  'Home'),
(19, '0333-4567890', 'Mobile'),
(20, '0345-5678901', 'Mobile'),
(20, '051-5678901',  'Home'),
(21, '0301-6789012', 'Mobile'),
(22, '0312-7890123', 'Mobile'),
(23, '0322-8901234', 'Mobile'),
(24, '0334-9012345', 'Mobile'),
(24, '0423-9012345', 'Work'),
(25, '0346-0123456', 'Mobile'),
(26, '0302-1234560', 'Mobile'),
(27, '0313-3456780', 'Mobile'),
(28, '0323-4567890', 'Mobile'),
(29, '0335-5678900', 'Mobile'),
(30, '0347-6789000', 'Mobile'),
(30, '051-7890000',  'Home');
GO

INSERT INTO Course (CourseCode, CourseName, Credits, DeptID, PrereqCourseID) VALUES
('CS101',  'Introduction to Programming',    3, 1,  NULL),
('CS201',  'Data Structures & Algorithms',   3, 1,  1),
('CS301',  'Database Systems',               3, 1,  2),
('CS401',  'Operating Systems',              3, 1,  2),
('CS501',  'Computer Networks',              3, 1,  4),
('CS202',  'Object-Oriented Programming',    3, 1,  1),
('MT101',  'Calculus I',                     3, 3,  NULL),
('MT201',  'Linear Algebra',                 3, 3,  7),
('MT301',  'Differential Equations',         3, 3,  7),
('EE101',  'Circuit Analysis',               3, 2,  NULL),
('EE201',  'Digital Electronics',            3, 2,  10),
('BA101',  'Principles of Management',       3, 4,  NULL),
('BA201',  'Financial Accounting',           3, 4,  12),
('SE101',  'Software Engineering Intro',     3, 5,  1),
('SE201',  'Software Design Patterns',       3, 5,  14);
GO

INSERT INTO Semester (SemesterName, [Year], StartDate, EndDate) VALUES
('Fall',   2019, '2019-09-02', '2020-01-24'),
('Spring', 2020, '2020-02-03', '2020-06-19'),
('Summer', 2020, '2020-07-06', '2020-08-28'),
('Fall',   2020, '2020-09-07', '2021-01-22'),
('Spring', 2021, '2021-02-01', '2021-06-18'),
('Summer', 2021, '2021-07-05', '2021-08-27'),
('Fall',   2021, '2021-09-06', '2022-01-21'),
('Spring', 2022, '2022-02-07', '2022-06-17'),
('Summer', 2022, '2022-07-04', '2022-08-26'),
('Fall',   2022, '2022-09-05', '2023-01-20'),
('Spring', 2023, '2023-02-06', '2023-06-16'),
('Summer', 2023, '2023-07-03', '2023-08-25'),
('Fall',   2023, '2023-09-04', '2024-01-19'),
('Spring', 2024, '2024-02-05', '2024-06-14'),
('Spring', 2025, '2025-02-03', '2025-06-20');
GO


INSERT INTO CourseSection (CourseID, SemesterID, FacultyID, Room, Schedule, MaxCapacity) VALUES
(1,   4,  1, 'A-101', 'Mon/Wed 08:00-09:30',  30),
(7,   4,  4, 'C-201', 'Tue/Thu 08:00-09:30',  35),
(1,   5,  2, 'A-102', 'Mon/Wed 09:45-11:15',  30),
(10,  5,  3, 'B-101', 'Tue/Thu 09:45-11:15',  30),
(2,   7,  1, 'A-101', 'Mon/Wed 08:00-09:30',  30),
(6,   7,  8, 'A-103', 'Tue/Thu 08:00-09:30',  35),
(8,   8,  9, 'C-202', 'Mon/Wed 11:30-13:00',  30),
(12,  8,  5, 'D-101', 'Tue/Thu 11:30-13:00',  40),
(3,  10,  1, 'A-101', 'Mon/Wed 08:00-09:30',  25),
(4,  10,  2, 'A-102', 'Tue/Thu 08:00-09:30',  30),
(11, 11,  3, 'B-102', 'Mon/Wed 09:45-11:15',  30),
(14, 11,  7, 'A-201', 'Tue/Thu 09:45-11:15',  25),
(5,  13, 15, 'A-103', 'Mon/Wed 08:00-09:30',  25),
(9,  13,  4, 'C-203', 'Tue/Thu 08:00-09:30',  30),
(13, 14,  5, 'D-102', 'Mon/Wed 09:45-11:15',  35),
(15, 14,  7, 'A-201', 'Tue/Thu 09:45-11:15',  25),
(1,  15,  8, 'A-104', 'Mon/Wed 08:00-09:30',  35),
(3,  15,  1, 'A-101', 'Tue/Thu 08:00-09:30',  25),
(8,  15,  9, 'C-201', 'Mon/Wed 11:30-13:00',  30),
(10, 15,  3, 'B-101', 'Tue/Thu 11:30-13:00',  30);
GO


INSERT INTO Enrollment (StudentID, SectionID, EnrollmentDate, Grade, Status) VALUES
(16,  1, '2020-09-07', 3.40, 'Completed'),
(17,  1, '2020-09-07', 3.65, 'Completed'),
(18,  2, '2020-09-07', 3.80, 'Completed'),
(16,  3, '2021-02-01', 3.25, 'Completed'),
(17,  3, '2021-02-01', 3.50, 'Completed'),
(18,  4, '2021-02-01', 3.20, 'Completed'),
(19,  5, '2021-09-06', 3.70, 'Completed'),
(20,  6, '2021-09-06', 3.60, 'Completed'),
(24,  7, '2022-02-07', 3.90, 'Completed'),
(25,  8, '2022-02-07', 2.75, 'Completed'),
(16,  9, '2023-02-06', 3.00, 'Completed'),
(17, 10, '2023-02-06', 3.45, 'Completed'),
(26, 11, '2023-02-06', 3.15, 'Completed'),
(28, 12, '2023-02-06', 3.75, 'Completed'),
(20, 13, '2024-02-05', NULL, 'Dropped'),
(30, 14, '2024-02-05', 3.35, 'Completed'),
-- Current semester (Spring 2025) — Status = 'Enrolled', no grade yet
(16, 18, '2025-02-03', NULL, 'Enrolled'),
(17, 17, '2025-02-03', NULL, 'Enrolled'),
(19, 18, '2025-02-03', NULL, 'Enrolled'),
(29, 19, '2025-02-03', NULL, 'Enrolled');
GO


UPDATE Enrollment SET Status = 'Withdrawn' WHERE StudentID = 17 AND SectionID = 17;
GO
-- Re-enroll Sara Khan into a different section for Spring 2025
INSERT INTO Enrollment (StudentID, SectionID, EnrollmentDate, Grade, Status)
VALUES (17, 20, '2025-02-10', NULL, 'Enrolled');
GO

PRINT '>> All data populated. Triggers fired and audit log updated.';
GO


CREATE VIEW vw_StudentTranscript AS
SELECT
    st.StudentID,
    p.FirstName + ' ' + p.LastName          AS StudentName,
    p.Email                                  AS StudentEmail,
    st.ProgramType,
    st.CGPA,
    c.CourseCode,
    c.CourseName,
    c.Credits,
    sm.SemesterName + ' ' + CAST(sm.[Year] AS NVARCHAR(4)) AS AcademicTerm,
    cs.Room,
    cs.Schedule,
    fp.FirstName + ' ' + fp.LastName        AS InstructorName,
    f.Rank                                   AS InstructorRank,
    e.Grade,
    e.Status                                 AS EnrollmentStatus,
    e.EnrollmentDate
FROM Enrollment e
INNER JOIN Student       st ON e.StudentID   = st.StudentID
INNER JOIN Person         p ON st.StudentID  = p.PersonID
INNER JOIN CourseSection cs ON e.SectionID   = cs.SectionID
INNER JOIN Course         c ON cs.CourseID   = c.CourseID
INNER JOIN Semester      sm ON cs.SemesterID = sm.SemesterID
INNER JOIN Faculty        f ON cs.FacultyID  = f.FacultyID
INNER JOIN Person        fp ON f.FacultyID   = fp.PersonID;
GO


CREATE VIEW vw_FacultyWorkload AS
SELECT
    f.FacultyID,
    p.FirstName + ' ' + p.LastName                AS FacultyName,
    f.Rank,
    d.DeptName,
    f.Salary,
    COUNT(cs.SectionID)                            AS TotalSections,
    SUM(cs.CurrentEnrollment)                      AS TotalStudentsTeaching,
    AVG(CAST(cs.CurrentEnrollment AS DECIMAL(5,2))) AS AvgEnrollmentPerSection
FROM Faculty f
INNER JOIN Person        p ON f.FacultyID = p.PersonID
INNER JOIN Department    d ON f.DeptID    = d.DeptID
LEFT  JOIN CourseSection cs ON f.FacultyID = cs.FacultyID
GROUP BY f.FacultyID, p.FirstName, p.LastName, f.Rank, d.DeptName, f.Salary;
GO

CREATE VIEW vw_SectionAvailability AS
SELECT
    cs.SectionID,
    c.CourseCode,
    c.CourseName,
    c.Credits,
    d.DeptName,
    sm.SemesterName + ' ' + CAST(sm.[Year] AS NVARCHAR(4)) AS AcademicTerm,
    sm.[Year]                                               AS [Year],
    cs.Room,
    cs.Schedule,
    fp.FirstName + ' ' + fp.LastName                       AS InstructorName,
    cs.MaxCapacity,
    cs.CurrentEnrollment,
    cs.MaxCapacity - cs.CurrentEnrollment                  AS AvailableSeats
FROM CourseSection cs
INNER JOIN Course     c ON cs.CourseID   = c.CourseID
INNER JOIN Department d ON c.DeptID      = d.DeptID
INNER JOIN Semester  sm ON cs.SemesterID = sm.SemesterID
INNER JOIN Faculty    f ON cs.FacultyID  = f.FacultyID
INNER JOIN Person    fp ON f.FacultyID   = fp.PersonID;
GO
PRINT '>> Views created successfully.';
GO


SELECT
    p.FirstName + ' ' + p.LastName                        AS StudentName,
    st.ProgramType,
    c.CourseCode,
    c.CourseName,
    c.Credits,
    sm.SemesterName + ' ' + CAST(sm.[Year] AS NVARCHAR(4)) AS AcademicTerm,
    cs.Room,
    cs.Schedule,
    fp.FirstName + ' ' + fp.LastName                      AS InstructorName,
    f.Rank                                                 AS InstructorRank,
    d.DeptName                                             AS Department,
    e.Grade,
    e.Status
FROM Enrollment e
INNER JOIN Student       st ON e.StudentID   = st.StudentID
INNER JOIN Person         p ON st.StudentID  = p.PersonID
INNER JOIN CourseSection cs ON e.SectionID   = cs.SectionID
INNER JOIN Course         c ON cs.CourseID   = c.CourseID
INNER JOIN Semester      sm ON cs.SemesterID = sm.SemesterID
INNER JOIN Faculty        f ON cs.FacultyID  = f.FacultyID
INNER JOIN Person        fp ON f.FacultyID   = fp.PersonID
INNER JOIN Department     d ON c.DeptID      = d.DeptID
ORDER BY p.LastName, sm.[Year], sm.SemesterName;
GO


SELECT
    fp.FirstName + ' ' + fp.LastName                       AS FacultyName,
    f.Rank,
    d.DeptName,
    c.CourseCode,
    c.CourseName,
    sm.SemesterName + ' ' + CAST(sm.[Year] AS NVARCHAR(4)) AS AcademicTerm,
    cs.Room,
    cs.Schedule,
    cs.CurrentEnrollment,
    cs.MaxCapacity,
    (cs.MaxCapacity - cs.CurrentEnrollment)                AS AvailableSeats
FROM CourseSection cs
INNER JOIN Faculty    f ON cs.FacultyID  = f.FacultyID
INNER JOIN Person    fp ON f.FacultyID   = fp.PersonID
INNER JOIN Department d ON f.DeptID      = d.DeptID
INNER JOIN Course     c ON cs.CourseID   = c.CourseID
INNER JOIN Semester  sm ON cs.SemesterID = sm.SemesterID
ORDER BY fp.LastName, sm.[Year] DESC, sm.SemesterName;
GO


SELECT
    d.DeptName,
    c.CourseCode                 AS CourseCode,
    c.CourseName                 AS CourseName,
    c.Credits                    AS Credits,
    prereq.CourseCode            AS PrerequisiteCode,
    prereq.CourseName            AS PrerequisiteName
FROM Course c
INNER JOIN Department d     ON c.DeptID      = d.DeptID
LEFT  JOIN Course prereq    ON c.PrereqCourseID = prereq.CourseID
ORDER BY d.DeptName, c.CourseCode;
GO


SELECT
    c.CourseCode,
    c.CourseName,
    sm.SemesterName + ' ' + CAST(sm.[Year] AS NVARCHAR(4)) AS AcademicTerm,
    COUNT(e.EnrollmentID)         AS TotalEnrollments,
    SUM(c.Credits)                AS TotalCreditHours,
    ROUND(AVG(e.Grade), 2)        AS AverageGrade,
    MAX(e.Grade)                  AS HighestGrade,
    MIN(e.Grade)                  AS LowestGrade
FROM Enrollment e
INNER JOIN CourseSection cs ON e.SectionID   = cs.SectionID
INNER JOIN Course         c ON cs.CourseID   = c.CourseID
INNER JOIN Semester      sm ON cs.SemesterID = sm.SemesterID
WHERE e.Status = 'Completed'
GROUP BY c.CourseCode, c.CourseName, sm.SemesterName, sm.[Year]
HAVING COUNT(e.EnrollmentID) >= 1
ORDER BY sm.[Year] DESC, c.CourseCode;
GO


SELECT
    d.DeptName,
    d.DeptCode,
    d.Budget,
    COUNT(DISTINCT f.FacultyID)     AS FacultyCount,
    COUNT(DISTINCT c.CourseID)      AS CoursesOffered,
    SUM(f.Salary)                   AS TotalSalaryBill,
    ROUND(AVG(f.Salary), 2)         AS AvgFacultySalary,
    MAX(f.Salary)                   AS MaxSalary,
    MIN(f.Salary)                   AS MinSalary
FROM Department d
LEFT JOIN Faculty f ON d.DeptID = f.DeptID
LEFT JOIN Course  c ON d.DeptID = c.DeptID
GROUP BY d.DeptName, d.DeptCode, d.Budget
HAVING COUNT(DISTINCT f.FacultyID) > 0
ORDER BY TotalSalaryBill DESC;
GO


SELECT
    st.ProgramType,
    COUNT(DISTINCT st.StudentID)    AS TotalStudents,
    COUNT(e.EnrollmentID)           AS TotalEnrollments,
    SUM(CASE WHEN e.Status = 'Enrolled'   THEN 1 ELSE 0 END) AS ActiveEnrollments,
    SUM(CASE WHEN e.Status = 'Completed'  THEN 1 ELSE 0 END) AS CompletedEnrollments,
    SUM(CASE WHEN e.Status = 'Dropped'    THEN 1 ELSE 0 END) AS DroppedEnrollments,
    ROUND(AVG(st.CGPA), 2)          AS AverageCGPA,
    MAX(st.CGPA)                    AS HighestCGPA,
    MIN(CASE WHEN st.CGPA > 0 THEN st.CGPA ELSE NULL END) AS LowestCGPA
FROM Student st
LEFT JOIN Enrollment e ON st.StudentID = e.StudentID
GROUP BY st.ProgramType
ORDER BY st.ProgramType;
GO

SELECT
    p.FirstName + ' ' + p.LastName   AS StudentName,
    st.ProgramType,
    st.CGPA,
    (SELECT COUNT(*)
     FROM   Enrollment e2
     WHERE  e2.StudentID = st.StudentID
     AND    e2.Status    = 'Enrolled') AS ActiveCourses
FROM Student st
INNER JOIN Person p ON st.StudentID = p.PersonID
WHERE (
    SELECT COUNT(*)
    FROM   Enrollment e
    WHERE  e.StudentID = st.StudentID
    AND    e.Status    = 'Enrolled'
) > (
    SELECT AVG(CAST(EnrollCount AS DECIMAL))
    FROM  (
        SELECT COUNT(*) AS EnrollCount
        FROM   Enrollment
        WHERE  Status = 'Enrolled'
        GROUP  BY StudentID
    ) AS SubEnroll
)
ORDER BY ActiveCourses DESC;
GO


SELECT
    c.CourseCode,
    c.CourseName,
    c.Credits,
    d.DeptName
FROM Course c
INNER JOIN Department d ON c.DeptID = d.DeptID
WHERE c.CourseID IN (
    SELECT cs.CourseID
    FROM   CourseSection cs
    INNER JOIN Enrollment e ON cs.SectionID = e.SectionID
    WHERE  e.Grade >= 3.70
)
ORDER BY d.DeptName, c.CourseCode;
GO


SELECT
    p.FirstName + ' ' + p.LastName  AS StudentName,
    st.ProgramType,
    st.CGPA,
    st.EnrollmentDate
FROM Student st
INNER JOIN Person p ON st.StudentID = p.PersonID
WHERE EXISTS (
    SELECT 1
    FROM   Enrollment e
    WHERE  e.StudentID = st.StudentID
    AND    e.Status    = 'Completed'
)
ORDER BY st.CGPA DESC;
GO


SELECT
    cs.SectionID,
    c.CourseCode,
    c.CourseName,
    sm.SemesterName + ' ' + CAST(sm.[Year] AS NVARCHAR(4)) AS AcademicTerm,
    cs.CurrentEnrollment,
    cs.MaxCapacity
FROM CourseSection cs
INNER JOIN Course   c ON cs.CourseID   = c.CourseID
INNER JOIN Semester sm ON cs.SemesterID = sm.SemesterID
WHERE cs.CurrentEnrollment > ANY (
    SELECT AVG(CAST(CurrentEnrollment AS DECIMAL))
    FROM   CourseSection
    WHERE  CurrentEnrollment > 0
    GROUP  BY SemesterID
)
ORDER BY cs.CurrentEnrollment DESC;
GO

SELECT * FROM EnrollmentAudit ORDER BY ChangedAt;
GO
SELECT SectionID, CourseID, CurrentEnrollment, MaxCapacity
FROM   CourseSection
WHERE  CurrentEnrollment > 0
ORDER  BY SectionID;
GO

PRINT '>> All queries, views, and triggers demonstrated successfully.';
GO
