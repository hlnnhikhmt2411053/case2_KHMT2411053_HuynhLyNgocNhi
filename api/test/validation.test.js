const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeEmail, validEmail, uniqueEmails } = require('../src/utils/validation');
test('Chuẩn hóa email', () => {
  assert.equal(normalizeEmail('  TEST@Example.COM '), 'test@example.com');
});
test('Kiểm tra email hợp lệ', () => {
  assert.equal(validEmail('abc@example.com'), true);
  assert.equal(validEmail('abc@@example.com'), false);
  assert.equal(validEmail(''), false);
});
test('Loại bỏ email trùng nhau', () => {
  assert.deepEqual(uniqueEmails([' A@x.com ', 'a@x.com', 'b@x.com']), ['a@x.com', 'b@x.com']);
});
