const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  taskId: { type: mongoose.Schema.Types.ObjectId, ref: 'Task', default: null },
  type: { type: String, enum: ['task_assigned', 'task_shared', 'task_updated', 'task_completed', 'due_reminder'], required: true },
  title: { type: String, trim: true, required: true },
  message: { type: String, trim: true, required: true },
  isRead: { type: Boolean, default: false }
}, { timestamps: true, collection: 'notifications' });
schema.index({ userId: 1, createdAt: -1 });
module.exports = mongoose.model('Notification', schema);
