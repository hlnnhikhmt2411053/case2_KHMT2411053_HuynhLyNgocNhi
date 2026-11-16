const router = require('express').Router();
const mongoose = require('mongoose');
const Notification = require('../models/Notification');
const auth = require('../middleware/auth');
router.use(auth);
router.get('/', async (req, res, next) => {
  try {
    const [notifications, unreadCount] = await Promise.all([
      Notification.find({ userId: req.userId }).sort({ createdAt: -1 }).limit(100).lean(),
      Notification.countDocuments({ userId: req.userId, isRead: false })
    ]);
    res.json({ notifications, unreadCount });
  } catch (e) { next(e); }
});
router.get('/unread-count', async (req, res, next) => {
  try { res.json({ unreadCount: await Notification.countDocuments({ userId: req.userId, isRead: false }) }); }
  catch (e) { next(e); }
});
router.patch('/read-all', async (req, res, next) => {
  try {
    await Notification.updateMany({ userId: req.userId, isRead: false }, { $set: { isRead: true } });
    res.json({ message: 'Đã đọc tất cả thông báo.' });
  } catch (e) { next(e); }
});
async function markRead(req, res, next) {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'ID thông báo không hợp lệ.' });
    const notification = await Notification.findOneAndUpdate(
      { _id: req.params.id, userId: req.userId }, { $set: { isRead: true } }, { new: true }
    );
    if (!notification) return res.status(404).json({ message: 'Không tìm thấy thông báo.' });
    res.json({ message: 'Đã đánh dấu đã đọc.', notification });
  } catch (e) { next(e); }
}
router.put('/:id/read', markRead); // Giữ tương thích code Flutter cũ
router.patch('/:id/read', markRead);
module.exports = router;
