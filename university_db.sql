-- ============================================================
--  NATIONAL UNIVERSITY OF TECHNOLOGY
--  University Management System — SSMS Script
--  Run this entire file once in SSMS (F5 / Execute)
-- ============================================================

CREATE DATABASE UNIVERSITY
GO

USE UNIVERSITY
GO

-- ============================================================
--  SEQUENCE OBJECT — Used to auto-generate StudentID
--  Starts at 0 so first StudentID = F25605300 + 0 = F25605300
-- ============================================================

CREATE SEQUENCE StudentIDSeq
    AS INT
    START WITH 0
    INCREMENT BY 1
GO

-- ============================================================
--  TABLE: NEWADMISSION
--  StudentID is generated automatically starting from F25605300
-- ============================================================

CREATE TABLE NEWADMISSION (
    StudentID        VARCHAR(20)  NOT NULL PRIMARY KEY,
    Name             VARCHAR(100) NOT NULL,
    FatherName       VARCHAR(100) NOT NULL,
    CNIC             VARCHAR(20)  NOT NULL,
    DateOfBirth      DATE         NOT NULL,
    Gender           VARCHAR(10)  NOT NULL,
    Email            VARCHAR(100) NOT NULL,
    Phone            VARCHAR(20)  NOT NULL,
    Program          VARCHAR(100) NOT NULL,
    Department       VARCHAR(100) NOT NULL,
    Address          VARCHAR(255) NOT NULL,
    MatricBoard      VARCHAR(100),
    MatricMarks      INT,
    MatricTotal      INT,
    InterBoard       VARCHAR(100),
    InterMarks       INT,
    InterTotal       INT,
    Domicile         VARCHAR(100),
    Nationality      VARCHAR(50)  DEFAULT 'Pakistani',
    BloodGroup       VARCHAR(5),
    GuardianName     VARCHAR(100),
    GuardianPhone    VARCHAR(20),
    GuardianRelation VARCHAR(50),
    AdmissionDate    DATE         DEFAULT GETDATE(),
    Status           VARCHAR(20)  DEFAULT 'Pending'
)
GO

-- ============================================================
--  TABLE: LoginDetails
--  StudentID references NEWADMISSION. Password = StudentID by default.
-- ============================================================

CREATE TABLE LoginDetails (
    StudentID  VARCHAR(20)  NOT NULL PRIMARY KEY,
    Password   VARCHAR(255) NOT NULL,
    CONSTRAINT FK_Login_Student FOREIGN KEY (StudentID)
        REFERENCES NEWADMISSION(StudentID)
        ON DELETE CASCADE
)
GO

-- ============================================================
--  TABLE: COURSES
--  Pre-populated with CS / AI / CyberSecurity / IT courses
-- ============================================================

CREATE TABLE COURSES (
    CourseID    VARCHAR(10)  NOT NULL PRIMARY KEY,
    CourseName  VARCHAR(150) NOT NULL,
    CreditHours INT          NOT NULL
)
GO

INSERT INTO COURSES (CourseID, CourseName, CreditHours) VALUES
('CS101', 'Introduction to Programming',             3),
('CS201', 'Data Structures and Algorithms',          3),
('CS301', 'Database Management Systems',             3),
('CS302', 'Operating Systems',                       3),
('CS401', 'Software Engineering',                    3),
('CS402', 'Computer Networks',                       3),
('CS501', 'Compiler Construction',                   3),
('CS502', 'Theory of Automata',                      3),
('AI101', 'Introduction to Artificial Intelligence', 3),
('AI201', 'Machine Learning',                        3),
('AI301', 'Deep Learning and Neural Networks',       3),
('AI302', 'Natural Language Processing',             3),
('AI401', 'Computer Vision',                         3),
('AI402', 'Reinforcement Learning',                  3),
('CY101', 'Introduction to CyberSecurity',           3),
('CY201', 'Network Security',                        3),
('CY301', 'Ethical Hacking and Penetration Testing', 3),
('CY302', 'Digital Forensics',                       3),
('CY401', 'Cryptography',                            3),
('CY402', 'Malware Analysis',                        3),
('IT101', 'Information Technology Fundamentals',     3),
('IT201', 'Web Technologies',                        3),
('IT301', 'Cloud Computing',                         3),
('IT302', 'Mobile Application Development',          3),
('IT401', 'DevOps and Agile Methodologies',          3)
GO

-- ============================================================
--  TABLE: SelectedCourses
--  Stores courses chosen by each student
-- ============================================================

CREATE TABLE SelectedCourses (
    ID         INT          IDENTITY(1,1) PRIMARY KEY,
    StudentID  VARCHAR(20)  NOT NULL,
    CourseID   VARCHAR(10)  NOT NULL,
    CONSTRAINT FK_SelCourse_Student FOREIGN KEY (StudentID)
        REFERENCES NEWADMISSION(StudentID)
        ON DELETE CASCADE,
    CONSTRAINT FK_SelCourse_Course  FOREIGN KEY (CourseID)
        REFERENCES COURSES(CourseID),
    CONSTRAINT UQ_StudentCourse UNIQUE (StudentID, CourseID)
)
GO

-- ============================================================
--  PROCEDURE: sp_NewAdmission
--  Generates StudentID, inserts into NEWADMISSION and LoginDetails
-- ============================================================

CREATE PROCEDURE sp_NewAdmission
    @Name             VARCHAR(100),
    @FatherName       VARCHAR(100),
    @CNIC             VARCHAR(20),
    @DateOfBirth      VARCHAR(20),
    @Gender           VARCHAR(10),
    @Email            VARCHAR(100),
    @Phone            VARCHAR(20),
    @Program          VARCHAR(100),
    @Department       VARCHAR(100),
    @Address          VARCHAR(255),
    @MatricBoard      VARCHAR(100),
    @MatricMarks      INT,
    @MatricTotal      INT,
    @InterBoard       VARCHAR(100),
    @InterMarks       INT,
    @InterTotal       INT,
    @Domicile         VARCHAR(100),
    @BloodGroup       VARCHAR(5),
    @GuardianName     VARCHAR(100),
    @GuardianPhone    VARCHAR(20),
    @GuardianRelation VARCHAR(50),
    @NewStudentID     VARCHAR(20) OUTPUT
AS
    DECLARE @SeqVal INT
    SELECT @SeqVal = NEXT VALUE FOR StudentIDSeq
    SET @NewStudentID = 'F' + CAST(25605300 + @SeqVal AS VARCHAR(20))

    INSERT INTO NEWADMISSION
        (StudentID, Name, FatherName, CNIC, DateOfBirth, Gender,
         Email, Phone, Program, Department, Address,
         MatricBoard, MatricMarks, MatricTotal,
         InterBoard,  InterMarks,  InterTotal,
         Domicile, BloodGroup,
         GuardianName, GuardianPhone, GuardianRelation)
    VALUES
        (@NewStudentID, @Name, @FatherName, @CNIC, @DateOfBirth, @Gender,
         @Email, @Phone, @Program, @Department, @Address,
         @MatricBoard, @MatricMarks, @MatricTotal,
         @InterBoard,  @InterMarks,  @InterTotal,
         @Domicile, @BloodGroup,
         @GuardianName, @GuardianPhone, @GuardianRelation)

    INSERT INTO LoginDetails (StudentID, Password)
    VALUES (@NewStudentID, @NewStudentID)

    SELECT @NewStudentID AS StudentID
GO

-- ============================================================
--  PROCEDURE: sp_StudentLogin
--  Validates StudentID and Password from LoginDetails
-- ============================================================

CREATE PROCEDURE sp_StudentLogin
    @StudentID VARCHAR(20),
    @Password  VARCHAR(255)
AS
    SELECT L.StudentID, N.Name, N.Program, N.Department
    FROM   LoginDetails L
    JOIN   NEWADMISSION N ON N.StudentID = L.StudentID
    WHERE  L.StudentID = @StudentID
    AND    L.Password  = @Password
GO

-- ============================================================
--  PROCEDURE: sp_GetStudentProfile
--  Returns full student info + selected courses with JOIN
-- ============================================================

CREATE PROCEDURE sp_GetStudentProfile
    @StudentID VARCHAR(20)
AS
    SELECT
        N.StudentID, N.Name, N.FatherName, N.CNIC,
        N.DateOfBirth, N.Gender, N.Email, N.Phone,
        N.Program, N.Department, N.Address,
        N.MatricBoard, N.MatricMarks, N.MatricTotal,
        N.InterBoard, N.InterMarks, N.InterTotal,
        N.Domicile, N.Nationality, N.BloodGroup,
        N.GuardianName, N.GuardianPhone, N.GuardianRelation,
        N.AdmissionDate, N.Status
    FROM NEWADMISSION N
    WHERE N.StudentID = @StudentID

    SELECT
        SC.CourseID,
        C.CourseName,
        C.CreditHours
    FROM SelectedCourses SC
    JOIN COURSES C ON C.CourseID = SC.CourseID
    WHERE SC.StudentID = @StudentID
GO

-- ============================================================
--  PROCEDURE: sp_GetCourses
--  Returns all available courses
-- ============================================================

CREATE PROCEDURE sp_GetCourses
AS
    SELECT CourseID, CourseName, CreditHours
    FROM   COURSES
    ORDER  BY CourseID
GO

-- ============================================================
--  PROCEDURE: sp_AddCourse
--  Adds a course for a student into SelectedCourses
-- ============================================================

CREATE PROCEDURE sp_AddCourse
    @StudentID VARCHAR(20),
    @CourseID  VARCHAR(10)
AS
    INSERT INTO SelectedCourses (StudentID, CourseID)
    VALUES (@StudentID, @CourseID)

    SELECT 1 AS Success
GO

-- ============================================================
--  PROCEDURE: sp_UpdatePassword
--  Updates the password in LoginDetails for a specific student
-- ============================================================

CREATE PROCEDURE sp_UpdatePassword
    @StudentID   VARCHAR(20),
    @NewPassword VARCHAR(255)
AS
    UPDATE LoginDetails
    SET    Password = @NewPassword
    WHERE  StudentID = @StudentID

    SELECT @@ROWCOUNT AS Updated
GO

-- ============================================================
--  PROCEDURE: sp_UpdateStudentInfo
--  Updates student information in NEWADMISSION
-- ============================================================

CREATE PROCEDURE sp_UpdateStudentInfo
    @StudentID       VARCHAR(20),
    @Name            VARCHAR(100),
    @FatherName      VARCHAR(100),
    @CNIC            VARCHAR(20),
    @DateOfBirth     VARCHAR(20),
    @Gender          VARCHAR(10),
    @Email           VARCHAR(100),
    @Phone           VARCHAR(20),
    @Program         VARCHAR(100),
    @Department      VARCHAR(100),
    @Address         VARCHAR(255),
    @Domicile        VARCHAR(100),
    @BloodGroup      VARCHAR(5),
    @GuardianName    VARCHAR(100),
    @GuardianPhone   VARCHAR(20),
    @GuardianRelation VARCHAR(50)
AS
    UPDATE NEWADMISSION
    SET
        Name             = @Name,
        FatherName       = @FatherName,
        CNIC             = @CNIC,
        DateOfBirth      = @DateOfBirth,
        Gender           = @Gender,
        Email            = @Email,
        Phone            = @Phone,
        Program          = @Program,
        Department       = @Department,
        Address          = @Address,
        Domicile         = @Domicile,
        BloodGroup       = @BloodGroup,
        GuardianName     = @GuardianName,
        GuardianPhone    = @GuardianPhone,
        GuardianRelation = @GuardianRelation
    WHERE StudentID = @StudentID

    SELECT @@ROWCOUNT AS Updated
GO

-- ============================================================
--  PROCEDURE: sp_DeleteProfile
--  Deletes student record from NEWADMISSION (cascades to LoginDetails
--  and SelectedCourses via FK ON DELETE CASCADE)
-- ============================================================

CREATE PROCEDURE sp_DeleteProfile
    @StudentID VARCHAR(20)
AS
    DELETE FROM NEWADMISSION
    WHERE  StudentID = @StudentID

    SELECT @@ROWCOUNT AS Deleted
GO

-- ============================================================
--  Verification — List tables and procedures created
-- ============================================================

SELECT TABLE_NAME AS Tables FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'
GO
SELECT name AS Procedures FROM sys.objects WHERE type = 'P'
GO
