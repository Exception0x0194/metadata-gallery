import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'src/rust/frb_generated.dart';
import 'src/services/database_service.dart';
import 'src/services/preferences_service.dart';
import 'ui/viewmodels/home_page_viewmodel.dart';
import 'ui/viewmodels/settings_page_viewmodel.dart';
import 'ui/views/home_page.dart';
import 'ui/views/settings_page.dart';

Future<void> main() async {
  await RustLib.init();
  await setupLocators();
  setupViewmodels();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<StatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int pageIdx = 0;

  final List<Widget> pages = [HomePage(), SettingsPage()];
  final destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      label: Text("Home"),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      label: Text("Settings"),
    ),
  ];

  void onChangePageIdx(int value) {
    setState(() {
      pageIdx = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              destinations: destinations,
              selectedIndex: pageIdx,
              onDestinationSelected: (value) => onChangePageIdx(value),
            ),
            VerticalDivider(),
            Expanded(child: pages[pageIdx]),
          ],
        ),
      ),
    );
  }
}

Future<void> setupLocators() async {
  final getIt = GetIt.instance;

  // Initialize shared preferences
  final prefsService = PreferencesService();
  await prefsService.initialize();
  getIt.registerSingleton(prefsService);

  // Initialize sqlite
  final databaseService = DatabaseService();
  await databaseService.initialize();
  getIt.registerSingleton(databaseService);
}

void setupViewmodels() {
  DatabaseService dbService = GetIt.I();
  PreferencesService prefsService = GetIt.I();

  final homePageViewmodel = HomePageViewmodel();
  prefsService.addListener(() => homePageViewmodel.onPrefsChanged());
  GetIt.I.registerSingleton(homePageViewmodel);

  final settingsPageViewmodel = SettingsPageViewmodel();
  dbService.addListener(() => settingsPageViewmodel.onDatabaseChanged());
  GetIt.I.registerSingleton(settingsPageViewmodel);
}
