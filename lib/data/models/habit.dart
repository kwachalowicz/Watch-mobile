import 'package:objectbox/objectbox.dart';

/// Definicja nawyku. Single source of truth żyje w aplikacji - apka pushuje
/// definicje na zegarek, zegarek raportuje wykonania z powrotem.
@Entity()
class Habit {
  @Id()
  int id = 0;

  /// Stabilne UUID (v4) - używane do synchronizacji z zegarkiem.
  /// Zegarek odsyła to ID przy raportowaniu wykonania, więc musi przetrwać
  /// re-instalacje i być wspólne między urządzeniami.
  @Unique()
  String uuid;

  String name;

  /// Krótka nazwa (do 12 znaków) wyświetlana na zegarku.
  /// Bangle.js 2 ma 176px szerokości - długie nazwy się nie zmieszczą.
  String shortName;

  /// Ikona/emoji dla apki. Na zegarku osobno - tam mamy własne bitmapy.
  String? icon;

  /// Kolejność wyświetlania na liście checkboxów.
  int order;

  /// Czy nawyk jest aktywny. Soft delete = isActive=false + zachowana historia.
  bool isActive;

  /// Kiedy stworzony / ostatnio edytowany - do conflict resolution przy syncu.
  @Property(type: PropertyType.date)
  DateTime createdAt;
  @Property(type: PropertyType.date)
  DateTime updatedAt;

  /// Wersja schematu - rośnie przy każdej edycji w apce.
  /// Zegarek sprawdza wersję i pyta o nowy stan jeśli ma starszą.
  @Index()
  int version;

  Habit({
    this.id = 0,
    required this.uuid,
    required this.name,
    required this.shortName,
    this.icon,
    required this.order,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });
}
