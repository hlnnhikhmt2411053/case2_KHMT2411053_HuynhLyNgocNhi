const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Task = require('../models/Task');
const requireAuth = require('../middleware/auth');
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
function tokenFor(user) {
  return jwt.sign({}, process.env.JWT_SECRET, { subject: user.id, expiresIn: '7d', algorithm: 'HS256' });
}
function publicUser(user) { return { id: user.id, fullName: user.fullName, email: user.email }; }
router.post('/register', async (req, res, next) => {
  try {
    const fullName = typeof req.body.fullName === 'string' ? req.body.fullName.trim() : '';
    const email = typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const password = typeof req.body.password === 'string' ? req.body.password : '';
    if (!fullName || fullName.length > 100 || !emailPattern.test(email) || password.length < 8 || password.length > 128)
      return res.status(400).json({ message: 'Nhập họ tên, email hợp lệ và mật khẩu từ 8 đến 128 ký tự.' });
    if (await User.exists({ email })) return res.status(409).json({ message: 'Email đã được đăng ký.' });
    const passwordHash = await bcrypt.hash(password, 12);
    const user = await User.create({ fullName, email, passwordHash });
    // Dữ liệu mẫu gắn với đúng tài khoản vừa tạo, giúp kiểm thử GET /tasks ở Buổi 1.
    await Task.create({ title: 'Hoàn thành bài thực hành Buổi 1', description: 'Kiểm thử đăng ký, đăng nhập, danh sách và chi tiết công việc.', createdBy: user._id, assigneeIds: [user._id], primaryAssigneeId: user._id, priority: 'high', status: 'todo' });
    return res.status(201).json({ token: tokenFor(user), user: publicUser(user) });
  } catch (err) {
    if (err.code === 11000) return res.status(409).json({ message: 'Email đã được đăng ký.' });
    return next(err);
  }
});
router.post('/login', async (req, res, next) => {
  try {
    const email = typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const password = typeof req.body.password === 'string' ? req.body.password : '';
    const user = await User.findOne({ email }).select('+passwordHash');
    if (!user || !(await bcrypt.compare(password, user.passwordHash)))
      return res.status(401).json({ message: 'Email hoặc mật khẩu không đúng.' });
    return res.json({ token: tokenFor(user), user: publicUser(user) });
  } catch (err) { return next(err); }
});
router.get('/me', requireAuth, async (req, res, next) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ message: 'Không tìm thấy tài khoản.' });
    return res.json({ user: publicUser(user) });
  } catch (err) { return next(err); }
});
module.exports = router;
