import 'package:objectbox/objectbox.dart';

@Entity()
class AppUser {
  @Id()
  int id = 0;

  @Unique()
  String email;

  String passwordHash;

  String? name;

  AppUser({
    this.id = 0,
    required this.email,
    required this.passwordHash,
    this.name,
  });
}
