import 'package:objectbox/objectbox.dart';

@Entity()
class AuthSession {
  @Id()
  int id = 0;

  int? userId;

  AuthSession({this.id = 0, this.userId});
}
