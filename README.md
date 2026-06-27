# Partwk - Premium Book Summaries & Micro-Learning App

Partwk is a premium mobile application built in Flutter with clean architecture, supporting dynamic Right-to-Left (RTL) layout switching and localized summaries in **English (LTR)**, **Kurdish Sorani (RTL)**, and **Arabic (RTL)**.

---

## Features

### Core App Flow
1. **Splash Screen**: Animated brand gateway with session-aware routing.
2. **Language Selection**: Real-time localization toggle that updates the text alignment (RTL/LTR) instantly.
3. **Onboarding**: Highlights premium values (unlimited summaries, custom coaching, etc.).
4. **Login/Register**: Standard email/password forms, Google, Apple logins, and a guest mode trigger.
5. **Interest Selection**: Visual category chip grid storing user preferences.
6. **Learning Goals**: Custom daily target trackers (e.g. read 15m daily, one idea a day).
7. **Main Navigation Scaffold**: Coordinate home, search, explore, library, and profile pages.

### Premium & Learning Tools
8. **Home Dashboard**: Features a daily digest card, mood-based summary recommendations, and consistency streaks.
9. **Explore & Browse**: Explore summaries by category playlists and structured learning paths.
10. **Book Details**: Cover art header, reviews listing, bookmark options, offline downloading, and comparison sheet triggers.
11. **Summary Reader**: Interactive tabs (5-min, 15-min, chapters, ideas, quotes, action items).
12. **AI Personal Coach**: Chatbot sidebar drawer allowing users to ask questions about summaries.
13. **Action Point Goals**: Button next to action points that lets users save tips directly as personal goals.
14. **Highlights & Notes**: Drag-select highlight colors and persistent note reflections.
15. **Audio Player**: Full-screen player with disk rotation, speed selectors, narrative voice dropdowns, and continuous background playback overlay.
16. **Flashcards**: Active recall study tool using flippable perspective animation.
17. **Quizzes**: Interactive quiz sheets rewarding completion scores.
18. **Graduation Certificates**: Claims customized certificates after finishing structured paths.
19. **Achievements Panel**: Unlocks color milestones and showcases total study stats.
20. **Settings Manager**: Simple switches for Dark/Light themes, notification preferences, and family account links.
21. **Gold Paywall**: Pricing plans checklist.
22. **Admin Dashboard**: Content creation panels to upload custom summaries, translation scripts, and audio tracks.

---

## Directory Architecture

```
lib/
├── core/
│   ├── constants/       # Layout limits, static maps
│   ├── localization/    # AppLanguageState and AppLocalizations delegates
│   ├── services/        # Service interfaces and implementations (Auth, DB, Audio, Coach)
│   ├── theme/           # AppTheme dark and light configurations
│   └── widgets/         # CustomButton, BookCard, MiniAudioBar
├── features/
│   ├── admin/           # AdminDashboard content creators
│   ├── audio/           # AudioPlayerScreen controls
│   ├── auth/            # Splash, Language, Onboarding, Login, Interests, Goals
│   ├── explore/         # ExploreScreen lists, SearchScreen matching queries
│   ├── home/            # HomeScreen digests, MainNavigation tabs
│   ├── learning/        # FlashcardsScreen, QuizScreen, NotesAndHighlightsScreen
│   ├── library/         # SavedLibraryScreen, DownloadsScreen, LearningPathScreen
│   └── profile/         # ProfileScreen options, SettingsScreen toggles, PaywallScreen cards
└── models/              # Book, User, Category, Quiz, Note, Highlight data classes
```

---

## How to Run the App

### 1. Prerequisites
- Install [Flutter SDK](https://docs.flutter.dev/get-started/install) matching standard environment paths.
- Setup a simulator or connect a physical device (iOS/Android).

### 2. Setup
Clone or navigate to the project directory and pull dependencies:
```bash
flutter pub get
```

### 3. Run the App
To start the app in development/debug mode:
```bash
flutter run
```

---

## Production Firebase Setup

The application is built using the **Service Locator Pattern** (`Locator` interface inside `lib/core/services/service_locator.dart`). To deploy with Firebase, perform the following steps:

1. **Configure Firebase project**:
   - Run `flutterfire configure` to generate `firebase_options.dart`.
2. **Implement Production Services**:
   - Create Firebase implementations of `AuthService` and `DatabaseService` using `cloud_firestore` and `firebase_auth` libraries.
3. **Register Services in Service Locator**:
   Change the references in [service_locator.dart](file:///Users/peshrawkaramani/Desktop/Partwk/lib/core/services/service_locator.dart):
   ```dart
   class Locator {
     static final AuthService auth = FirebaseAuthService(); // Replace Mock
     static final DatabaseService db = FirebaseDatabaseService(); // Replace Mock
     static final AudioService audio = MockAudioService(); // Connects to Native player
     static final AICoachService aiCoach = MockAICoachService(); // Connects to Cloud Function
   }
   ```
