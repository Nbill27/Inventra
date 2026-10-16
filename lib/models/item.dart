class Item {
  const Item({
    this.id,
    this.noUrut,
    required this.name,
    this.code,
    this.range,
    this.brand,
    this.pic,
    this.status,
    required this.stockTotal,
    required this.stockAvailable,
  });

  factory Item.fromMap(Map<String, Object?> map) => Item(
        id: map['id'] as int?,
        noUrut: map['no_urut'] as String?,
        name: map['name'] as String,
        code: map['code'] as String?,
        // `range` is a SQLite keyword, so the column is named `range_text`.
        range: map['range_text'] as String?,
        brand: map['brand'] as String?,
        pic: map['pic'] as String?,
        status: map['status'] as String?,
        stockTotal: map['stock_total'] as int,
        stockAvailable: map['stock_available'] as int,
      );

  final int? id;

  /// The `NO` column of the master file.
  final String? noUrut;
  final String name;
  final String? code;
  final String? range;
  final String? brand;

  /// Person in charge of the tool, from the file's `PIC` column.
  final String? pic;
  final String? status;
  final int stockTotal;
  final int stockAvailable;

  /// Units currently out on loan. Derived, so it cannot drift from the two columns.
  int get borrowed => stockTotal - stockAvailable;

  Map<String, Object?> toMap() => {
        'id': id,
        'no_urut': noUrut,
        'name': name,
        'code': code,
        'range_text': range,
        'brand': brand,
        'pic': pic,
        'status': status,
        'stock_total': stockTotal,
        'stock_available': stockAvailable,
      };

  Item copyWith({
    int? id,
    String? noUrut,
    String? name,
    String? code,
    String? range,
    String? brand,
    String? pic,
    String? status,
    int? stockTotal,
    int? stockAvailable,
  }) =>
      Item(
        id: id ?? this.id,
        noUrut: noUrut ?? this.noUrut,
        name: name ?? this.name,
        code: code ?? this.code,
        range: range ?? this.range,
        brand: brand ?? this.brand,
        pic: pic ?? this.pic,
        status: status ?? this.status,
        stockTotal: stockTotal ?? this.stockTotal,
        stockAvailable: stockAvailable ?? this.stockAvailable,
      );
}
