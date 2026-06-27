import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/audio_bar.dart';
import '../../core/services/service_locator.dart';
import '../home/home_screen.dart';
import '../explore/explore_screen.dart';
import '../explore/search_screen.dart';
import '../../core/widgets/global_audio_bar_wrapper.dart';
import '../library/saved_library_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/paywall_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const SearchScreen(),
    const SavedLibraryScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVersionAndExpiry();
    });
  }

  void _checkVersionAndExpiry() async {
    await _performVersionCheck();
    await _performExpiryCheck();
  }

  bool _isVersionLower(String current, String required) {
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> requiredParts = required.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    int maxLen = currentParts.length > requiredParts.length ? currentParts.length : requiredParts.length;
    for (int i = 0; i < maxLen; i++) {
      int currentPart = i < currentParts.length ? currentParts[i] : 0;
      int requiredPart = i < requiredParts.length ? requiredParts[i] : 0;
      if (currentPart < requiredPart) return true;
      if (currentPart > requiredPart) return false;
    }
    return false;
  }

  Future<void> _performVersionCheck() async {
    const String currentVersion = '2.0';
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('global').get();
      if (!doc.exists) return;
      
      final data = doc.data();
      if (data == null) return;
      
      final minVersion = data['minVersion'] as String? ?? '2.0';
      final latestVersion = data['latestVersion'] as String? ?? '2.0';
      
      final playStoreUrl = data['playStoreUrl'] as String? ?? '';
      final appStoreUrl = data['appStoreUrl'] as String? ?? '';
      final targetUrl = Platform.isAndroid ? playStoreUrl : appStoreUrl;
      
      if (_isVersionLower(currentVersion, minVersion)) {
        if (mounted) {
          _showUpdateDialog(context, targetUrl, isForced: true);
        }
      } else if (_isVersionLower(currentVersion, latestVersion)) {
        if (mounted) {
          _showUpdateDialog(context, targetUrl, isForced: false);
        }
      }
    } catch (e) {
      print('Error during version update check: $e');
    }
  }

  void _showUpdateDialog(BuildContext context, String storeUrl, {required bool isForced}) {
    final localizations = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      barrierDismissible: !isForced,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: !isForced,
          child: AlertDialog(
            title: Text(localizations.translate('update_available')),
            content: Text(localizations.translate('update_desc')),
            actions: [
              if (!isForced)
                TextButton(
                  child: Text(localizations.translate('later')),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ElevatedButton(
                child: Text(localizations.translate('update_now')),
                onPressed: () async {
                  if (storeUrl.isNotEmpty) {
                    final uri = Uri.parse(storeUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _performExpiryCheck() async {
    final user = AppLocator.auth.currentUser;
    if (user == null) return;
    
    if ((user.subscriptionStatus == 'free' || user.subscriptionStatus.isEmpty) &&
        user.subscriptionExpiryDate != null &&
        user.subscriptionExpiryDate!.isNotEmpty) {
      try {
        final expiry = DateTime.parse(user.subscriptionExpiryDate!);
        if (DateTime.now().isAfter(expiry)) {
          final prefs = await SharedPreferences.getInstance();
          final lastShownExpiry = prefs.getString('last_shown_expiry_date');
          
          if (lastShownExpiry != user.subscriptionExpiryDate) {
            if (mounted) {
              _showExpiryDialog(context, user.subscriptionExpiryDate!);
            }
          }
        }
      } catch (e) {
        print('Error during premium expiry check: $e');
      }
    }
  }

  void _showExpiryDialog(BuildContext context, String expiryDateStr) {
    final localizations = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(localizations.translate('premium_expired_title')),
          content: Text(localizations.translate('premium_expired_desc')),
          actions: [
            TextButton(
              child: Text(localizations.translate('later')),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('last_shown_expiry_date', expiryDateStr);
                if (mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
            ElevatedButton(
              child: Text(localizations.translate('renew_now')),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('last_shown_expiry_date', expiryDateStr);
                if (mounted) {
                  Navigator.of(dialogContext).pop(); // Close dialog
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isRtl = localizations.isRtl;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: Text(
                localizations.translate('exit_title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(localizations.translate('exit_desc')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(localizations.translate('cancel_btn')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(localizations.translate('exit_btn')),
                ),
              ],
            );
          },
        );
        if (shouldExit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: GlobalAudioBarWrapper(
          child: _screens[_currentIndex],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            const screens = ['Home Dashboard', 'Explore & Playlists', 'Search Books', 'My Library', 'Profile & Settings'];
            if (index >= 0 && index < screens.length) {
              AppLocator.auth.updatePresence(screen: screens[index], activityType: 'browsing');
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: localizations.translate('home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.explore_outlined),
              activeIcon: const Icon(Icons.explore),
              label: localizations.translate('explore'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.search_outlined),
              activeIcon: const Icon(Icons.search),
              label: localizations.translate('search'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.bookmark_outline),
              activeIcon: const Icon(Icons.bookmark),
              label: localizations.translate('library'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: localizations.translate('profile'),
            ),
          ],
        ),
      ),
    );
  }
}
