import 'package:flutter/widgets.dart';

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

// Clase para los datos de servicio
class ServiceData {
  final String type;
  final bool success;
  final dynamic data;
  final String? error;
  final String? message;

  ServiceData({
    required this.type,
    required this.success,
    this.data,
    this.error,
    this.message,
  });
}

// Clase para los pagos pendientes
class PendingPayment {
  final String id;
  final String title;
  final IconData icon;
  final String amount;
  final String dueDate;
  final String status;
  final String serviceType;

  PendingPayment({
    required this.id,
    required this.title,
    required this.icon,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.serviceType,
  });
}
