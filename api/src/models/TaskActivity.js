const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  taskId: { type: mongoose.Schema.Types.ObjectId, ref: 'Task', required: true, index: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  action: { type: String, required: true },
  details: { type: mongoose.Schema.Types.Mixed, default: {} }
}, { timestamps: true, collection: 'task_activities' });
schema.index({ taskId: 1, createdAt: -1 });
module.exports = mongoose.model('TaskActivity', schema);
