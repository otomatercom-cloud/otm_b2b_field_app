import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around the otm_b2b_mobile_api Odoo module's REST endpoints.
/// Every call sends the saved device token in the X-Mobile-Token header.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static const _kBaseUrl = 'base_url';
  static const _kToken = 'token';
  static const _kUserName = 'user_name';
  static const _kIsManager = 'is_manager';
  static const _kIsHead = 'is_head';

  String? baseUrl;
  String? token;
  String? userName;
  bool isManager = false;
  bool isHead = false;

  static final ApiClient instance = ApiClient._internal();
  ApiClient._internal();

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_kBaseUrl);
    token = prefs.getString(_kToken);
    userName = prefs.getString(_kUserName);
    isManager = prefs.getBool(_kIsManager) ?? false;
    isHead = prefs.getBool(_kIsHead) ?? false;
  }

  bool get isLoggedIn => token != null && baseUrl != null;

  Uri _uri(String path, [Map<String, String>? query]) {
    final url = baseUrl!.endsWith('/') ? baseUrl!.substring(0, baseUrl!.length - 1) : baseUrl!;
    return Uri.parse('$url$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'X-Mobile-Token': token!,
      };

  Future<Map<String, dynamic>> _handle(http.Response resp) async {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Unexpected server response (${resp.statusCode}).');
    }
    if (body['success'] == true) {
      return (body['data'] as Map?)?.cast<String, dynamic>() ?? {};
    }
    throw ApiException(body['error']?.toString() ?? 'Request failed.');
  }

  Future<void> login({
    required String serverUrl,
    required String db,
    required String login,
    required String password,
  }) async {
    baseUrl = serverUrl.trim();
    if (!baseUrl!.toLowerCase().startsWith('https://')) {
      throw ApiException('Server must use https:// for a secure login.');
    }
    final resp = await http.post(
      _uri('/otm_b2b/mobile/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'db': db, 'login': login, 'password': password, 'device': 'flutter-app'}),
    );
    final data = await _handle(resp);
    token = data['token'] as String;
    userName = data['name'] as String?;
    isManager = data['is_manager'] == true;
    isHead = data['is_head'] == true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, baseUrl!);
    await prefs.setString(_kToken, token!);
    await prefs.setString(_kUserName, userName ?? '');
    await prefs.setBool(_kIsManager, isManager);
    await prefs.setBool(_kIsHead, isHead);
  }

  Future<void> logout() async {
    if (token != null && baseUrl != null) {
      try {
        await http.post(_uri('/otm_b2b/mobile/logout'), headers: _headers, body: jsonEncode({}));
      } catch (_) {
        // best-effort - clear local session regardless
      }
    }
    token = null;
    baseUrl = null;
    userName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final resp = await http.get(_uri('/otm_b2b/mobile/dashboard'), headers: _headers);
    return _handle(resp);
  }

  Future<List<dynamic>> getVisits({String scope = 'today'}) async {
    final resp = await http.get(_uri('/otm_b2b/mobile/visits', {'scope': scope}), headers: _headers);
    final data = await _handle(resp);
    return data['visits'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> searchInstitutions({String q = '', bool highPriorityOnly = false}) async {
    final resp = await http.get(
      _uri('/otm_b2b/mobile/institutions', {
        'q': q,
        if (highPriorityOnly) 'high_priority': '1',
      }),
      headers: _headers,
    );
    final data = await _handle(resp);
    return data['institutions'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getInstitutionContacts(int institutionId) async {
    final resp = await http.get(_uri('/otm_b2b/mobile/institution/$institutionId/contacts'), headers: _headers);
    final data = await _handle(resp);
    return data['contacts'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getActivityTypes() async {
    final resp = await http.get(_uri('/otm_b2b/mobile/activity_types'), headers: _headers);
    final data = await _handle(resp);
    return data['activity_types'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> checkIn({
    required int planId,
    double? latitude,
    double? longitude,
  }) async {
    final resp = await http.post(
      _uri('/otm_b2b/mobile/visit/checkin'),
      headers: _headers,
      body: jsonEncode({'plan_id': planId, 'latitude': latitude, 'longitude': longitude}),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> checkOut({
    required int visitRecordId,
    double? latitude,
    double? longitude,
  }) async {
    final resp = await http.post(
      _uri('/otm_b2b/mobile/visit/checkout'),
      headers: _headers,
      body: jsonEncode({'visit_record_id': visitRecordId, 'latitude': latitude, 'longitude': longitude}),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> completeVisit({
    int? planId,
    int? visitRecordId,
    int? activityTypeId,
    required String remarks,
    String? nextAction,
    String? nextFollowupDate,
    List<int> contactIds = const [],
    List<Map<String, String>> newContacts = const [],
    double? latitude,
    double? longitude,
  }) async {
    final resp = await http.post(
      _uri('/otm_b2b/mobile/visit/complete'),
      headers: _headers,
      body: jsonEncode({
        if (planId != null) 'plan_id': planId,
        if (visitRecordId != null) 'visit_record_id': visitRecordId,
        if (activityTypeId != null) 'activity_type_id': activityTypeId,
        'remarks': remarks,
        'next_action': nextAction,
        'next_followup_date': nextFollowupDate,
        'contact_ids': contactIds,
        'new_contacts': newContacts,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final resp = await http.post(_uri(path), headers: _headers, body: jsonEncode(body));
    return _handle(resp);
  }

  Future<List<dynamic>> getSeminars({String scope = 'today'}) async {
    final resp = await http.get(_uri('/otm_b2b/mobile/seminars', {'scope': scope}), headers: _headers);
    final data = await _handle(resp);
    return data['seminars'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> seminarCheckIn(int planId, double lat, double lng) =>
      _post('/otm_b2b/mobile/seminar/checkin', {'plan_id': planId, 'latitude': lat, 'longitude': lng});

  Future<Map<String, dynamic>> seminarCheckOut(int seminarId, {double? lat, double? lng}) =>
      _post('/otm_b2b/mobile/seminar/checkout', {'seminar_id': seminarId, 'latitude': lat, 'longitude': lng});

  Future<Map<String, dynamic>?> getCurrentTrip() async {
    final resp = await http.get(_uri('/otm_b2b/mobile/trip/current'), headers: _headers);
    final data = await _handle(resp);
    return (data['trip'] as Map?)?.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> _tripCall(String path, Map<String, dynamic> body) async {
    final data = await _post(path, body);
    return (data['trip'] as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> startTrip(double meter) =>
      _tripCall('/otm_b2b/mobile/trip/start', {'start_meter': meter});

  Future<Map<String, dynamic>> addTripStop({required double meter, int? planId, String? locationName}) =>
      _tripCall('/otm_b2b/mobile/trip/stop',
          {'meter_reading': meter, if (planId != null) 'plan_id': planId, 'location_name': locationName ?? ''});

  Future<Map<String, dynamic>> finishTrip(double meter) =>
      _tripCall('/otm_b2b/mobile/trip/finish', {'meter_reading': meter});

  Future<int> sendPings(List<Map<String, dynamic>> points) async {
    final data = await _post('/otm_b2b/mobile/track/ping', {'points': points});
    return (data['saved'] as num?)?.toInt() ?? 0;
  }
}
