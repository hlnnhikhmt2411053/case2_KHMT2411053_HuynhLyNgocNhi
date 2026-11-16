const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
function normalizeEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}
function validEmail(value) {
  const v = normalizeEmail(value);
  return v.length <= 254 && emailPattern.test(v);
}
function uniqueEmails(values) {
  if (!Array.isArray(values)) return [];
  return [...new Set(values.map(normalizeEmail))];
}
module.exports = { normalizeEmail, validEmail, uniqueEmails };
