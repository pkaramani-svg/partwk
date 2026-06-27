import 'auth_service.dart';
import 'database_service.dart';
import 'audio_service.dart';
import 'ai_coach_service.dart';
import 'firebase_auth_service.dart';
import 'firestore_database_service.dart';
import '../../services/download_service.dart';

class AppLocator {
  static AuthService auth = FirebaseAuthService();
  static DatabaseService db = FirestoreDatabaseService();
  static AudioService audio = RealAudioService();
  static AICoachService aiCoach = RealAICoachService();

  // Helper initialization if any async bindings are needed in the future
  static Future<void> init() async {
    // Services are initialized on demand or as singletons here
    await DownloadService.init();
    await audio.init();
  }
}
