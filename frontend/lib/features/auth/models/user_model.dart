class UserPreferences {
  final List<String> pinnedModules;
  final List<String> moduleOrder;
  final bool largeText;

  UserPreferences({
    required this.pinnedModules,
    required this.moduleOrder,
    required this.largeText,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      pinnedModules: List<String>.from(json['pinnedModules'] ?? ['boat_receipts']),
      moduleOrder: List<String>.from(json['moduleOrder'] ?? ['boat_receipts', 'games']),
      largeText: json['largeText'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pinnedModules': pinnedModules,
      'moduleOrder': moduleOrder,
      'largeText': largeText,
    };
  }
}

class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String role;
  final UserPreferences preferences;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.preferences,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? 'Mẹ',
      role: json['role'] ?? 'user',
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'])
          : UserPreferences(pinnedModules: ['boat_receipts'], moduleOrder: ['boat_receipts', 'games'], largeText: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'role': role,
      'preferences': preferences.toJson(),
    };
  }
}
