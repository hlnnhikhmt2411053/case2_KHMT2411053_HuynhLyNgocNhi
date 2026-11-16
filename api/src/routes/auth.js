const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const requireAuth = require('../middleware/auth');
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
function tokenFor(user) {
  return jwt.sign({}, process.env.JWT_SECRET, { subject: user.id, expiresIn: '7d', algorithm: 'HS256' });
}
function publicUser(user) { return { id: user.id, fullName: user.fullName, email: user.email }; }
router.post('/register', async (req, res, next) => {
  try {
    const fullName = typeof req.body?.fullName === 'string' ? req.body.fullName.trim() : '';
    const email = typeof req.body?.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const password = typeof req.body?.password === 'string' ? req.body.password : '';
    if (!fullName || fullName.length > 100 || email.length > 254 || !emailPattern.test(email) || password.length < 8 || password.length > 128)
      return res.status(400).json({ message: 'Nhập họ tên, email hợp lệ và mật khẩu 8–128 ký tự.' });
    if (await User.exists({ email })) return res.status(409).json({ message: 'Email đã được đăng ký.' });
    const user = await User.create({ fullName, email, passwordHash: await bcrypt.hash(password, 12) });
    return res.status(201).json({ token: tokenFor(user), user: publicUser(user) });
  } catch (e) {
    if (e.code === 11000) return res.status(409).json({ message: 'Email đã được đăng ký.' });
    next(e);
  }
});
router.post('/login', async (req, res, next) => {
  try {
    const email = typeof req.body?.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const password = typeof req.body?.password === 'string' ? req.body.password : '';
    const user = await User.findOne({ email }).select('+passwordHash');
    if (!user || !(await bcrypt.compare(password, user.passwordHash)))
      return res.status(401).json({ message: 'Email hoặc mật khẩu không đúng.' });
    res.json({ token: tokenFor(user), user: publicUser(user) });
  } catch (e) { next(e); }
});
router.get('/me', requireAuth, async (req, res, next) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ message: 'Không tìm thấy tài khoản.' });
    res.json({ user: publicUser(user) });
  } catch (e) { next(e); }
});
router.put('/me', requireAuth, async (req, res, next) => {
  try {
    const fullName = typeof req.body?.fullName === 'string' ? req.body.fullName.trim() : '';
    if (!fullName || fullName.length > 100) return res.status(400).json({ message: 'Họ tên 1–100 ký tự.' });
    const user = await User.findByIdAndUpdate(req.userId, { $set: { fullName } }, { new: true, runValidators: true });
    if (!user) return res.status(404).json({ message: 'Không tìm thấy tài khoản.' });
    res.json({ user: publicUser(user) });
  } catch (e) { next(e); }
});
router.put('/change-password', requireAuth, async (req, res, next) => {
  try {
    const oldPassword = req.body?.oldPassword;
    const newPassword = req.body?.newPassword;
    if (typeof oldPassword !== 'string' || typeof newPassword !== 'string' || newPassword.length < 8 || newPassword.length > 128)
      return res.status(400).json({ message: 'Mật khẩu mới phải dài 8–128 ký tự.' });
    const user = await User.findById(req.userId).select('+passwordHash');
    if (!user || !(await bcrypt.compare(oldPassword, user.passwordHash)))
      return res.status(401).json({ message: 'Mật khẩu hiện tại không đúng.' });
    user.passwordHash = await bcrypt.hash(newPassword, 12);
    await user.save();
    res.json({ message: 'Đổi mật khẩu thành công.' });
  } catch (e) { next(e); }
});
module.exports = router;
