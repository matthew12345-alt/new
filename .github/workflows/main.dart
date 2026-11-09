import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'providers/task_provider.dart';
import 'screens/home_screen.dart';
import 'screens/task_detail_screen.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsProvider();
  await settings.load();

  final notifications = NotificationService.instance;
  await notifications.init(
    onTaskTapped: (id) => navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(taskId: id)),
    ),
  );

  final tasks = TaskProvider(settings);
  await tasks.init();
  final launchTaskId = await notifications.launchTaskId();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<TaskProvider>.value(value: tasks),
      ],
      child: App(initialTaskId: launchTaskId),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key, this.initialTaskId});
  final int? initialTaskId;

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F7D6E),
          brightness: b,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final themeMode =
        context.select<SettingsProvider, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Daily Tasks',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: HomeScreen(initialTaskId: initialTaskId),
    );
  }
}
