import 'package:objectbox/objectbox.dart';

@Entity()
class ErrorLog {
  @Id()
  int id = 0;

  String message;
  String stackTrace;
  
  @Property(type: PropertyType.dateUtc)
  DateTime timestamp;
  
  String severity; // e.g., 'WARNING', 'CRITICAL'

  ErrorLog({
    required this.message,
    required this.stackTrace,
    required this.timestamp,
    required this.severity,
  });
}