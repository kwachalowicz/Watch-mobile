import 'dart:typed_data';
import 'package:objectbox/objectbox.dart';
import 'raw_telemetry.dart';
import 'error_log.dart';
import 'package:watch_me/objectbox.g.dart';

class ObjectBoxGateway {
  late final Store store;
  late final Box<RawTelemetry> telemetryBox;
  late final Box<ErrorLog> errorLogBox;

  ObjectBoxGateway._create(this.store) {
    telemetryBox = Box<RawTelemetry>(store);
    errorLogBox = Box<ErrorLog>(store);
  }

  static Future<ObjectBoxGateway> create() async {
    final store = await openStore();
    return ObjectBoxGateway._create(store);
  }

  ObjectBoxGateway.fromReference(ByteData referenceByteData) {
    store = Store.fromReference(getObjectBoxModel(), referenceByteData);
    telemetryBox = Box<RawTelemetry>(store);
    errorLogBox = Box<ErrorLog>(store);
  }
}