/// A Spotify "paging object" — a paginated list response.
class Paging<T> {
  final List<T> items;
  final int total;
  final int limit;
  final int offset;
  final String? next;
  final String? previous;

  const Paging({
    required this.items,
    this.total = 0,
    this.limit = 0,
    this.offset = 0,
    this.next,
    this.previous,
  });

  factory Paging.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final rawItems = (json['items'] as List?) ?? const [];
    return Paging<T>(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(parse)
          .toList(),
      total: json['total'] as int? ?? rawItems.length,
      limit: json['limit'] as int? ?? rawItems.length,
      offset: json['offset'] as int? ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
    );
  }

  bool get hasMore => next != null;

  static Paging<T> empty<T>() => Paging<T>(items: const []);
}
