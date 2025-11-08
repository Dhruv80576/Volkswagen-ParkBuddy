class UserModel {
  final String name;
  final String email;
  final String phone;
  final String carBrand;
  final String carModel;
  final String carNumber;
  final String carColor;

  UserModel({
    required this.name,
    required this.email,
    required this.phone,
    required this.carBrand,
    required this.carModel,
    required this.carNumber,
    required this.carColor,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'carBrand': carBrand,
      'carModel': carModel,
      'carNumber': carNumber,
      'carColor': carColor,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      carBrand: json['carBrand'] ?? '',
      carModel: json['carModel'] ?? '',
      carNumber: json['carNumber'] ?? '',
      carColor: json['carColor'] ?? '',
    );
  }
}
