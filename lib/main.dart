import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'settings_provider.dart';
import 'database/auth_database.dart';
import 'l10n/app_localizations.dart';

// Screens
import 'splash_screen.dart';
import 'tv_homescreen.dart';
import 'search_screen.dart';
import 'categories_screen.dart';
import 'downloads_screen.dart';
import 'interactive_features_screen.dart';
import 'mylist_screen.dart';
import 'movie_detail_screen.dart';
import 'components/socialsection/ProfileScreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');

    await Supabase.initialize(
      url: 'https://qumrbpxhyxkgreoqsnis.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF1bXJicHhoeXhrZ3Jlb3FxbmlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg2NzkyNDksImV4cCI6MjA2NDI1NTI0OX0.r-Scwh1gYAfMwYjh1_wjAVb66XSjvcUgPeV_CH7VkS4',
    );
    debugPrint('✅ Supabase initialized');

    await AuthDatabase.instance.initialize();
    debugPrint('✅ AuthDatabase initialized');
  } catch (e, stackTrace) {
    debugPrint('❌ Initialization error: $e');
    debugPrintStack(stackTrace: stackTrace);
    return;
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: settings.accentColor,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: settings.accentColor,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: settings.accentColor,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: settings.accentColor,
          unselectedItemColor: Colors.grey,
        ),
      ),
      locale: settings.getLocale(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/profile':
            final user = settings.arguments as Map<String, dynamic>?;
            if (user != null) {
              return MaterialPageRoute(
                builder: (_) => ProfileScreen(user: user),
              );
            }
            break;

          case '/movie_detail':
            final args = settings.arguments;
            if (args is Map<String, dynamic> && args.containsKey('movie')) {
              return MaterialPageRoute(
                builder: (_) => MovieDetailScreen(movie: args['movie']),
              );
            } else {
              return MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body:  Center(
                    child: Text(
                      'Invalid movie data provided',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            }
        }
        return null;
      },
      routes: {
        '/search': (_) => const SearchScreen(),
        '/categories': (_) => const CategoriesScreen(),
        '/downloads': (_) => const DownloadsScreen(),
        '/interactive': (_) => const InteractiveFeaturesScreen(),
        '/mylist': (_) => const MyListScreen(),
      },
    );
  }
}
