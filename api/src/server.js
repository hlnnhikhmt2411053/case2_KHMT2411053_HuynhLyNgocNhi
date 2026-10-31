require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const app = express();
app.use(cors());
app.use(express.json({ limit: '20kb' }));
app.get('/', (_req, res) => res.json({ message: 'Task Manager API đang hoạt động' }));
app.use('/api/auth', require('./routes/auth'));
app.use('/api/tasks', require('./routes/tasks'));
app.use((_req, res) => res.status(404).json({ message: 'API không tồn tại.' }));
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ message: 'Lỗi máy chủ. Vui lòng thử lại.' });
});
async function start() {
  if (!process.env.MONGODB_URI || !process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
    throw new Error('Hãy cấu hình MONGODB_URI và JWT_SECRET (ít nhất 32 ký tự) trong file .env');
  }
  await mongoose.connect(process.env.MONGODB_URI, { serverSelectionTimeoutMS: 10000 });
  const port = Number(process.env.PORT || 3000);
  app.listen(port, '0.0.0.0', () => console.log(`API: http://localhost:${port}`));
}
start().catch(err => { console.error('Không thể chạy API:', err.message); process.exit(1); });
