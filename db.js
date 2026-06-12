// db.js – SQL Server connection using Windows Authentication (msnodesqlv8)
// Server  : localhost  (matches SSMS → Server Name: localhost)
// Auth    : Windows Authentication  (MBN\nasir — no password needed)
// Options : TrustServerCertificate=yes  (matches SSMS Trust Server Certificate ✓)
const sql = require('mssql/msnodesqlv8');

const config = {
  connectionString:
    'Driver={SQL Server};Server=localhost;Database=UNIVERSITY;Trusted_Connection=yes;TrustServerCertificate=yes;'
};

let pool = null;

async function getPool() {
  if (!pool) {
    pool = await sql.connect(config);
    console.log('[DB] Connected to UNIVERSITY on localhost (Windows Auth)');
  }
  return pool;
}

module.exports = { sql, getPool };
