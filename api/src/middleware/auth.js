const jwt = require('jsonwebtoken');
module.exports = function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const match = /^Bearer (.+)$/i.exec(header);
  if (!match) return res.status(401).json({ message: 'Vui lòng đăng nhập.' });
  try {
    const payload = jwt.verify(match[1], process.env.JWT_SECRET, { algorithms: ['HS256'] });
    req.userId = payload.sub;
    return next();
  } catch (_) {
    return res.status(401).json({ message: 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.' });
  }
};
