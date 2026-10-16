class Item {
  const Item({
    this.id,
    required this.name,
    this.code,
    this.category,
    required this.stockTotal,
    required this.stockAvailable,
    this.note,
  });

  factory Item.fromMap(Map<String, Object?> map) => Item(
        id: map['id'] as int?,
        name: map['name'] as String,
        code: map['code'] as String?,
        category: map['category'] as String?,
        stockTotal: map['stock_total'] as int,
        stockAvailable: map['stock_available'] as int,
        note: map['note'] as String?,
      );

  final int? id;
  final String name;
  final String? code;
  final String? category;
  final int stockTotal;
  final int stockAvailable;
  final String? note;

  /// Units currently out on loan. Derived, so it cannot drift from the two columns.
  int get borrowed => stockTotal - stockAvailable;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'code': code,
        'category': category,
        'stock_total': stockTotal,
        'stock_available': stockAvailable,
        'note': note,
      };

  Item copyWith({
    int? id,
    String? name,
    String? code,
    String? category,
    int? stockTotal,
    int? stockAvailable,
    String? note,
  }) =>
      Item(
        id: id ?? this.id,
        name: name ?? this.name,
        code: code ?? this.code,
        category: category ?? this.category,
        stockTotal: stockTotal ?? this.stockTotal,
        stockAvailable: stockAvailable ?? this.stockAvailable,
        note: note ?? this.note,
      );
}
