// server.js — National University of Technology — Management System Backend
const express    = require('express');
const cors       = require('cors');
const bodyParser = require('body-parser');
const path       = require('path');
const { sql, getPool } = require('./db');

const app  = express();
const PORT = 3000;

app.use(cors());
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'public')));

// ─────────────────────────────────────────────────────────
//  NEW ADMISSION — sp_NewAdmission
//  Auto-generates StudentID (F25605300++) and seeds LoginDetails
// ─────────────────────────────────────────────────────────
app.post('/api/admission', async (req, res) => {
  try {
    const {
      name, fatherName, cnic, dateOfBirth, gender, email, phone,
      program, department, address,
      matricBoard, matricMarks, matricTotal,
      interBoard, interMarks, interTotal,
      domicile, bloodGroup,
      guardianName, guardianPhone, guardianRelation
    } = req.body;

    const pool    = await getPool();
    const request = pool.request();

    request.input('Name',             sql.VarChar(100), name);
    request.input('FatherName',       sql.VarChar(100), fatherName);
    request.input('CNIC',             sql.VarChar(20),  cnic);
    request.input('DateOfBirth',      sql.VarChar(20),  dateOfBirth);
    request.input('Gender',           sql.VarChar(10),  gender);
    request.input('Email',            sql.VarChar(100), email);
    request.input('Phone',            sql.VarChar(20),  phone);
    request.input('Program',          sql.VarChar(100), program);
    request.input('Department',       sql.VarChar(100), department);
    request.input('Address',          sql.VarChar(255), address);
    request.input('MatricBoard',      sql.VarChar(100), matricBoard  || null);
    request.input('MatricMarks',      sql.Int,          matricMarks  ? parseInt(matricMarks)  : null);
    request.input('MatricTotal',      sql.Int,          matricTotal  ? parseInt(matricTotal)  : null);
    request.input('InterBoard',       sql.VarChar(100), interBoard   || null);
    request.input('InterMarks',       sql.Int,          interMarks   ? parseInt(interMarks)   : null);
    request.input('InterTotal',       sql.Int,          interTotal   ? parseInt(interTotal)   : null);
    request.input('Domicile',         sql.VarChar(100), domicile     || null);
    request.input('BloodGroup',       sql.VarChar(5),   bloodGroup   || null);
    request.input('GuardianName',     sql.VarChar(100), guardianName || null);
    request.input('GuardianPhone',    sql.VarChar(20),  guardianPhone    || null);
    request.input('GuardianRelation', sql.VarChar(50),  guardianRelation || null);
    request.output('NewStudentID',    sql.VarChar(20));

    const result    = await request.execute('sp_NewAdmission');
    const studentID = result.output.NewStudentID;

    res.json({ success: true, studentID, message: `Admission successful! Your Student ID: ${studentID}` });
  } catch (err) {
    console.error('[/api/admission]', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────
//  STUDENT LOGIN — sp_StudentLogin
// ─────────────────────────────────────────────────────────
app.post('/api/student/login', async (req, res) => {
  try {
    const { studentID, password } = req.body;
    const pool    = await getPool();
    const request = pool.request();
    request.input('StudentID', sql.VarChar(20),  studentID);
    request.input('Password',  sql.VarChar(255), password);
    const result = await request.execute('sp_StudentLogin');
    if (result.recordset.length === 0)
      return res.status(401).json({ success: false, message: 'Invalid Student ID or Password.' });
    res.json({ success: true, student: result.recordset[0] });
  } catch (err) {
    console.error('[/api/student/login]', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────
//  GET STUDENT PROFILE — sp_GetStudentProfile
//  Returns student info (recordset[0]) + selected courses (recordset[1])
// ─────────────────────────────────────────────────────────
app.get('/api/student/profile', async (req, res) => {
  try {
    const { studentID } = req.query;
    const pool    = await getPool();
    const request = pool.request();
    request.input('StudentID', sql.VarChar(20), studentID);
    const result = await request.execute('sp_GetStudentProfile');
    if (result.recordsets[0].length === 0)
      return res.status(404).json({ success: false, message: 'Student not found.' });
    res.json({
      success:  true,
      student:  result.recordsets[0][0],
      courses:  result.recordsets[1]
    });
  } catch (err) {
    console.error('[/api/student/profile]', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────
//  GET ALL COURSES — sp_GetCourses
// ─────────────────────────────────────────────────────────
app.get('/api/courses', async (req, res) => {
  try {
    const pool    = await getPool();
    const request = pool.request();
    const result  = await request.execute('sp_GetCourses');
    res.json({ success: true, courses: result.recordset });
  } catch (err) {
    console.error('[/api/courses]', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────
//  ADD COURSE — sp_AddCourse
// ─────────────────────────────────────────────────────────
app.post('/api/student/addcourse', async (req, res) => {
  try {
    const { studentID, courseID } = req.body;
    const pool    = await getPool();
    const request = pool.request();
    request.input('StudentID', sql.VarChar(20), studentID);
    request.input('CourseID',  sql.VarChar(10), courseID);
    await request.execute('sp_AddCourse');
    res.json({ success: true, message: 'Course added successfully.' });
  } catch (err) {
    if (err.message && err.message.includes('UQ_StudentCourse'))
      return res.status(409).json({ success: false, message: 'Course already added.' });
    console.error('[/api/student/addcourse]', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────
//  UPDATE PASSWORD — sp_UpdatePassword
// ─────────────────────────────────────────────────────────
app.put('/api/student/updatepassword', async (req, res) => {
  try {
    const { studentID, newPassword } = req.body;
    const pool    = await getPool();
    const request = pool.request();
    request.input('StudentID',   sql.VarChar(20),  studentID);
    request.input('NewPassword', sql.VarChar(255), newPassword);
    await request.execute('sp_UpdatePassword');
    res.json({ success: true, message: 'Password updated successfully.' });
  } catch (err) {
    console.error('[/api/student/updatepassword]', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────
//  UPDATE STUDENT INFO — sp_UpdateStudentInfo
// ─────────────────────────────────────────────────────────
app.put('/api/student/updateinfo', async (req, res) => {
  try {
    const {
      studentID, name, fatherName, cnic, dateOfBirth, gender,
      email, phone, program, department, address,
      domicile, bloodGroup, guardianName, guardianPhone, guardianRelation
    } = req.body;

    const pool    = await getPool();
    const request = pool.request();
    request.input('StudentID',       sql.VarChar(20),  studentID);
    request.input('Name',            sql.VarChar(100), name);
    request.input('FatherName',      sql.VarChar(100), fatherName);
    request.input('CNIC',            sql.VarChar(20),  cnic);
    request.input('DateOfBirth',     sql.VarChar(20),  dateOfBirth);
    request.input('Gender',          sql.VarChar(10),  gender);
    request.input('Email',           sql.VarChar(100), email);
    request.input('Phone',           sql.VarChar(20),  phone);
    request.input('Program',         sql.VarChar(100), program);
    request.input('Department',      sql.VarChar(100), department);
    request.input('Address',         sql.VarChar(255), address);
    request.input('Domicile',        sql.VarChar(100), domicile        || null);
    request.input('BloodGroup',      sql.VarChar(5),   bloodGroup      || null);
    request.input('GuardianName',    sql.VarChar(100), guardianName    || null);
    request.input('GuardianPhone',   sql.VarChar(20),  guardianPhone   || null);
    request.input('GuardianRelation',sql.VarChar(50),  guardianRelation|| null);

    await request.execute('sp_UpdateStudentInfo');
    res.json({ success: true, message: 'Information updated successfully.' });
  } catch (err) {
    console.error('[/api/student/updateinfo]', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────
//  DELETE PROFILE — sp_DeleteProfile
//  Cascades: removes NEWADMISSION row → triggers FK cascade
//  to delete LoginDetails and SelectedCourses rows too
// ─────────────────────────────────────────────────────────
app.delete('/api/student/deleteprofile', async (req, res) => {
  try {
    const { studentID } = req.body;
    const pool    = await getPool();
    const request = pool.request();
    request.input('StudentID', sql.VarChar(20), studentID);
    await request.execute('sp_DeleteProfile');
    res.json({ success: true, message: 'Profile deleted successfully.' });
  } catch (err) {
    console.error('[/api/student/deleteprofile]', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────
//  START SERVER
// ─────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`\n  National University of Technology — Server running at http://localhost:${PORT}\n`);
});
