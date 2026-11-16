const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const EmailLog = require('../models/EmailLog');
const User = require('../models/User');
const { safeEvent } = require('./messaging');

// Mở rộng Buổi 3: nhắc việc 24 giờ trước hạn.
// Khởi động bằng ENABLE_REMINDERS=true, mỗi lượt kiểm tra cách nhau 30 phút.
// EmailLog chống gửi lặp trong cùng 24 giờ cho cùng task/recipient.
async function remindDueSoon() {
  const now = new Date();
  const limit = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const tasks = await Task.find({ status: { $ne: 'completed' },
    dueDate: { $gte: now, $lte: limit } }).limit(500).lean();
  for (const task of tasks) {
    const shares = await TaskShare.find({ taskId: task._id }).select('userId').lean();
    const ids = [...new Set([
      ...task.assigneeIds.map(x => x.toString()),
      ...shares.map(x => x.userId.toString())
    ])].filter(x => x !== task.createdBy.toString());
    const users = await User.find({ _id: { $in: ids } }).select('_id email').lean();
    for (const user of users) {
      const exists = await EmailLog.exists({ taskId: task._id,
        recipientEmail: user.email, eventType: 'due_reminder',
        createdAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) } });
      if (exists) continue;
      await safeEvent({ task, actorId: task.createdBy,
        recipients: [user._id], type: 'due_reminder',
        title: 'Nhắc hạn hoàn thành công việc',
        message: `Công việc "${task.title}" sẽ đến hạn trong 24 giờ.` });
    }
  }
}
function startReminders() {
  if (process.env.ENABLE_REMINDERS !== 'true') return;
  async function check() {
    try { await remindDueSoon(); }
    catch (e) { console.error('Kiểm tra hạn hoàn thành thất bại:', e.message); }
  }
  void check();
  setInterval(check, 30 * 60 * 1000).unref();
}
module.exports = { startReminders, remindDueSoon };
