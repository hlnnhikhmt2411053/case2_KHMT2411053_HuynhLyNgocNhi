const router = require('express').Router();
const mongoose = require('mongoose');
const auth = require('../middleware/auth');
const Task = require('../models/Task');
const EmailLog = require('../models/EmailLog');
const { sendEmailLog } = require('../services/messaging');
router.use(auth);
router.post('/:id/retry', async (req, res, next) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'ID không hợp lệ.' });
    const log = await EmailLog.findById(req.params.id).select('+text');
    if (!log) return res.status(404).json({ message: 'Không tìm thấy email.' });
    const task = await Task.findOne({ _id: log.taskId, createdBy: req.userId });
    if (!task) return res.status(403).json({ message: 'Chỉ người tạo công việc được gửi lại.' });
    if (log.status === 'sent' || log.attempts >= 3) return res.status(400).json({ message: 'Email đã gửi hoặc vượt số lần gửi lại.' });
    await sendEmailLog(log);
    res.json({ message: 'Đã xử lý yêu cầu gửi lại.', status: log.status });
  } catch (e) { next(e); }
});
module.exports = router;
