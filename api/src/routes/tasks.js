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

//// BUỔI 2: SỬA CÔNG VIỆC
router.put('/:id', async (req, res, next) => {
  try {
    const taskId = req.params.id;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID công việc không hợp lệ.'
      });
    }

    const task = await Task.findById(taskId);

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc.'
      });
    }

    // Giai đoạn này chỉ người tạo được sửa công việc.
    if (task.createdBy.toString() !== req.userId.toString()) {
      return res.status(403).json({
        message: 'Bạn không có quyền sửa công việc này.'
      });
    }

    const data = req.body || {};
    const updates = {};

    if (Object.hasOwn(data, 'title')) {
      if (
        typeof data.title !== 'string' ||
        !data.title.trim() ||
        data.title.trim().length > 200
      ) {
        return res.status(400).json({
          message: 'Tên công việc phải từ 1 đến 200 ký tự.'
        });
      }

      updates.title = data.title.trim();
    }

    if (Object.hasOwn(data, 'description')) {
      if (
        typeof data.description !== 'string' ||
        data.description.length > 5000
      ) {
        return res.status(400).json({
          message: 'Mô tả công việc không hợp lệ.'
        });
      }

      updates.description = data.description.trim();
    }

    if (Object.hasOwn(data, 'priority')) {
      if (!['low', 'medium', 'high'].includes(data.priority)) {
        return res.status(400).json({
          message: 'Mức độ ưu tiên không hợp lệ.'
        });
      }

      updates.priority = data.priority;
    }

    if (Object.hasOwn(data, 'status')) {
      if (!['todo', 'in_progress', 'completed'].includes(data.status)) {
        return res.status(400).json({
          message: 'Trạng thái không hợp lệ.'
        });
      }

      updates.status = data.status;
    }

    for (const field of ['startDate', 'dueDate']) {
      if (Object.hasOwn(data, field)) {
        const value = data[field];

        if (value === null || value === '') {
          updates[field] = null;
        } else if (
          typeof value === 'string' &&
          /^\d{4}-\d{2}-\d{2}(T.*)?$/.test(value) &&
          !Number.isNaN(Date.parse(value))
        ) {
          updates[field] = new Date(value);
        } else {
          return res.status(400).json({
            message: `${field} không hợp lệ.`
          });
        }
      }
    }

    const start = Object.hasOwn(updates, 'startDate')
      ? updates.startDate
      : task.startDate;

    const due = Object.hasOwn(updates, 'dueDate')
      ? updates.dueDate
      : task.dueDate;

    if (start && due && due < start) {
      return res.status(400).json({
        message: 'Hạn hoàn thành không được trước ngày bắt đầu.'
      });
    }

    Object.assign(task, updates);
    await task.save();

    return res.json({
      message: 'Cập nhật công việc thành công.',
      task
    });

  } catch (err) {
    return next(err);
  }
});
module.exports = router;
