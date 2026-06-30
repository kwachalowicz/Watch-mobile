class AppUser {
  final String id;
  final String email;
  final String? name;

  AppUser({required this.id, required this.email, this.name});

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String?,
      );
}
