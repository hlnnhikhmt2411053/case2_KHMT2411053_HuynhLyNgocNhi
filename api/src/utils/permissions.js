// De yeu cau viewer/editor; du lieu Buoi 2 cu co the luu view/edit.
// Chuyen de doc duoc du lieu cu va luu chuan moi trong cac thao tac moi.
function canonicalPermission(value) {
  if (value === 'viewer' || value === 'view') return 'viewer';
  if (value === 'editor' || value === 'edit') return 'editor';
  return null;
}
function isEditor(value) { return canonicalPermission(value) === 'editor'; }
module.exports = { canonicalPermission, isEditor };
