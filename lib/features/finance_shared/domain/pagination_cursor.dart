/// Offset/limit pagination for bounded finance list RPCs.
class PaginationCursor {
  const PaginationCursor({this.offset = 0, this.limit = 50});

  final int offset;
  final int limit;

  PaginationCursor nextPage() =>
      PaginationCursor(offset: offset + limit, limit: limit);

  bool get isFirstPage => offset == 0;
}
