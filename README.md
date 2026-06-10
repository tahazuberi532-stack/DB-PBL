# DB-PBL
# University Enrollment System — Database Project

> **CS160: Database Systems | PBL Assignment**
> NUTECH — National University of Technology, Islamabad
> Instructor: Ms. Saima Yasmeen | GitHub: [@saimayasmeen4](https://github.com/saimayasmeen4)

---

## Project Overview

A comprehensive relational database design and implementation for a **University Enrollment System** built on **Microsoft SQL Server 2022**. The project covers the full DBMS pipeline — from conceptual EERD design through physical SQL implementation with constraints, views, triggers, and advanced queries.

---

## Repository Structure

```
university-enrollment-system/
├── sql/
│   └── UES_Database.sql        # Complete T-SQL script
├── docs/
│   ├── UES_Report.docx         # Full project report (DOCX)
│   └── UES_EERD.png            # High-definition EERD diagram
└── README.md
```

---

## Database Schema — 10 Tables

| Table | Type | Description |
|-------|------|-------------|
| `Department` | Strong Entity | 15 academic departments |
| `Person` | Strong Entity (Supertype) | All persons — shared attributes incl. composite Address |
| `Faculty` | Subtype of Person | ISA specialisation — rank, salary, department |
| `Student` | Subtype of Person | ISA specialisation — CGPA, program type, advisor |
| `StudentPhone` | Multi-Valued Attribute | One-to-many phone numbers per student |
| `Course` | Strong Entity | Self-referencing prerequisite FK |
| `Semester` | Strong Entity | 15 semesters (Fall/Spring/Summer, 2019–2025) |
| `CourseSection` | Strong Entity | One offering of a course in a semester |
| `Enrollment` | **Weak Entity** | Identifying relationship Student ↔ CourseSection |
| `EnrollmentAudit` | Audit Log | Populated exclusively by triggers |

---

## Advanced EERD Constructs Demonstrated

- **Generalisation / Specialisation** — `Person` → `Student` / `Faculty` (disjoint, total participation)
- **Weak Entity** — `Enrollment` identified by `StudentID + SectionID`
- **Associative Entity** — `Enrollment` resolves the M:N between Student and CourseSection
- **Multi-Valued Attribute** — `StudentPhone` stores multiple phone numbers per student
- **Composite Attribute** — `Address` decomposed into Street, City, State, ZipCode on Person
- **Recursive Relationship** — `Course.PrereqCourseID` → `Course` (prerequisite chain)

---

## SQL Features Implemented

### Constraints
- `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT`, `IDENTITY(1,1)`
- `FOREIGN KEY` with `ON DELETE CASCADE` and `ON DELETE SET NULL`
- `UNIQUE(StudentID, SectionID)` on Enrollment (identifies weak entity)

### Views (3)
| View | Purpose |
|------|---------|
| `vw_StudentTranscript` | Complete academic history per student (8-table join) |
| `vw_FacultyWorkload` | Teaching load and enrollment stats per faculty |
| `vw_SectionAvailability` | Real-time seat availability for all sections |

### Triggers (2)
| Trigger | Event | Action |
|---------|-------|--------|
| `trg_UpdateSectionEnrollment` | AFTER INSERT/UPDATE/DELETE on Enrollment | Auto-maintains `CurrentEnrollment`; enforces capacity with `RAISERROR + ROLLBACK` |
| `trg_AuditEnrollmentChanges` | AFTER INSERT/UPDATE/DELETE on Enrollment | Logs old/new status & grade to `EnrollmentAudit` |

### Advanced Queries
| Query | Type | Tables Joined |
|-------|------|--------------|
| J-1: Full Enrollment Details | Multi-Table JOIN | 8 tables |
| J-2: Faculty Teaching Schedule | Multi-Table JOIN | 6 tables |
| J-3: Prerequisite Chain | Self-JOIN | 3 tables |
| A-1: Course Performance Stats | GROUP BY + HAVING | Aggregation |
| A-2: Department HR Summary | GROUP BY + SUM/AVG/MAX/MIN | Aggregation |
| A-3: Program Type Distribution | CASE + COUNT | Aggregation |
| S-1: Above-Average Enrollments | Correlated Subquery | — |
| S-2: Distinction Courses | IN Subquery | — |
| S-3: Completed Students | EXISTS Subquery | — |
| S-4: High-Enrollment Sections | ANY Subquery | — |

---

## Setup Instructions

### Prerequisites
- Microsoft SQL Server 2022 (any edition including Express)
- SQL Server Management Studio (SSMS) 2022

### Steps to Execute

1. **Open SSMS** and connect to your SQL Server instance.

2. **Open the script:**
   - `File → Open → File…`
   - Navigate to and select `sql/UES_Database.sql`

3. **Execute the full script:**
   - Press **F5** or click **Execute**
   - The script will create the database, all tables, insert all data, create triggers, create views, and run all queries in sequence

4. **Verify execution:**
   - In the Object Explorer, expand `UniversityEnrollmentSystem → Tables` — 10 tables should be visible
   - Run `SELECT * FROM EnrollmentAudit ORDER BY ChangedAt;` to verify triggers fired
   - Run `SELECT * FROM vw_StudentTranscript;` to test views

5. **Reset (re-run from scratch):**
   - The script includes a cleanup `SECTION 2` that safely drops all objects before recreation — simply execute the full script again

---

## Sample Queries to Test

```sql
-- View full transcript for a student
SELECT * FROM vw_StudentTranscript WHERE StudentID = 16 ORDER BY AcademicTerm;

-- Check faculty workload
SELECT * FROM vw_FacultyWorkload ORDER BY TotalStudentsTeaching DESC;

-- Spring 2025 seat availability
SELECT * FROM vw_SectionAvailability WHERE AcademicTerm = 'Spring 2025';

-- Verify trigger fired (audit log)
SELECT * FROM EnrollmentAudit ORDER BY ChangedAt;

-- Verify CurrentEnrollment was auto-updated
SELECT SectionID, CourseID, CurrentEnrollment, MaxCapacity
FROM CourseSection WHERE CurrentEnrollment > 0;
```

---

## Data Overview

| Table | Rows | Key Detail |
|-------|------|------------|
| Department | 15 | CS, EE, Math, BA, SE, Physics, Civil, Mech, AI, CySec, IT, DataSci, ChemEng, Econ, English |
| Person | 30 | 15 faculty + 15 students; all Islamabad-based |
| Faculty | 15 | Ranks: Lecturer → Professor across 12 departments |
| Student | 15 | Mix of Undergraduate/Graduate; CGPAs 0.00–3.90 |
| StudentPhone | 20 | Mobile, Home, Work types |
| Course | 15 | CS, Math, EE, BA, SE tracks; prerequisite chains up to depth 3 |
| Semester | 15 | Fall/Spring/Summer 2019–2025 |
| CourseSection | 20 | Sections across 10 semesters |
| Enrollment | 21 | 15 Completed, 1 Dropped, 1 Withdrawn, 4 Enrolled (active) |
| EnrollmentAudit | 22+ | Auto-populated by `trg_AuditEnrollmentChanges` |

---

## Instructor Access

**GitHub Handle:** `saimayasmeen4`

To add the instructor as a collaborator:
1. Go to the repository on GitHub
2. Navigate to **Settings → Collaborators → Add people**
3. Search for `saimayasmeen4` and send the invitation

---

*University Enrollment System — CS160 Database Systems PBL | NUTECH 2025*
University Enrollment System Database Project developed for CS160 Database Systems (NUTECH). Includes EERD-based relational database design, SQL DDL implementation, constraints, triggers, views, advanced queries, and sample data population for managing students, faculty, courses, enrollments, and academic records.
