import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionProvider extends ChangeNotifier {
  static const String _keyName = 'user_name';
  static const String _keyEmail = 'user_email';
  static const String _keyBranch = 'user_branch';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserType = 'user_type';
  static const String _keyIsPersonal = 'is_personal';
  static const String _keyIsAdmin = 'is_admin';
  static const String _keyIsRecepcion = 'is_recepcion';
  static const String _keyIsGestor = 'is_gestor';
  static const String _keyUserId = 'user_id';

  String? _userName;
  String? _userEmail;
  String? _selectedBranch;
  String? _userId;
  bool _isLoggedIn = false;
  String _userType = 'client';
  bool _isPersonal = false;
  bool _isAdmin = false;
  bool _isRecepcion = false;
  bool _isGestor = false;
  String _adminView = 'admin';
  bool _visitRegistered = false;
  bool _isInitialized = false;

  SessionProvider() {
    _loadFromPrefs();
  }

  bool get isInitialized => _isInitialized;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get selectedBranch => _selectedBranch;
  bool get isLoggedIn => _isLoggedIn;
  String get userType => _userType;
  bool get isPersonal => _isPersonal;
  bool get isAdmin => _isAdmin;
  bool get isRecepcion => _isRecepcion;
  bool get isGestor => _isGestor;
  bool get isStaff => _userType == 'staff';
  String get adminView => _adminView;
  String? get userId => _userId;
  bool get visitRegistered => _visitRegistered;

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString(_keyName);
      _userEmail = prefs.getString(_keyEmail);
      _selectedBranch = prefs.getString(_keyBranch);
      _isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      _userType = prefs.getString(_keyUserType) ?? 'client';
      _isPersonal = prefs.getBool(_keyIsPersonal) ?? false;
      _isAdmin = prefs.getBool(_keyIsAdmin) ?? false;
      _isRecepcion = prefs.getBool(_keyIsRecepcion) ?? false;
      _isGestor = prefs.getBool(_keyIsGestor) ?? false;
      _userId = prefs.getString(_keyUserId);
    } catch (e) {
      debugPrint('Error loading session from prefs: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setClientSession({
    required String userId,
    required String name,
    required String email,
    required String branch,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _userId = userId;
    _userName = name;
    _userEmail = email;
    _selectedBranch = branch;
    _isLoggedIn = true;
    _userType = 'client';
    _isPersonal = false;
    _isAdmin = false;
    _isRecepcion = false;
    _isGestor = false;

    await _saveToPrefs(prefs);
    _visitRegistered = false;
    notifyListeners();
  }

  Future<void> setStaffSession({
    required String userId,
    required String name,
    required String email,
    bool isPersonal = false,
    bool isAdmin = false,
    bool isRecepcion = false,
    bool isGestor = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _userId = userId;
    _userName = name;
    _userEmail = email;
    _isLoggedIn = true;
    _userType = 'staff';
    _isPersonal = isPersonal;
    _isAdmin = isAdmin;
    _isRecepcion = isRecepcion;
    _isGestor = isGestor;

    await _saveToPrefs(prefs);
    notifyListeners();
  }

  Future<void> updateClientData({
    required String name,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _userName = name;
    _userEmail = email;
    await _saveToPrefs(prefs);
    notifyListeners();
  }

  void setAdminView(String view) {
    _adminView = view;
    notifyListeners();
  }

  Future<void> _saveToPrefs(SharedPreferences prefs) async {
    await prefs.setString(_keyName, _userName ?? '');
    await prefs.setString(_keyEmail, _userEmail ?? '');
    await prefs.setString(_keyBranch, _selectedBranch ?? '');
    await prefs.setBool(_keyIsLoggedIn, _isLoggedIn);
    await prefs.setString(_keyUserType, _userType);
    await prefs.setBool(_keyIsPersonal, _isPersonal);
    await prefs.setBool(_keyIsAdmin, _isAdmin);
    await prefs.setBool(_keyIsRecepcion, _isRecepcion);
    await prefs.setBool(_keyIsGestor, _isGestor);
    if (_userId != null) await prefs.setString(_keyUserId, _userId!);
  }

  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Sign out from Supabase Auth
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        debugPrint('Supabase sign out error: $e');
      }
      
      _userName = null;
      _userEmail = null;
      _selectedBranch = null;
      _isLoggedIn = false;
      _userType = 'client';
      _isPersonal = false;
      _isAdmin = false;
      _isRecepcion = false;
      _isGestor = false;
      _adminView = 'admin';
      _userId = null;
    } finally {
      _visitRegistered = false;
      notifyListeners();
    }
  }

  Future<void> checkAndRegisterVisit() async {
    // Exclude staff and administrators from visit tracking
    if (_isLoggedIn && (_userType == 'staff' || _isAdmin || _isPersonal || _isRecepcion || _isGestor)) {
      return;
    }

    // Exclude demo users from visit tracking
    if (_userId != null && _userId!.startsWith('demo-')) {
      return;
    }

    if (_visitRegistered) return;
    _visitRegistered = true;
    notifyListeners();

    try {
      await Supabase.instance.client
          .from('EventosAPI')
          .insert({
            'tipodeevento': 'visita',
          });
      debugPrint('Visit registered successfully in EventosAPI');
    } catch (e) {
      debugPrint('Error registering visit in EventosAPI: $e');
    }
  }
}
