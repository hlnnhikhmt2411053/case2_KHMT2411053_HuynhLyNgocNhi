const router = require('express').Router();
const mongoose = require('mongoose');
const Task = require('../models/Task');
const requireAuth = require('../middleware/auth');
router.use(requireAuth);
router.get('/', async (req, res, next) => {
  try {
    const id = new mongoose.Types.ObjectId(req.userId);
    const tasks = await Task.find({ $or: [{ createdBy: id }, { assigneeIds: id }] })
      .sort({ createdAt: -1 }).limit(100).lean();
    return res.json({ tasks });
  } catch (err) { return next(err); }
});
router.get('/:id', async (req, res, next) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'ID công việc không hợp lệ.' });
    const id = new mongoose.Types.ObjectId(req.userId);
    const task = await Task.findOne({ _id: req.params.id, $or: [{ createdBy: id }, { assigneeIds: id }] }).lean();
    if (!task) return res.status(404).json({ message: 'Không tìm thấy công việc hoặc bạn không có quyền xem.' });
    return res.json({ task });
  } catch (err) { return next(err); }
});
module.exports = router;
