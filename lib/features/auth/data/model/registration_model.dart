class RegistrationModel {
  final String uid;
  final String email;

  RegistrationModel({
    required this.uid,
    required this.email,
  });

  Map<String, dynamic> toJson() {
    return {
      "uid": uid,
      "email": email,
    };
  }
}
