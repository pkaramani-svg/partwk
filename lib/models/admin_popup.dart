import '../core/utils/safe_parser.dart';

class AdminPopup {
  final String id;
  final Map<String, String> title;
  final Map<String, String> body;
  final String type; // info, update, warning, promotion, new_book, subscription, maintenance
  final String status; // draft, active, paused
  final String priority; // normal, important, urgent
  final String frequency; // once, every_open, once_daily, weekly, until_dismissed
  final String? imageUrl;
  final String? actionUrl;
  final Map<String, String> actionText;
  final PopupScheduling scheduling;
  final PopupTargeting targeting;
  final String createdAt;
  final String updatedAt;

  AdminPopup({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.status,
    required this.priority,
    required this.frequency,
    this.imageUrl,
    this.actionUrl,
    required this.actionText,
    required this.scheduling,
    required this.targeting,
    required this.createdAt,
    required this.updatedAt,
  });

  String getLocalizedTitle(String langCode) => title[langCode] ?? title['en'] ?? '';
  String getLocalizedBody(String langCode) => body[langCode] ?? body['en'] ?? '';
  String getLocalizedActionText(String langCode) => actionText[langCode] ?? actionText['en'] ?? 'Open Link';

  factory AdminPopup.fromMap(String id, Map<String, dynamic> data) {
    return AdminPopup(
      id: id,
      title: SafeParser.asMapStringString(data['title']),
      body: SafeParser.asMapStringString(data['body']),
      type: data['type'] ?? 'info',
      status: data['status'] ?? 'draft',
      priority: data['priority'] ?? 'normal',
      frequency: data['frequency'] ?? 'once',
      imageUrl: data['imageUrl'] as String?,
      actionUrl: data['actionUrl'] as String?,
      actionText: SafeParser.asMapStringString(data['actionText']),
      scheduling: PopupScheduling.fromMap(data['scheduling'] as Map<String, dynamic>? ?? {}),
      targeting: PopupTargeting.fromMap(data['targeting'] as Map<String, dynamic>? ?? {}),
      createdAt: data['createdAt'] ?? '',
      updatedAt: data['updatedAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'status': status,
      'priority': priority,
      'frequency': frequency,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
      'actionText': actionText,
      'scheduling': scheduling.toMap(),
      'targeting': targeting.toMap(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class PopupScheduling {
  final String? startDate;
  final String? endDate;

  PopupScheduling({this.startDate, this.endDate});

  factory PopupScheduling.fromMap(Map<String, dynamic> data) {
    return PopupScheduling(
      startDate: data['startDate'] as String?,
      endDate: data['endDate'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}

class PopupTargeting {
  final List<String> languages;
  final List<String> userTypes;
  final List<String> countries;
  final List<String> platforms;
  final List<String> appVersions;
  final List<String> emails;
  final List<String> userIds;

  PopupTargeting({
    required this.languages,
    required this.userTypes,
    required this.countries,
    required this.platforms,
    required this.appVersions,
    required this.emails,
    required this.userIds,
  });

  factory PopupTargeting.fromMap(Map<String, dynamic> data) {
    return PopupTargeting(
      languages: _parseList(data['languages']) ?? ['en', 'ku', 'ar'],
      userTypes: _parseList(data['userTypes']) ?? [],
      countries: _parseList(data['countries']) ?? [],
      platforms: _parseList(data['platforms']) ?? [],
      appVersions: _parseList(data['appVersions']) ?? [],
      emails: _parseList(data['emails']) ?? [],
      userIds: _parseList(data['userIds']) ?? [],
    );
  }

  static List<String>? _parseList(dynamic val) {
    if (val == null) return null;
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'languages': languages,
      'userTypes': userTypes,
      'countries': countries,
      'platforms': platforms,
      'appVersions': appVersions,
      'emails': emails,
      'userIds': userIds,
    };
  }
}
