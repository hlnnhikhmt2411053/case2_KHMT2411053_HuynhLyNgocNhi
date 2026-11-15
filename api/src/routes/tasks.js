const router = require('express').Router();
const mongoose = require('mongoose');
const Task = require('../models/Task');
const requireAuth = require('../middleware/auth');
router.use(requireAuth);
router.get('/', async (req, res, next) => {
  try {
    const id = new mongoose.Types.ObjectId(req.userId);

const tasks = await Task.find({
  $or: [
    { createdBy: id },
    { assigneeIds: id }
  ]
})
  .populate('assigneeIds', 'fullName email')
  .populate('primaryAssigneeId', 'fullName email')
  .sort({ createdAt: -1 })
  .limit(100)
  .lean();


const result = tasks.map(task => ({
  ...task,
  isOwner: task.createdBy?.toString() === req.userId.toString()
}));

return res.json({ tasks: result });

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

//// BUỔI 2: XÓA CÔNG VIỆC
router.delete('/:id', async (req, res, next) => {
  try {
    const taskId = req.params.id;

    // Kiểm tra ID công việc
    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID công việc không hợp lệ.'
      });
    }

    // Tìm công việc trong MongoDB
    const task = await Task.findById(taskId);

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc.'
      });
    }

    // Chỉ người tạo công việc mới được xóa
    if (task.createdBy.toString() !== req.userId.toString()) {
      return res.status(403).json({
        message: 'Bạn không có quyền xóa công việc này.'
      });
    }

    // Xóa công việc
    await Task.deleteOne({
      _id: taskId,
      createdBy: req.userId
    });

    return res.json({
      message: 'Xóa công việc thành công.'
    });

  } catch (err) {
    return next(err);
  }
});

const User = require('../models/User');

// BUOI 2: GIAO CONG VIEC CHO NHIEU NGUOI
router.post('/:id/assignees', async (req, res, next) => {
  try {
    const taskId = req.params.id;
    const { emails, primaryEmail } = req.body || {};

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID công việc không hợp lệ.'
      });
    }

    // Chỉ người tạo mới được giao công việc
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.userId
    });

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền giao.'
      });
    }

    if (!Array.isArray(emails) || emails.length === 0 ||
        emails.length > 50) {
      return res.status(400).json({
        message: 'Vui lòng chọn từ 1 đến 50 người nhận.'
      });
    }

    if (emails.some(email =>
      typeof email !== 'string' ||
      !email.trim() ||
      email.length > 254
    )) {
      return res.status(400).json({
        message: 'Danh sách email không hợp lệ.'
      });
    }

    // Chuẩn hóa email và bỏ trùng
    const normalizedEmails = [
      ...new Set(
        emails.map(email => email.trim().toLowerCase())
      )
    ];

    // Tìm tài khoản đã đăng ký
    const users = await User.find({
      email: { $in: normalizedEmails }
    }).select('_id fullName email');

    const foundEmails = new Set(
      users.map(user => user.email.toLowerCase())
    );

    const missingEmails = normalizedEmails.filter(
      email => !foundEmails.has(email)
    );

    if (missingEmails.length > 0) {
      return res.status(400).json({
        message: 'Một số email chưa đăng ký tài khoản.',
        missingEmails
      });
    }

    let primaryAssigneeId = null;

    if (primaryEmail != null && primaryEmail !== '') {
      if (typeof primaryEmail !== 'string') {
        return res.status(400).json({
          message: 'Email người phụ trách chính không hợp lệ.'
        });
      }

      const normalizedPrimary = primaryEmail.trim().toLowerCase();

      const primaryUser = users.find(
        user => user.email.toLowerCase() === normalizedPrimary
      );

      if (!primaryUser) {
        return res.status(400).json({
          message: 'Người phụ trách chính phải có trong danh sách được giao.'
        });
      }

      primaryAssigneeId = primaryUser._id;
    }

    // Lưu danh sách người nhận vào MongoDB
    task.assigneeIds = users.map(user => user._id);
    task.primaryAssigneeId = primaryAssigneeId;

    await task.save();

    return res.json({
      message: 'Giao công việc thành công.',
      assignees: users,
      primaryAssigneeId: task.primaryAssigneeId
    });

  } catch (err) {
    return next(err);
  }
});

//// BUỔI 2: LẤY DANH SÁCH NGƯỜI ĐÃ ĐƯỢC GIAO CÔNG VIỆC
router.get('/:id/assignees', async (req, res, next) => {
  try {
    const taskId = req.params.id;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: 'ID công việc không hợp lệ.'
      });
    }

    // Người tạo hoặc người được giao mới có quyền xem
    const task = await Task.findOne({
      _id: taskId,
      $or: [
        { createdBy: req.userId },
        { assigneeIds: req.userId }
      ]
    }).lean();

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền xem.'
      });
    }

    // Lấy thông tin người nhận từ MongoDB
    const users = await User.find({
      _id: { $in: task.assigneeIds || [] }
    })
      .select('_id fullName email')
      .lean();

    // Giữ đúng thứ tự danh sách đã giao
    const usersById = new Map(
      users.map(user => [user._id.toString(), user])
    );

    const assignees = (task.assigneeIds || [])
      .map(id => usersById.get(id.toString()))
      .filter(Boolean);

    const primaryId = task.primaryAssigneeId?.toString() || null;

    const primaryUser = assignees.find(
      user => user._id.toString() === primaryId
    );

    return res.json({
      message: 'Lấy danh sách người nhận thành công.',
      assignees,
      primaryAssigneeId: primaryId,
      primaryEmail: primaryUser?.email || null
    });

  } catch (err) {
    return next(err);
  }
});
module.exports = router;
