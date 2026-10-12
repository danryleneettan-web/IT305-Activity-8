import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Firebase Authentication REST + Realtime Database REST client.
/// Passwords are sent only to Firebase Authentication and never stored in RTDB.
class FirebaseService extends ChangeNotifier {
  static final FirebaseService instance = FirebaseService._internal();
  FirebaseService._internal();

  static const String _apiKey = 'AIzaSyB9fLFhHZT75mbuMu_RmX0PwmNjlyxoBKw';
  static const String _databaseUrl = 'https://coop-692bf-default-rtdb.firebaseio.com/';
  static const String _identityUrl = 'https://identitytoolkit.googleapis.com/v1/';
  static const String _tokenUrl = 'https://securetoken.googleapis.com/v1/token';
  static const String _accountDomain = 'coop-692bf.firebaseapp.com';

  String? _idToken;
  String? _refreshToken;
  String? _uid;
  String? _role;
  DateTime? _tokenExpiresAt;
  bool _isConnected = false;
  String? _lastError;

  String get databaseUrl => _databaseUrl;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  String? get currentUid => _uid;
  String? get currentRole => _role;
  bool get isStaff => _role == 'staff';

  final Map<String, MemberModel> _localMembers = {};
  final Map<String, SurveyModel> _localSurveys = {};
  final Map<String, SurveySubmission> _localSubmissions = {};

  void setDatabaseUrl(String value) {
    if (!value.trim().startsWith(_databaseUrl)) {
      _lastError = 'This app is configured for the CoopConnect Firebase project.';
      notifyListeners();
    }
  }

  String _memberEmail(String account) => '${account.trim()}@members.$_accountDomain';
  String _staffEmail(String username) => '${username.trim()}@staff.$_accountDomain';

  Uri _authUri(String method) => Uri.parse('$_identityUrl$method?key=$_apiKey');

  Future<Map<String, dynamic>> _postAuth(String method, Map<String, dynamic> body) async {
    final response = await http.post(_authUri(method),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 12));
    final data = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data is Map ? data['error'] : null;
      final message = error is Map ? error['message']?.toString() : null;
      if (['INVALID_LOGIN_CREDENTIALS', 'EMAIL_NOT_FOUND', 'INVALID_PASSWORD'].contains(message)) {
        throw FirebaseException('Firebase did not accept those sign-in details. Check your email and password, or create a member account first.');
      }
      if (message == 'OPERATION_NOT_ALLOWED') {
        throw FirebaseException('Email/password sign-in is not enabled for this Firebase project yet.');
      }
      throw FirebaseException(message ?? 'Firebase Authentication failed (${response.statusCode}).');
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Map<String, dynamic> _decodeClaims(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    final normalized = base64Url.normalize(parts[1]);
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map);
  }

  void _startSession(Map<String, dynamic> auth) {
    _idToken = auth['idToken']?.toString();
    _refreshToken = auth['refreshToken']?.toString();
    _uid = auth['localId']?.toString();
    final claims = _decodeClaims(_idToken ?? '');
    _role = claims['role']?.toString() ?? 'member';
    final seconds = int.tryParse(auth['expiresIn']?.toString() ?? '') ?? 3600;
    _tokenExpiresAt = DateTime.now().add(Duration(seconds: seconds));
    _isConnected = _idToken != null && _uid != null;
    _lastError = null;
    notifyListeners();
  }

  Future<bool> _refreshSession() async {
    if (_idToken == null || _uid == null) return false;
    if (_tokenExpiresAt != null && DateTime.now().isBefore(_tokenExpiresAt!.subtract(const Duration(minutes: 2)))) return true;
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(Uri.parse('$_tokenUrl?key=$_apiKey'), headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'grant_type': 'refresh_token', 'refresh_token': _refreshToken})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _idToken = data['id_token']?.toString();
      _refreshToken = data['refresh_token']?.toString() ?? _refreshToken;
      _uid = data['user_id']?.toString() ?? _uid;
      final seconds = int.tryParse(data['expires_in']?.toString() ?? '') ?? 3600;
      _tokenExpiresAt = DateTime.now().add(Duration(seconds: seconds));
      _role = _decodeClaims(_idToken ?? '')['role']?.toString() ?? _role;
      return _idToken != null;
    } catch (_) {
      return false;
    }
  }

  Future<Uri> _dbUri(String path) async {
    if (!await _refreshSession()) throw FirebaseException('Sign in to access cooperative data.');
    final base = Uri.parse('$_databaseUrl${path.startsWith('/') ? path.substring(1) : path}.json');
    return base.replace(queryParameters: {...base.queryParameters, 'auth': _idToken!});
  }

  Future<http.Response> _dbRequest(String path, {String method = 'GET', Object? body}) async {
    final uri = await _dbUri(path);
    final headers = <String, String>{'Content-Type': 'application/json'};
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'PUT': return http.put(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 12));
      case 'PATCH': return http.patch(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 12));
      case 'DELETE': return http.delete(uri, headers: headers).timeout(const Duration(seconds: 12));
      default: return http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
    }
  }

  dynamic _decodeDb(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _lastError = 'Realtime Database returned HTTP ${response.statusCode}.';
      throw FirebaseException(_lastError!);
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  Future<bool> testConnection() async {
    try {
      _decodeDb(await _dbRequest('cooperative_portal/surveys'));
      _isConnected = true;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (error) {
      _isConnected = false;
      _lastError = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<StaffModel?> authenticateStaff(String username, String password) async {
    try {
      final auth = await _postAuth('accounts:signInWithPassword', {
        'email': _staffEmail(username), 'password': password, 'returnSecureToken': true,
      });
      _startSession(auth);
      if (_role != 'staff') { signOut(); return null; }
      final data = _decodeDb(await _dbRequest('cooperative_portal/staff/${Uri.encodeComponent(username.trim())}'));
      final record = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      _isConnected = true;
      return StaffModel(username: username.trim(), fullName: record['fullName']?.toString() ?? record['full_name']?.toString() ?? username.trim(), password: '', role: 'staff');
    } catch (error) {
      _lastError = error.toString();
      return null;
    }
  }

  Future<MemberModel?> authenticateMember(String accountNumber, String password) async {
    try {
      final account = accountNumber.trim();
      final usesEmail = account.contains('@');
      final auth = await _postAuth('accounts:signInWithPassword', {
        'email': usesEmail ? account : _memberEmail(account), 'password': password, 'returnSecureToken': true,
      });
      _startSession(auth);
      final profileKey = usesEmail ? _uid! : account;
      final data = _decodeDb(await _dbRequest('cooperative_portal/members/${Uri.encodeComponent(profileKey)}'));
      if (data is! Map) { signOut(); return null; }
      final member = MemberModel.fromJson(Map<String, dynamic>.from(data), profileKey);
      if (member.authUid != _uid) { signOut(); return null; }
      _localMembers[member.accountNumber] = member;
      return member;
    } catch (error) {
      _lastError = error.toString();
      return null;
    }
  }

  Future<MemberModel?> registerMember({required String email, required String firstName, required String lastName, required String password}) async {
    try {
      if (!email.trim().contains('@') || firstName.trim().isEmpty || lastName.trim().isEmpty || password.length < 8) {
        throw FirebaseException('Enter a valid email, your first and last name, and a password of at least 8 characters.');
      }
      final auth = await _postAuth('accounts:signUp', {
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      });
      _startSession(auth);
      final profileKey = _uid!;
      final account = 'PUBLIC-${profileKey.substring(0, 8).toUpperCase()}';
      final now = DateTime.now().toIso8601String();
      final member = MemberModel(
        id: profileKey,
        accountNumber: account,
        password: '',
        authUid: _uid ?? '',
        email: email.trim(),
        forcePasswordChange: false,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        civilStatus: 'Single',
        address: '',
        contactNumber: '',
        birthday: '',
        createdAt: now,
        updatedAt: now,
      );
      final response = await _dbRequest('cooperative_portal/members/${Uri.encodeComponent(profileKey)}', method: 'PUT', body: member.toJson());
      _decodeDb(response);
      _localMembers[account] = member;
      return member;
    } catch (error) {
      _lastError = error.toString();
      if (_idToken != null) {
        try { await _postAuth('accounts:delete', {'idToken': _idToken}); } catch (_) {}
      }
      signOut();
      return null;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      if (!email.trim().contains('@')) throw FirebaseException('Enter the email used to create your account.');
      await _postAuth('accounts:sendOobCode', {'requestType': 'PASSWORD_RESET', 'email': email.trim()});
      _lastError = null;
      return true;
    } catch (error) {
      _lastError = error.toString();
      return false;
    }
  }

  void signOut() {
    _idToken = null; _refreshToken = null; _uid = null; _role = null; _tokenExpiresAt = null;
    _isConnected = false;
    _localMembers.clear(); _localSurveys.clear(); _localSubmissions.clear();
    notifyListeners();
  }

  Future<List<MemberModel>> getMembers({String query = '', bool recentOnly = false}) async {
    final list = <MemberModel>[];
    final data = _decodeDb(await _dbRequest('cooperative_portal/members'));
    if (data is Map) {
      data.forEach((key, value) {
        if (value is Map) {
          final member = MemberModel.fromJson(Map<String, dynamic>.from(value), key.toString());
          list.add(member); _localMembers[member.accountNumber] = member;
        }
      });
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final q = query.toLowerCase();
    return list.where((m) {
      if (q.isNotEmpty && !m.accountNumber.toLowerCase().contains(q) && !m.firstName.toLowerCase().contains(q) && !m.lastName.toLowerCase().contains(q)) return false;
      if (recentOnly) { final date = DateTime.tryParse(m.updatedAt); if (date != null && DateTime.now().difference(date).inDays > 7) return false; }
      return true;
    }).toList();
  }

  Future<MemberModel?> getMember(String accountNumber) async {
    final profileKey = _localMembers[accountNumber]?.id ?? accountNumber;
    final data = _decodeDb(await _dbRequest('cooperative_portal/members/${Uri.encodeComponent(profileKey)}'));
    if (data is! Map) return null;
    final member = MemberModel.fromJson(Map<String, dynamic>.from(data), profileKey);
    _localMembers[accountNumber] = member;
    return member;
  }

  Future<bool> saveMember(MemberModel member) async {
    try {
      member.updatedAt = DateTime.now().toIso8601String();
      if (member.authUid.isEmpty) {
        if (!isStaff) throw FirebaseException('Only cooperative staff can create member accounts.');
        final initialPassword = member.password;
        if (initialPassword.length < 6) throw FirebaseException('The temporary password must be at least 6 characters.');
        final auth = await _postAuth('accounts:signUp', {'email': _memberEmail(member.accountNumber), 'password': initialPassword, 'returnSecureToken': true});
        member.authUid = auth['localId']?.toString() ?? '';
        member.forcePasswordChange = true;
      }
      member.password = '';
      final profileKey = member.id.isNotEmpty ? member.id : member.accountNumber;
      member.id = profileKey;
      final response = await _dbRequest('cooperative_portal/members/${Uri.encodeComponent(profileKey)}', method: 'PUT', body: member.toJson());
      _decodeDb(response);
      _localMembers[member.accountNumber] = member;
      notifyListeners();
      return true;
    } catch (error) { _lastError = error.toString(); return false; }
  }

  Future<bool> resetMemberPassword(String accountNumber) async {
    _lastError = 'Password resets must be completed by a Firebase Authentication administrator.';
    return false;
  }

  Future<bool> updateMemberPassword(String accountNumber, String newPassword) async {
    if (_uid == null || _idToken == null || _role != 'member' || newPassword.length < 8) return false;
    try {
      await _postAuth('accounts:update', {'idToken': _idToken, 'password': newPassword, 'returnSecureToken': true});
      final member = await getMember(accountNumber);
      if (member == null) return false;
      member.forcePasswordChange = false;
      member.updatedAt = DateTime.now().toIso8601String();
      final response = await _dbRequest('cooperative_portal/members/${Uri.encodeComponent(member.id)}', method: 'PATCH', body: {'forcePasswordChange': false, 'updatedAt': member.updatedAt});
      _decodeDb(response);
      member.password = '';
      _localMembers[accountNumber] = member;
      return true;
    } catch (error) { _lastError = error.toString(); return false; }
  }

  Future<bool> deleteMember(String accountNumber) async {
    try {
      final profileKey = _localMembers[accountNumber]?.id ?? accountNumber;
      _decodeDb(await _dbRequest('cooperative_portal/members/${Uri.encodeComponent(profileKey)}', method: 'DELETE'));
      _localMembers.remove(accountNumber); notifyListeners(); return true;
    } catch (error) { _lastError = error.toString(); return false; }
  }

  Future<String> generateNextAccountNumber() async {
    final members = await getMembers();
    var maxNum = 20260000;
    for (final member in members) { final value = int.tryParse(member.accountNumber.replaceAll('-', '')); if (value != null && value > maxNum) maxNum = value; }
    final next = (maxNum + 1).toString();
    return '${next.substring(0, 4)}-${next.substring(4)}';
  }

  Future<List<SurveyModel>> getSurveys() async {
    final list = <SurveyModel>[];
    final data = _decodeDb(await _dbRequest('cooperative_portal/surveys'));
    if (data is Map) { data.forEach((key, value) { if (value is Map) { final survey = SurveyModel.fromJson(Map<String, dynamic>.from(value), key.toString()); list.add(survey); _localSurveys[survey.id] = survey; } }); }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<bool> saveSurvey(SurveyModel survey) async {
    if (!isStaff) return false;
    try {
      if (survey.id.isEmpty) survey.id = 'survey_${DateTime.now().millisecondsSinceEpoch}';
      survey.updatedAt = DateTime.now().toIso8601String();
      if (survey.createdAt.isEmpty) survey.createdAt = survey.updatedAt;
      _decodeDb(await _dbRequest('cooperative_portal/surveys/${Uri.encodeComponent(survey.id)}', method: 'PUT', body: survey.toJson()));
      _localSurveys[survey.id] = survey; notifyListeners(); return true;
    } catch (error) { _lastError = error.toString(); return false; }
  }

  Future<bool> deactivateSurvey(String surveyId) async {
    SurveyModel? survey = _localSurveys[surveyId];
    if (survey == null) {
      for (final item in await getSurveys()) { if (item.id == surveyId) { survey = item; break; } }
    }
    if (survey == null) return false;
    survey.status = 'inactive';
    return saveSurvey(survey);
  }

  Future<bool> hasMemberSubmittedSurvey(String surveyId, String memberId) async {
    if (_uid == null) return false;
    final key = '${surveyId}_$_uid';
    final data = _decodeDb(await _dbRequest('cooperative_portal/survey_submissions/$key'));
    return data != null;
  }

  Future<bool> submitSurveyResponse({required String surveyId, required String memberId, required String memberName, required Map<String, String> answers}) async {
    if (_uid == null || _role != 'member') return false;
    final key = '${surveyId}_$_uid';
    final sub = SurveySubmission(id: key, surveyId: surveyId, memberId: memberId, memberName: memberName, memberUid: _uid!, submittedAt: DateTime.now().toIso8601String(), answers: answers);
    try {
      _decodeDb(await _dbRequest('cooperative_portal/survey_submissions/$key', method: 'PUT', body: sub.toJson()));
      _localSubmissions[key] = sub; notifyListeners(); return true;
    } catch (error) { _lastError = error.toString(); return false; }
  }

  Future<List<SurveySubmission>> getSurveySubmissions(String surveyId) async {
    final result = <SurveySubmission>[];
    final data = _decodeDb(await _dbRequest('cooperative_portal/survey_submissions'));
    if (data is Map) { data.forEach((key, value) { if (value is Map) { final item = SurveySubmission.fromJson(Map<String, dynamic>.from(value), key.toString()); if (item.surveyId == surveyId) { result.add(item); _localSubmissions[item.id] = item; } } }); }
    return result;
  }
}

class FirebaseException implements Exception {
  final String message;
  FirebaseException(this.message);
  @override
  String toString() => message;
}
