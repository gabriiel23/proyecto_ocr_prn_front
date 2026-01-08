class DetailCategory {
  final String id;
  final String title;
  final String icon;
  final String status;
  final int recordCount;
  final List<Record>? records;

  DetailCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.status,
    required this.recordCount,
    this.records,
  });
}

class Record {
  final String title;
  final String description;
  final String date;
  final String? amount;
  final String? status;

  Record({
    required this.title,
    required this.description,
    required this.date,
    this.amount,
    this.status,
  });
}
