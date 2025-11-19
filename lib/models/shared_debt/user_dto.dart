// lib/models/shared_debt/user_dto.dart

class UserDto {
  final int id;
  final String name;
  final String email;
  final String debtId;

  UserDto({
    required this.id,
    required this.name,
    required this.email,
    required this.debtId,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      debtId: json['debtId'],
    );
  }
}