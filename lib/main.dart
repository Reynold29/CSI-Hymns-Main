import 'dart:convert';
import 'theme_state.dart';
import 'widgets/sidebar.dart';
import 'screens/categories.dart';
import 'screens/hymns_screen.dart';
import 'screens/keerthane_screen.dart';
import 'screens/order_of_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:hymns_latest/screens/favorites_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';
import 'package:hymns_latest/services/supabase_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class LightSwipePagePhysics extends PageScrollPhysics {
  const LightSwipePagePhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  LightSwipePagePhysics applyTo(ScrollPhysics? ancestor) {
    return LightSwipePagePhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingDistance => 5.0; // much lower than default (50.0)

  @override
  double get minFlingVelocity => 100.0; // lower than default (400.0)
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      FirebaseOptions firebaseOptions = const FirebaseOptions(
        apiKey: "AIzaSyDxevY9bYbwnMKCCyAqCXo5emtBbE4_keY",
        authDomain: "hymnappnoti.firebaseapp.com",
        projectId: "hymnappnoti",
        storageBucket: "hymnappnoti.firebasestorage.app",
        messagingSenderId: "162340486626",
        appId: "1:162340486626:web:6ea1b8331cdcb4b3e54dbb",
      );
      await Firebase.initializeApp(options: firebaseOptions);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue app initialization even if Firebase fails
  }

  // Initialize Supabase
  try {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'] ?? dotenv.env['SUPABASE_PROJECT_URL'] ?? '';
    final anon = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    await SupabaseService().init(url: url, anonKey: anon);
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  runApp(
    ShowCaseWidget(
      builder: (context) => ChangeNotifierProvider(
        create: (context) => ThemeState(),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeState>(
      builder: (context, themeState, child) {
        return MaterialApp(
          title: 'CSI Hymns and Lyrics',
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'plusJakartaSans',
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeState.seedColor,
              brightness: Brightness.light,
            ),
            navigationBarTheme: NavigationBarThemeData(
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: 'plusJakartaSans',
            scaffoldBackgroundColor: themeState.blackThemeEnabled ? Colors.black : null,
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeState.seedColor,
              brightness: Brightness.dark,
            ),
            navigationBarTheme: NavigationBarThemeData(
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
          ),
          themeMode: themeState.themeMode,
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  final GlobalKey _menuButtonKey = GlobalKey();
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late PageController _pageController;
  StreamSubscription<AuthState>? _authSub;

  static const Duration _pageAnimationDuration = Duration(milliseconds: 300);
  static const Curve _pageAnimationCurve = Curves.easeInOutCubic;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _pageController = PageController(initialPage: _selectedIndex);
    checkForUpdate();
    _initOneSignalWithCount();
    _checkFirstRunAndShowCase();
    _listenToSupabaseAuth();
  }

  Future<void> checkForUpdate() async {
    try {
      InAppUpdate.checkForUpdate().then((info) {
        setState(() {
          if (info.updateAvailability == UpdateAvailability.updateAvailable) {
            update();
          }
        });
      }).catchError((e) {
        String msg = e.toString().contains('not owned by any user')
            ? "In-app update is only available for Play Store installs."
            : "Error checking for update: $e";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      });
    } catch (e) {
      String msg = e.toString().contains('not owned by any user')
          ? "In-app update is only available for Play Store installs."
          : "Error checking for update: $e";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  void update() async {
    await InAppUpdate.startFlexibleUpdate();
    InAppUpdate.completeFlexibleUpdate().then((_) {}).catchError((e) {});
  }

  // Removed unused counter method

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  // Removed unused drawer toggle stub

  static final List<Widget> _screens = [
    const HymnsScreen(),
    const KeerthaneScreen(),
    const OrderOfServiceScreen(),
    const Categories(),
    const FavoritesScreen(),
  ];

  void _onItemTapped(int index) async {
    if (_selectedIndex == index) return;
    await HapticFeedbackManager.lightClick();
    _pageController.animateToPage(
      index,
      duration: _pageAnimationDuration,
      curve: _pageAnimationCurve,
    );
  }

  void _listenToSupabaseAuth() {
    _authSub = SupabaseService().authStream.listen((state) async {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _showResetPasswordDialog();
      }
    });
  }

  void _showResetPasswordDialog() {
    final TextEditingController pass1 = TextEditingController();
    final TextEditingController pass2 = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Set new password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pass1,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pass2,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm password'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final p1 = pass1.text;
                final p2 = pass2.text;
                if (p1.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
                  return;
                }
                if (p1 != p2) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                  return;
                }
                try {
                  await Supabase.instance.client.auth.updateUser(UserAttributes(password: p1));
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkFirstRunAndShowCase() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstRun = (prefs.getBool('isFirstRun') ?? true);

    if (isFirstRun == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ShowCaseWidget.of(context).startShowCase([_menuButtonKey]);
          prefs.setBool('isFirstRun', false);
        }
      });
    }
  }

  Future<void> _initOneSignalWithCount() async {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("29f2a6ba-3f56-4ffe-8075-3b70d7440b13");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    int promptCount = prefs.getInt('notificationPromptCount') ?? 0;

    // Get the current native notification permission status
    OSNotificationPermission nativePermissionStatus = await OneSignal.Notifications.permissionNative();

    // 1. If permission is already authorized, reset prompt count and return.
    if (nativePermissionStatus == OSNotificationPermission.authorized) {
      prefs.setInt('notificationPromptCount', 0);
      return;
    }

    // 2. If permission is denied AND we've already prompted twice or more, do not prompt again.
    if (nativePermissionStatus == OSNotificationPermission.denied && promptCount >= 2) {
      debugPrint("User has denied notification permissions multiple times. Not prompting again.");
      return;
    }

    // 3. Otherwise (permission not authorized, and prompt count is less than 2), request permission.
    if (promptCount < 2) {
      OneSignal.Notifications.requestPermission(true).then((accepted) {
        if (!accepted) {
          // User denied the prompt, increment the count
          prefs.setInt('notificationPromptCount', promptCount + 1);
        } else {
          // User accepted, reset count (optional, but good practice)
          prefs.setInt('notificationPromptCount', 0);
        }
      });
    }

    // -- iOS settings --
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print("FOREGROUND WILL DISPLAY LISTENER: Notification Received");
    });

    OneSignal.Notifications.addClickListener((event) {
      print('NOTIFICATION CLICK LISTENER: ${jsonEncode(event.notification.jsonRepresentation())}');
    });

    // iOS-only event listener for notification permissions
    OneSignal.Notifications.addPermissionObserver((state) {
      print("Notification permission status: ${state.toString()}");
    });

    // -- Android settings --
    // (Listeners are generally platform-agnostic for OneSignal, but specific platform handling can be added here if needed)
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CSI Kannada Hymns Book',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
        leading: Builder(
          builder: (context) {
            return Showcase(
              key: _menuButtonKey,
              title: 'Sidebar',
              description: 'Tap here to open the menu for categories and settings.',
              targetShapeBorder: const CircleBorder(),
              overlayColor: Colors.black.withOpacity(0.7),
              titleTextStyle: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 20, fontWeight: FontWeight.bold),
              child: IconButton(
                icon: Icon(Icons.menu, color: colorScheme.onSurface, size: 26),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            );
          },
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      drawer: Sidebar(animationController: _animationController),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const LightSwipePagePhysics(),
              onPageChanged: (int index) async {
                setState(() => _selectedIndex = index);
                await HapticFeedbackManager.lightClick();
              },
              children: _screens,
            ),
          ),
          // Modern curved navbar with SafeArea
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabCount = 5;
                  final tabWidth = constraints.maxWidth / tabCount;
                  return Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.bottomLeft,
                      children: [
                        // Row of tab buttons with less bottom padding for indicator
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildTabButton(context, 0, Icons.music_note, 'Hymns'),
                              _buildTabButton(context, 1, Icons.album, 'Keerthane'),
                              _buildTabButton(context, 2, Icons.event_note, 'Service'),
                              _buildTabButton(context, 3, Icons.category, 'Categories'),
                              _buildTabButton(context, 4, Icons.favorite, 'Favorites'),
                            ],
                          ),
                        ),
                        // Perfectly aligned indicator
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          left: _selectedIndex * tabWidth,
                          bottom: 2,
                          child: Container(
                            width: tabWidth,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.13),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, int index, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedbackManager.lightClick();
          _onItemTapped(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 4),
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 24),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.1,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
