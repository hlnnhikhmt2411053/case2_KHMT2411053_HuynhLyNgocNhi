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

router.post('/', async (req, res, next) => {
  try {
    const {
      title,
      description = '',
      startDate,
      dueDate,
      priority = 'medium',
      status = 'todo'
    } = req.body || {};

    // Kiểm tra tên công việc
    if (
      typeof title !== 'string' ||
      !title.trim() ||
      title.trim().length > 200
    ) {
      return res.status(400).json({
        message: 'Tên công việc phải từ 1 đến 200 ký tự.'
      });
    }

    // Kiểm tra mô tả
    if (
      typeof description !== 'string' ||
      description.length > 5000
    ) {
      return res.status(400).json({
        message: 'Mô tả công việc không hợp lệ.'
      });
    }

    // Kiểm tra mức độ ưu tiên và trạng thái
    if (!['low', 'medium', 'high'].includes(priority)) {
      return res.status(400).json({
        message: 'Mức độ ưu tiên không hợp lệ.'
      });
    }

    if (!['todo', 'in_progress', 'completed'].includes(status)) {
      return res.status(400).json({
        message: 'Trạng thái công việc không hợp lệ.'
      });
    }

    // Kiểm tra ngày bắt đầu và hạn hoàn thành
    function parseDate(value) {
      if (value == null || value === '') return null;
      if (typeof value !== 'string') return undefined;
      const date = new Date(value);
      return Number.isNaN(date.getTime()) ? undefined : date;
    }

    const start = parseDate(startDate);
    const due = parseDate(dueDate);

    if (start === undefined || due === undefined) {
      return res.status(400).json({
        message: 'Ngày bắt đầu hoặc hạn hoàn thành không hợp lệ.'
      });
    }

    if (start && due && due < start) {
      return res.status(400).json({
        message: 'Hạn hoàn thành không được trước ngày bắt đầu.'
      });
    }

    // ID người tạo lấy từ token đã xác thực
    const createdBy = new mongoose.Types.ObjectId(req.userId);

    const task = await Task.create({
      title: title.trim(),
      description: description.trim(),
      createdBy,
      priority,
      status,
      ...(start ? { startDate: start } : {}),
      ...(due ? { dueDate: due } : {})
    });

    return res.status(201).json({
      message: 'Thêm công việc thành công.',
      task
    });
  } catch (err) {
    return next(err);
  }
});
module.exports = router;
