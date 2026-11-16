const router = require('express').Router();
const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const Notification = require('../models/Notification');
const EmailLog = require('../models/EmailLog');
const TaskActivity = require('../models/TaskActivity');
const { safeEvent, activity } = require('../services/messaging');
const { canonicalPermission, isEditor } = require('../utils/permissions');
const requireAuth = require('../middleware/auth');
router.use(requireAuth);
// Danh sach: cong viec da tao, duoc giao, hoac duoc chia se.
router.get('/', async (req, res, next) => {
  try {
    const userId = new mongoose.Types.ObjectId(req.userId);
    const shares = await TaskShare.find({ userId })
      .select('taskId permission')
      .lean();

    const sharePermissionByTask = new Map(
      shares.map(share => [share.taskId.toString(), canonicalPermission(share.permission)])
    );

    // Mọi bộ lọc đều nằm SAU điều kiện phân quyền để không lộ task riêng tư.
    const conditions = [];
    const scope = String(req.query.scope || 'all');
    const owned = { createdBy: userId };
    const assigned = { assigneeIds: userId };
    const shared = { _id: { $in: shares.map(share => share.taskId) } };
    const access = scope === 'created' ? owned : scope === 'assigned' ? assigned
      : scope === 'shared' ? shared : { $or: [owned, assigned, shared] };
    conditions.push(access);
    if (['todo', 'in_progress', 'completed'].includes(req.query.status))
      conditions.push({ status: req.query.status });
    if (['low', 'medium', 'high'].includes(req.query.priority))
      conditions.push({ priority: req.query.priority });
    const q = String(req.query.q || '').trim().slice(0, 100);
    if (q) conditions.push({ title: { $regex: q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' } });
    if (mongoose.isValidObjectId(req.query.assignee))
      conditions.push({ assigneeIds: req.query.assignee });
    const sortBy = ['createdAt', 'dueDate', 'priority'].includes(req.query.sortBy)
      ? req.query.sortBy : 'createdAt';
    const order = req.query.order === 'asc' ? 1 : -1;
    const tasks = await Task.find({ $and: conditions })
      .populate('assigneeIds', 'fullName email')
      .populate('primaryAssigneeId', 'fullName email')
      .sort({ createdAt: -1 })
      .limit(200).lean();
    // Sắp xếp trong tập tối đa 200 công việc mà tài khoản được xem.
    // Độ ưu tiên dùng thứ tự low < medium < high, không theo bảng chữ cái.
    if (sortBy !== 'createdAt' || order === 1) {
      const weights = { low: 1, medium: 2, high: 3 };
      tasks.sort((a, b) => {
        // Công việc chưa có hạn luôn nằm sau công việc có hạn.
        if (sortBy === 'dueDate') {
          if (!a.dueDate && b.dueDate) return 1;
          if (a.dueDate && !b.dueDate) return -1;
        }
        const av = sortBy === 'priority' ? weights[a.priority] || 0
          : sortBy === 'dueDate' ? (a.dueDate?.getTime() ?? 0)
          : a.createdAt.getTime();
        const bv = sortBy === 'priority' ? weights[b.priority] || 0
          : sortBy === 'dueDate' ? (b.dueDate?.getTime() ?? 0)
          : b.createdAt.getTime();
        return (av - bv) * order;
      });
    }

    const result = tasks.map(task => {
      const isOwner = task.createdBy.toString() === req.userId.toString();
      const sharePermission = sharePermissionByTask.get(task._id.toString()) || null;
      const assigned = (task.assigneeIds || []).some(u => (u._id || u).toString() === req.userId.toString());
      const primary = (task.primaryAssigneeId?._id || task.primaryAssigneeId)?.toString() === req.userId.toString();
      const role = isOwner ? 'owner' : primary ? 'primary' : assigned ? 'assignee' : 'shared';
      return {
        ...task,
        isOwner,
        canEdit: isOwner || isEditor(sharePermission),
        sharePermission,
        role
      };
    });

    return res.json({ tasks: result });
  } catch (err) {
    return next(err);
  }
});

// Chi tiet: chu so huu, nguoi duoc giao hoac nguoi duoc chia se.
router.get('/:id', async (req, res, next) => {
  try {
    const taskId = req.params.id;
    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({ message: 'ID công việc không hợp lệ.' });
    }

    const task = await Task.findById(taskId)
      .populate('createdBy', 'fullName email')
      .populate('assigneeIds', 'fullName email')
      .populate('primaryAssigneeId', 'fullName email').lean();
    if (!task) {
      return res.status(404).json({ message: 'Không tìm thấy công việc.' });
    }

    const isOwner = (task.createdBy._id || task.createdBy).toString() === req.userId.toString();
    const isAssignee = (task.assigneeIds || []).some(
      id => (id._id || id).toString() === req.userId.toString()
    );
    const [share, shares] = await Promise.all([
      TaskShare.findOne({ taskId, userId: req.userId }).select('permission').lean(),
      TaskShare.find({ taskId }).populate('userId', 'fullName email').select('userId permission').lean()
    ]);

    if (!isOwner && !isAssignee && !share) {
      return res.status(403).json({ message: 'Bạn không có quyền xem công việc này.' });
    }

    return res.json({
      task: {
        ...task,
        isOwner,
        canEdit: isOwner || isEditor(share?.permission),
        sharePermission: canonicalPermission(share?.permission),
        shares: shares.map(x => ({ ...x, permission: canonicalPermission(x.permission) }))
      }
    });
  } catch (err) {
    return next(err);
  }
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

    await activity(task._id, req.userId, 'created', { title: task.title });
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

    // Chu so huu va nguoi duoc chia se quyen edit co the sua.
    const isOwner = task.createdBy.toString() === req.userId.toString();
    const canEdit = isOwner || Boolean(await TaskShare.exists({
      taskId: task._id,
      userId: req.userId,
      permission: { $in: ['editor', 'edit'] }
    }));

    if (!canEdit) {
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

    const oldStatus = task.status;
    const oldDue = task.dueDate?.toISOString() || null;
    Object.assign(task, updates);
    await task.save();
    await activity(task._id, req.userId, 'updated', { fields: Object.keys(updates), status: task.status });
    if (Object.keys(updates).length) {
      const shares = await TaskShare.find({ taskId: task._id }).select('userId').lean();
      const recipients = [task.createdBy, ...(task.assigneeIds || []), ...shares.map(x => x.userId)];
      const completed = oldStatus !== 'completed' && task.status === 'completed';
      const dueChanged = Object.hasOwn(updates, 'dueDate') && oldDue !== (task.dueDate?.toISOString() || null);
      const title = completed ? 'Công việc đã hoàn thành' : 'Công việc đã được cập nhật';
      const message = completed ? `Công việc "${task.title}" đã hoàn thành.`
        : dueChanged ? `Hạn hoàn thành của "${task.title}" đã thay đổi.`
        : `Công việc "${task.title}" có thông tin mới.`;
      await safeEvent({ task, actorId: req.userId, recipients,
        type: completed ? 'task_completed' : 'task_updated', title, message });
    }

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
    await Task.deleteOne({ _id: taskId, createdBy: req.userId });
    await Promise.all([
      TaskShare.deleteMany({ taskId }),
      Notification.deleteMany({ taskId }),
      TaskActivity.deleteMany({ taskId })
    ]);
    // Email logs được giữ để tra cứu lịch sử gửi, dù công việc bị xóa.
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
    const oldAssigneeIds = new Set((task.assigneeIds || []).map(x => x.toString()));
    task.assigneeIds = users.map(user => user._id);
    task.primaryAssigneeId = primaryAssigneeId;

    await task.save();
    await activity(task._id, req.userId, 'assigned', { count: users.length, primaryEmail });
    const newlyAssigned = users.filter(u => !oldAssigneeIds.has(u._id.toString()));
    if (newlyAssigned.length) await safeEvent({ task, actorId: req.userId,
      recipients: newlyAssigned.map(u => u._id), type: 'task_assigned',
      title: 'Bạn được giao công việc mới',
      message: `Bạn đã được giao công việc: ${task.title}` });

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

    // Người tạo, người được giao hoặc được chia sẻ đều có quyền xem danh sách người thực hiện.
    const access = await accessFor(taskId, req.userId);
    if (!access || !access.canView) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền xem.'
      });
    }
    const task = access.task;

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

// BUOI 2: CHIA SE CONG VIEC CHO MOT HOAC NHIEU TAI KHOAN
// POST /api/tasks/:id/shares
router.post('/:id/shares', async (req, res, next) => {
  try {
    const taskId = req.params.id;
    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({ message: 'ID công việc không hợp lệ.' });
    }
    const task = await Task.findOne({ _id: taskId, createdBy: req.userId });
    if (!task) {
      return res.status(404).json({ message: 'Không tìm thấy công việc hoặc không có quyền chia sẻ.' });
    }
    const body = req.body || {};
    const permission = canonicalPermission(body.permission ?? 'viewer');
    if (!permission) return res.status(400).json({ message: 'Quyền phải là viewer hoặc editor.' });
    const emails = Array.isArray(body.emails) ? body.emails : [body.email];
    if (!emails.length || emails.length > 50 || emails.some(x =>
      typeof x !== 'string' || x.length > 254 ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(x.trim())
    )) {
      return res.status(400).json({ message: 'Cần từ 1 đến 50 email hợp lệ.' });
    }
    const normalizedEmails = [...new Set(emails.map(x => x.trim().toLowerCase()))];
    const users = await User.find({ email: { $in: normalizedEmails } })
      .select('_id fullName email').lean();
    const found = new Set(users.map(u => u.email));
    const missingEmails = normalizedEmails.filter(e => !found.has(e));
    if (missingEmails.length) {
      return res.status(400).json({ message: 'Email chưa đăng ký TaskManager.', missingEmails });
    }
    if (users.some(u => u._id.toString() === req.userId.toString())) {
      return res.status(400).json({ message: 'Không chia sẻ công việc cho chính mình.' });
    }

    const changes = [];
    for (const user of users) {
      const oldShare = await TaskShare.findOne({ taskId, userId: user._id }).lean();
      const share = await TaskShare.findOneAndUpdate(
        { taskId, userId: user._id },
        { $set: { permission, sharedBy: req.userId } },
        { new: true, upsert: true, runValidators: true }
      );
      changes.push(share);
      if (!oldShare || canonicalPermission(oldShare.permission) !== permission) {
        await activity(taskId, req.userId, 'shared', { userId: user._id.toString(), permission });
        await safeEvent({ task, actorId: req.userId, recipients: [user._id],
          type: 'task_shared', title: 'Bạn được chia sẻ công việc',
          message: `Bạn được mời ${permission === 'editor' ? 'chỉnh sửa' : 'xem'} công việc: ${task.title}` });
      }
    }
    return res.json({
      message: 'Chia sẻ công việc thành công.',
      shares: changes,
      share: changes[0] || null, // tương thích với ứng dụng cũ
      user: users[0] || null,
      users
    });
  } catch (err) { return next(err); }
});

// BUOI 2: XEM DANH SACH TAI KHOAN DUOC CHIA SE (CHI CHU SO HUU)
router.get('/:id/shares', async (req, res, next) => {
  try {
    const taskId = req.params.id;
    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({ message: 'ID công việc không hợp lệ.' });
    }

    const task = await Task.findOne({ _id: taskId, createdBy: req.userId });
    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền quản lý chia sẻ.'
      });
    }

    const shares = await TaskShare.find({ taskId })
      .populate('userId', 'fullName email')
      .sort({ createdAt: -1 })
      .lean();

    return res.json({ shares: shares.map(x => ({ ...x, permission: canonicalPermission(x.permission) })) });
  } catch (err) {
    return next(err);
  }
});

// BUOI 2: THU HOI QUYEN CHIA SE (CHI CHU SO HUU)
router.delete('/:id/shares/:shareId', async (req, res, next) => {
  try {
    const { id: taskId, shareId } = req.params;
    if (!mongoose.isValidObjectId(taskId) || !mongoose.isValidObjectId(shareId)) {
      return res.status(400).json({ message: 'ID không hợp lệ.' });
    }

    const task = await Task.findOne({ _id: taskId, createdBy: req.userId });
    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền thu hồi chia sẻ.'
      });
    }

    const deleted = await TaskShare.findOneAndDelete({ taskId, $or: [{ _id: shareId }, { userId: shareId }] });
    if (!deleted) {
      return res.status(404).json({ message: 'Không tìm thấy người được chia sẻ.' });
    }

    await activity(taskId, req.userId, 'share_revoked', { userId: deleted.userId.toString() });
    return res.json({ message: 'Thu hồi quyền chia sẻ thành công.' });
  } catch (err) {
    return next(err);
  }
});


// Quyền xem xét theo chủ công việc, được giao hoặc được chia sẻ.
async function accessFor(taskId, userId) {
  const task = await Task.findById(taskId);
  if (!task) return null;
  const owner = task.createdBy.toString() === userId.toString();
  const assigned = (task.assigneeIds || []).some(x => x.toString() === userId.toString());
  const share = await TaskShare.findOne({ taskId, userId }).select('permission').lean();
  return { task, owner, assigned, share, canView: owner || assigned || !!share,
    canEdit: owner || isEditor(share?.permission) };
}
router.patch('/:id/status', async (req, res, next) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'ID không hợp lệ.' });
    const access = await accessFor(req.params.id, req.userId);
    if (!access) return res.status(404).json({ message: 'Không tìm thấy công việc.' });
    if (!access.canEdit) return res.status(403).json({ message: 'Bạn không có quyền sửa.' });
    const status = req.body?.status;
    if (!['todo', 'in_progress', 'completed'].includes(status)) return res.status(400).json({ message: 'Trạng thái không hợp lệ.' });
    const previous = access.task.status;
    access.task.status = status;
    await access.task.save();
    await activity(access.task._id, req.userId, 'status_changed', { from: previous, to: status });
    const shares = await TaskShare.find({ taskId: access.task._id }).select('userId').lean();
    if (previous !== status) await safeEvent({ task: access.task, actorId: req.userId,
      recipients: [access.task.createdBy, ...access.task.assigneeIds, ...shares.map(s => s.userId)],
      type: status === 'completed' ? 'task_completed' : 'task_updated',
      title: status === 'completed' ? 'Công việc đã hoàn thành' : 'Trạng thái công việc thay đổi',
      message: `Trạng thái "${access.task.title}" đã thay đổi.` });
    res.json({ task: access.task });
  } catch (e) { next(e); }
});
router.get('/:id/activities', async (req, res, next) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'ID không hợp lệ.' });
    const access = await accessFor(req.params.id, req.userId);
    if (!access || !access.canView) return res.status(403).json({ message: 'Bạn không có quyền xem.' });
    const activities = await TaskActivity.find({ taskId: req.params.id })
      .populate('userId', 'fullName email').sort({ createdAt: -1 }).limit(100).lean();
    res.json({ activities });
  } catch (e) { next(e); }
});
router.get('/:id/email-logs', async (req, res, next) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(400).json({ message: 'ID không hợp lệ.' });
    const task = await Task.findOne({ _id: req.params.id, createdBy: req.userId });
    if (!task) return res.status(403).json({ message: 'Chỉ chủ công việc được xem lịch sử email.' });
    const logs = await EmailLog.find({ taskId: task._id })
      .select('-text').sort({ createdAt: -1 }).limit(100).lean();
    res.json({ logs });
  } catch (e) { next(e); }
});
router.patch('/:id/assignees/:userId', async (req, res, next) => {
  try {
    const { id, userId } = req.params;
    if (!mongoose.isValidObjectId(id) || !mongoose.isValidObjectId(userId)) return res.status(400).json({ message: 'ID không hợp lệ.' });
    const task = await Task.findOne({ _id: id, createdBy: req.userId });
    if (!task) return res.status(403).json({ message: 'Chỉ người tạo được chỉnh vai trò.' });
    if (!(task.assigneeIds || []).some(x => x.toString() === userId)) return res.status(404).json({ message: 'Người này chưa được giao.' });
    if (req.body?.primary !== true && req.body?.primary !== false) return res.status(400).json({ message: 'Cần primary kiểu true/false.' });
    task.primaryAssigneeId = req.body.primary ? userId : (task.primaryAssigneeId?.toString() === userId ? null : task.primaryAssigneeId);
    await task.save();
    await activity(id, req.userId, 'primary_changed', { userId, primary: req.body.primary });
    res.json({ task });
  } catch (e) { next(e); }
});
router.delete('/:id/assignees/:userId', async (req, res, next) => {
  try {
    const { id, userId } = req.params;
    if (!mongoose.isValidObjectId(id) || !mongoose.isValidObjectId(userId)) return res.status(400).json({ message: 'ID không hợp lệ.' });
    const task = await Task.findOne({ _id: id, createdBy: req.userId });
    if (!task) return res.status(403).json({ message: 'Chỉ người tạo được hủy giao việc.' });
    const originalLength = task.assigneeIds.length;
    task.assigneeIds = task.assigneeIds.filter(x => x.toString() !== userId);
    if (task.assigneeIds.length === originalLength) return res.status(404).json({ message: 'Người này chưa được giao.' });
    if (task.primaryAssigneeId?.toString() === userId) task.primaryAssigneeId = null;
    await task.save();
    await activity(id, req.userId, 'unassigned', { userId });
    res.json({ message: 'Đã hủy giao công việc.', task });
  } catch (e) { next(e); }
});
router.patch('/:id/shares/:shareId', async (req, res, next) => {
  try {
    const { id, shareId } = req.params;
    if (!mongoose.isValidObjectId(id) || !mongoose.isValidObjectId(shareId)) return res.status(400).json({ message: 'ID không hợp lệ.' });
    const task = await Task.findOne({ _id: id, createdBy: req.userId });
    if (!task) return res.status(403).json({ message: 'Chỉ chủ công việc được sửa quyền.' });
    const permission = canonicalPermission(req.body?.permission);
    if (!permission) return res.status(400).json({ message: 'Quyền phải là viewer hoặc editor.' });
    const share = await TaskShare.findOneAndUpdate({ _id: shareId, taskId: id }, { $set: { permission } }, { new: true });
    if (!share) return res.status(404).json({ message: 'Không tìm thấy bản ghi chia sẻ.' });
    await activity(id, req.userId, 'share_permission_changed', { userId: share.userId, permission: share.permission });
    await safeEvent({ task, actorId: req.userId, recipients: [share.userId], type: 'task_shared',
      title: 'Quyền chia sẻ đã thay đổi', message: `Quyền truy cập "${task.title}" của bạn đã thay đổi.` });
    res.json({ share });
  } catch (e) { next(e); }
});
module.exports = router;
