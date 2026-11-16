const nodemailer = require('nodemailer');
const Notification = require('../models/Notification');
const EmailLog = require('../models/EmailLog');
const TaskActivity = require('../models/TaskActivity');
const User = require('../models/User');
let transporter;

const smtpConfigured = () => Boolean(
  process.env.SMTP_HOST && process.env.SMTP_USER &&
  process.env.SMTP_PASS && process.env.SMTP_FROM
);
function mailer() {
  if (!transporter) transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: String(process.env.SMTP_SECURE || 'false') === 'true',
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
  });
  return transporter;
}
async function sendEmailLog(log) {
  if (!smtpConfigured()) {
    // Không giả vờ gửi thành công khi chưa cấu hình SMTP.
    log.status = 'pending';
    log.errorMessage = 'SMTP chưa được cấu hình trong .env';
    await log.save();
    return;
  }
  try {
    log.attempts += 1;
    await mailer().sendMail({
      from: process.env.SMTP_FROM,
      to: log.recipientEmail,
      subject: log.subject,
      text: log.text
    });
    log.status = 'sent';
    log.sentAt = new Date();
    log.errorMessage = '';
  } catch (error) {
    log.status = 'failed';
    log.errorMessage = String(error.message || error).slice(0, 300);
    console.error('SMTP send failed:', log.errorMessage);
  }
  await log.save();
}
async function emitEvent({ task, actorId, recipients, type, title, message, emailEvent }) {
  const ids = [...new Set(recipients.map(x => x.toString()))]
    .filter(x => x !== actorId.toString());
  if (!ids.length) return;
  // Thông báo trong app được ghi trước và độc lập với SMTP.
  await Notification.insertMany(ids.map(userId => ({
    userId, taskId: task._id, type, title, message
  })));
  const users = await User.find({ _id: { $in: ids } }).select('email').lean();
  for (const user of users) {
    const log = await EmailLog.create({
      taskId: task._id, recipientEmail: user.email,
      eventType: emailEvent || type, subject: title, text: message
    });
    await sendEmailLog(log);
  }
}
async function activity(taskId, userId, action, details = {}) {
  try { await TaskActivity.create({ taskId, userId, action, details }); }
  catch (error) { console.error('Ghi lịch sử thất bại:', error.message); }
}
async function safeEvent(data) {
  try { await emitEvent(data); }
  catch (error) { console.error('Ghi/gửi thông báo thất bại:', error.message); }
}
module.exports = { sendEmailLog, smtpConfigured, safeEvent, activity };
