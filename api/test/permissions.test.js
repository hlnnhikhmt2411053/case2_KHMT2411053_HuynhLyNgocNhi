const test = require('node:test');
const assert = require('node:assert/strict');
const { canonicalPermission, isEditor } = require('../src/utils/permissions');
test('Quyen viewer/editor theo de', () => {
  assert.equal(canonicalPermission('viewer'), 'viewer');
  assert.equal(canonicalPermission('editor'), 'editor');
  assert.equal(isEditor('viewer'), false);
  assert.equal(isEditor('editor'), true);
});
test('Du lieu quyen view/edit cu van hoat dong', () => {
  assert.equal(canonicalPermission('view'), 'viewer');
  assert.equal(canonicalPermission('edit'), 'editor');
  assert.equal(isEditor('edit'), true);
  assert.equal(canonicalPermission('invalid'), null);
});
