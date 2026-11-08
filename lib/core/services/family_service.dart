import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FamilyService {
  FamilyService({FirebaseFunctions? functions}) : _customFunctions = functions;
  final FirebaseFunctions? _customFunctions;

  FirebaseFunctions? get _functions {
    if (_customFunctions != null) return _customFunctions;
    if (Firebase.apps.isNotEmpty) return FirebaseFunctions.instance;
    return null;
  }

  Future<Map<String, dynamic>> status() async => _call('getFamilyStatus');
  Future<Map<String, dynamic>> invite(String email) => _call('inviteFamilyMember', {'email': email});
  Future<Map<String, dynamic>> accept() => _call('acceptFamilyInvitation');
  Future<Map<String, dynamic>> cancel() => _call('cancelFamilyInvitation');
  Future<Map<String, dynamic>> remove() => _call('removeFamilyMember');
  Future<Map<String, dynamic>> leave() => _call('leaveFamily');

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    final fns = _functions;
    if (fns == null) return {};
    try {
      final result = await fns.httpsCallable(name).call(data);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw FamilyException(e.message ?? 'Family action could not be completed.');
    }
  }
}

class FamilyException implements Exception {
  FamilyException(this.message);
  final String message;
  @override String toString() => message;
}
