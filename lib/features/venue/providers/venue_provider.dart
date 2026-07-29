import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VenueProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  int? _activeBranchId;
  bool _isLoading = false;

  // Getters to expose state securely to the UI screens
  int? get activeBranchId => _activeBranchId;
  bool get isLoading => _isLoading;

  /// Loads the user's historically saved branch allocation on app launch
  Future<void> initializeSessionVenue() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _supabase
          .from('profiles')
          .select('last_selected_branch_id')
          .eq('id', userId)
          .single();

      if (profile['last_selected_branch_id'] != null) {
        _activeBranchId = profile['last_selected_branch_id'] as int;
      }
    } catch (e) {
      debugPrint('⚠️ Error initializing venue session state: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets a new active venue branch and updates traffic analytics metrics
  Future<bool> updateActiveVenue(int branchId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Persist selection structural state to database
      await _supabase.from('profiles').update({
        'last_selected_branch_id': branchId,
      }).eq('id', userId);

      // 📊 2. Register metric analytics record footprint
      await _supabase.from('user_login_sessions').insert({
        'user_id': userId,
        'selected_branch_id': branchId,
      });

      _activeBranchId = branchId;
      return true;
    } catch (e) {
      debugPrint('❌ Failed to commit venue change transition step: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears active state parameters on user sign out routines
  void clearVenueSession() {
    _activeBranchId = null;
    notifyListeners();
  }
}
