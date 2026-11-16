const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  taskId: { type: mongoose.Schema.Types.ObjectId, ref: 'Task', default: null },
  recipientEmail: { type: String, required: true, trim: true, lowercase: true },
  eventType: { type: String, required: true },
  subject: { type: String, required: true },
  text: { type: String, required: true, select: false },
  status: { type: String, enum: ['pending', 'sent', 'failed'], default: 'pending' },
  attempts: { type: Number, default: 0 },
  errorMessage: { type: String, default: '' },
  sentAt: { type: Date, default: null }
}, { timestamps: true, collection: 'email_logs' });
schema.index({ taskId: 1, createdAt: -1 });
module.exports = mongoose.model('EmailLog', schema);
