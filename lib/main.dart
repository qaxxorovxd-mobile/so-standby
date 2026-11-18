import 'package:flutter/services.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

import 'core/services_scope.dart';
import 'core/settings.dart';
import 'core/style.dart';
import 'screens/onboarding_screen.dart';
import 'screens/standby_screen.dart';
import 'services/battery.dart';
import 'services/media.dart';
import 'services/power.dart';
import 'services/weather.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.black,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final settings = await AppSettings.load();
  runApp(SoStandByApp(
    settings: settings,
    weather: WeatherService(settings),
    media: MediaService(),
    battery: BatteryService(),
    power: PowerService(),
  ));
}

class SoStandByApp extends StatelessWidget {
  const SoStandByApp({super.key, required this.settings, required this.weather, required this.media, required this.battery, required this.power});

  final AppSettings settings;
  final WeatherService weather;
  final MediaService media;
  final BatteryService battery;
  final PowerService power;

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: settings,
      child: Services(
        weather: weather,
        media: media,
        battery: battery,
        power: power,
        child: MaterialApp(
          title: 'So StandBy',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'Inter',
            scaffoldBackgroundColor: Colors.black,
            colorScheme: const ColorScheme.dark(primary: Color(0xFF0A84FF), surface: Colors.black),
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            pageTransitionsTheme: const PageTransitionsTheme(builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            }),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
            child: Material(
              color: Colors.black,
              child: DefaultTextStyle(style: sf(17, weight: FontWeight.w500), child: child!),
            ),
          ),
          home: settings.onboarded ? const StandbyScreen() : const OnboardingScreen(),
        ),
      ),
    );
  }
}
