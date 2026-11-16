const router = require('express').Router();
const mongoose = require('mongoose');
const User = require('../models/User');
const auth = require('../middleware/auth');
router.use(auth);
router.get('/search', async (req, res, next) => {
  try {
    const q = String(req.query.q || '').trim().slice(0, 100);
    if (q.length < 2) return res.json({ users: [] });
    const escaped = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const users = await User.find({ $or: [
      { email: { $regex: escaped, $options: 'i' } },
      { fullName: { $regex: escaped, $options: 'i' } }
    ] }).select('_id fullName email').limit(15).lean();
    res.json({ users });
  } catch (e) { next(e); }
});
router.get('/:id', async (req, res, next) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'ID không hợp lệ.' });
    const user = await User.findById(req.params.id).select('_id fullName email').lean();
    if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng.' });
    res.json({ user });
  } catch (e) { next(e); }
});
module.exports = router;
