import 'package:flutter/widgets.dart';

import '../services/battery.dart';
import '../services/media.dart';
import '../services/weather.dart';

class Services extends InheritedWidget {
  const Services({super.key, required this.weather, required this.media, required this.battery, required super.child});

  final WeatherService weather;
  final MediaService media;
  final BatteryService battery;

  static Services of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Services>()!;

  @override
  bool updateShouldNotify(Services old) => false;
}
