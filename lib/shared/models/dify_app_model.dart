// Dify应用模型
class DifyApp {
  final String id;
  final String name;
  final String description;
  final String? icon;
  final String? type;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DifyApp({
    required this.id,
    required this.name,
    required this.description,
    this.icon,
    this.type,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DifyApp.fromJson(Map<String, dynamic> json) {
    return DifyApp(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String?,
      type: json['type'] as String?,
      enabled: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'type': type,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

// Dify应用列表响应模型
class DifyAppsResponse {
  final bool success;
  final String message;
  final List<DifyApp> data;
  final int? code;

  const DifyAppsResponse({
    required this.success,
    required this.message,
    required this.data,
    this.code,
  });

  factory DifyAppsResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    final apps = dataList
        .map((item) => DifyApp.fromJson(item as Map<String, dynamic>))
        .toList();

    return DifyAppsResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: apps,
      code: json['code'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data.map((app) => app.toJson()).toList(),
      'code': code,
    };
  }
}