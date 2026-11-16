const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  taskId: { type: mongoose.Schema.Types.ObjectId, ref: 'Task', required: true, index: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  sharedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  permission: { type: String, enum: ['viewer', 'editor', 'view', 'edit'], default: 'viewer' }
}, { timestamps: true, collection: 'task_shares' });
schema.index({ taskId: 1, userId: 1 }, { unique: true });
module.exports = mongoose.model('TaskShare', schema);
