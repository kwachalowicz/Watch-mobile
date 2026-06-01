import 'package:objectbox/objectbox.dart';

@Entity()
class RawTelemetry {
  @Id()
  int id = 0;

  double accelX;
  double accelY;
  double accelZ;

  double magX;
  double magY;
  double magZ;

  RawTelemetry({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.magX,
    required this.magY,
    required this.magZ,
  });
}
