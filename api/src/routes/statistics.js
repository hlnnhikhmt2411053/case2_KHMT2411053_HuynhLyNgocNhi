const router = require('express').Router();
const mongoose = require('mongoose');
const auth = require('../middleware/auth');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
router.use(auth);
async function accessible(req) {
  const id = new mongoose.Types.ObjectId(req.userId);
  const shares = await TaskShare.find({ userId: id }).select('taskId').lean();
  return Task.find({ $or: [
    { createdBy: id }, { assigneeIds: id }, { _id: { $in: shares.map(s => s.taskId) } }
  ] }).select('status dueDate createdBy assigneeIds primaryAssigneeId').lean();
}
router.get('/tasks', async (req, res, next) => {
  try {
    const tasks = await accessible(req);
    const byStatus = { todo: 0, in_progress: 0, completed: 0 };
    for (const t of tasks) byStatus[t.status] = (byStatus[t.status] || 0) + 1;
    res.json({ total: tasks.length, byStatus });
  } catch (e) { next(e); }
});
router.get('/assignments', async (req, res, next) => {
  try {
    const tasks = await accessible(req);
    const id = req.userId;
    res.json({
      created: tasks.filter(t => t.createdBy.toString() === id).length,
      assigned: tasks.filter(t => (t.assigneeIds || []).some(x => x.toString() === id)).length,
      primary: tasks.filter(t => t.primaryAssigneeId?.toString() === id).length
    });
  } catch (e) { next(e); }
});
router.get('/deadlines', async (req, res, next) => {
  try {
    const tasks = await accessible(req);
    const now = Date.now();
    const soon = now + 24 * 60 * 60 * 1000;
    res.json({
      overdue: tasks.filter(t => t.status !== 'completed' && t.dueDate && t.dueDate.getTime() < now).length,
      dueSoon: tasks.filter(t => t.status !== 'completed' && t.dueDate && t.dueDate.getTime() >= now && t.dueDate.getTime() <= soon).length
    });
  } catch (e) { next(e); }
});
module.exports = router;
