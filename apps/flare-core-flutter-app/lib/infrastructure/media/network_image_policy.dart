/// 仅当 URL 为 `http`/`https` 时使用 [CachedNetworkImage] / [CachedNetworkImageProvider]，
/// 避免把 Tauri 开发路径（如 `/src/assets/...`）交给 HTTP 客户端导致 [ArgumentError]。
bool isHttpOrHttpsUrl(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return false;
  final uri = Uri.tryParse(s);
  if (uri == null || !uri.hasScheme) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}

bool isLocalFileLikePath(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return false;
  if (s.startsWith('/')) return true;
  if (s.startsWith('file://')) return true;
  final uri = Uri.tryParse(s);
  if (uri == null) return false;
  if (uri.scheme == 'file') return true;
  return false;
}
