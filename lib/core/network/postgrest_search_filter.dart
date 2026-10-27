/// Builds a PostgREST `or` filter that matches [search] in any of [columns].
///
/// The search text is wrapped in double quotes so commas, dots, colons, and
/// parentheses typed by the user stay part of the value instead of being read
/// as filter syntax (which would break or extend the query).
String ilikeAnyColumnFilter(List<String> columns, String search) {
  final escaped = '%$search%'.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  final value = '"$escaped"';
  return columns.map((column) => '$column.ilike.$value').join(',');
}
