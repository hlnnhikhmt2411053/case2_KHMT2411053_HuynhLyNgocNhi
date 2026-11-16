require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const app = express();
app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '20kb' }));
app.get('/', (_req, res) => res.json({ message: 'Task Manager API đang hoạt động' }));
app.use('/api/auth', require('./routes/auth'));
app.use('/api/users', require('./routes/users'));
app.use('/api/tasks', require('./routes/tasks'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/statistics', require('./routes/statistics'));
app.use('/api/email-logs', require('./routes/emailLogs'));
app.use((_req, res) => res.status(404).json({ message: 'API không tồn tại.' }));
app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({ message: 'Lỗi máy chủ, vui lòng thử lại.' });
});
async function start() {
  if (!process.env.MONGODB_URI || !process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
    throw new Error('Cần MONGODB_URI và JWT_SECRET tối thiểu 32 ký tự trong api/.env');
  }
  await mongoose.connect(process.env.MONGODB_URI, { serverSelectionTimeoutMS: 10000 });
  const port = Number(process.env.PORT || 3000);
  app.listen(port, '0.0.0.0', () => console.log(`API: http://localhost:${port}`));
  require('./services/reminders').startReminders();
}
if (require.main === module) start().catch(e => { console.error(e.message); process.exit(1); });
module.exports = app; // Cho phép viết kiểm thử API.
