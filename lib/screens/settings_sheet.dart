import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart' show showModalBottomSheet;

import '../core/settings.dart';
import '../core/style.dart';
import '../core/services_scope.dart';
import '../services/power.dart';
import '../services/weather.dart';
import 'onboarding_screen.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0x00000000),
    barrierColor: const Color(0x99000000),
    builder: (_) => const _SettingsSheet(),
  );
}

void _preview(BuildContext context, ChargeKind kind) {
  final size = MediaQuery.of(context).size;
  final power = Services.of(context).power;
  final level = Services.of(context).battery.level;
  Navigator.of(context).pop();
  Future.delayed(const Duration(milliseconds: 350), () {
    power.simulate(kind, landscape: size.width > size.height, level: level < 0 ? null : level);
  });
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final t = s.t;
    final mq = MediaQuery.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600, maxHeight: mq.size.height * 0.94),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0E0E10),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(width: 38, height: 5, decoration: BoxDecoration(color: Palette.tertiary, borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
              child: Row(children: [
                Text(t.settings, style: sf(28, weight: FontWeight.w800)),
                const Spacer(),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.done, style: sf(17, weight: FontWeight.w700, color: Palette.blue)),
                ),
              ]),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + mq.padding.bottom),
                children: [
                  _Group(title: t.appearance, children: [
                    _AccentRow(s: s),
                    _SwitchRow(label: t.use24h, value: s.use24h, onChanged: (v) => s.use24h = v),
                    _SwitchRow(label: t.showSeconds, value: s.showSeconds, onChanged: (v) => s.showSeconds = v),
                    _SwitchRow(label: t.smoothSeconds, value: s.smoothSeconds, onChanged: (v) => s.smoothSeconds = v),
                  ]),
                  _Group(title: t.nightMode, footer: t.nightModeFooter, children: [
                    _SegRow<NightMode>(
                      value: s.nightMode,
                      items: {NightMode.off: t.off, NightMode.auto: t.auto, NightMode.on: t.on},
                      onChanged: (v) => s.nightMode = v,
                    ),
                  ]),
                  _Group(title: t.weather, children: [
                    _SegRow<bool>(
                      label: t.units,
                      value: s.fahrenheit,
                      items: const {false: '°C', true: '°F'},
                      onChanged: (v) => s.fahrenheit = v,
                    ),
                    const _CityRow(),
                  ]),
                  _Group(
                    title: 'Charging',
                    footer: 'When you plug in, So StandBy jumps to Batteries and plays an animation. '
                        'With a cable it flies in from the USB-C port side; with wireless charging it starts in the center.',
                    children: [
                      _SwitchRow(label: 'Charging Animation', value: s.chargeAnimation, onChanged: (v) => s.chargeAnimation = v),
                      _NavRow(label: 'Preview: Cable (USB-C)', onTap: () => _preview(context, ChargeKind.wired)),
                      _NavRow(label: 'Preview: Wireless', onTap: () => _preview(context, ChargeKind.wireless)),
                    ],
                  ),
                  _Group(title: t.display, footer: t.burnInFooter, children: [
                    _SwitchRow(label: t.keepAwake, value: s.keepAwake, onChanged: (v) => s.keepAwake = v),
                    _SwitchRow(label: t.burnIn, value: s.burnIn, onChanged: (v) => s.burnIn = v),
                  ]),
                  _Group(children: [
                    _NavRow(
                      label: t.permissions,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => const OnboardingScreen(fromSettings: true)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Center(child: Text('So StandBy · 1.2.0', style: sf(13, weight: FontWeight.w600, color: Palette.tertiary))),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({this.title, this.footer, required this.children});
  final String? title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Container(margin: const EdgeInsets.only(left: 16), height: 0.5, color: Palette.separator));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 7),
            child: Text(title!.toUpperCase(), style: sf(13, weight: FontWeight.w600, color: Palette.secondary, tracking: 0.4)),
          ),
        Container(
          decoration: BoxDecoration(color: Palette.card, borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
            child: Text(footer!, style: sf(13, weight: FontWeight.w500, color: Palette.secondary, height: 1.35)),
          ),
      ]),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: Text(label, style: sf(17, weight: FontWeight.w500))),
            CupertinoSwitch(
              value: value,
              activeTrackColor: Palette.green,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ]),
        ),
      );
}

class _SegRow<T extends Object> extends StatelessWidget {
  const _SegRow({this.label, required this.value, required this.items, required this.onChanged});
  final String? label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final seg = CupertinoSlidingSegmentedControl<T>(
      groupValue: value,
      backgroundColor: const Color(0xFF2C2C2E),
      thumbColor: const Color(0xFF636366),
      children: {
        for (final e in items.entries)
          e.key: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(e.value, style: sf(14, weight: FontWeight.w600)),
          ),
      },
      onValueChanged: (v) {
        if (v == null) return;
        HapticFeedback.selectionClick();
        onChanged(v);
      },
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: label == null
          ? SizedBox(width: double.infinity, child: seg)
          : Row(children: [
              const SizedBox(width: 4),
              Expanded(child: Text(label!, style: sf(17, weight: FontWeight.w500))),
              seg,
            ]),
    );
  }
}

class _AccentRow extends StatelessWidget {
  const _AccentRow({required this.s});
  final AppSettings s;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.t.accent, style: sf(17, weight: FontWeight.w500)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final c in Accents.all)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                s.accent = c;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: s.accent.toARGB32() == c.toARGB32() ? Palette.label : const Color(0x00000000),
                    width: 2.5,
                  ),
                ),
                child: DecoratedBox(decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: Text(label, style: sf(17, weight: FontWeight.w500))),
              const Icon(CupertinoIcons.chevron_forward, size: 18, color: Palette.tertiary),
            ]),
          ),
        ),
      );
}

class _CityRow extends StatefulWidget {
  const _CityRow();

  @override
  State<_CityRow> createState() => _CityRowState();
}

class _CityRowState extends State<_CityRow> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppSettings s) async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await WeatherService.searchCity(q, s.lang.name);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) {
      setState(() => _error = s.t.cityNotFound);
      return;
    }
    _ctrl.clear();
    FocusScope.of(context).unfocus();
    await s.setManualCity(r.$1, r.$2, r.$3);
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final t = s.t;
    final manual = s.manualCity != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t.location, style: sf(17, weight: FontWeight.w500))),
          if (manual)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              onPressed: () => s.setManualCity(null, null, null),
              child: Row(children: [
                const Icon(CupertinoIcons.location_fill, size: 15, color: Palette.blue),
                const SizedBox(width: 4),
                Text(t.currentLocation, style: sf(15, weight: FontWeight.w600, color: Palette.blue)),
              ]),
            )
          else
            Row(children: [
              const Icon(CupertinoIcons.location_fill, size: 15, color: Palette.secondary),
              const SizedBox(width: 4),
              Text(t.currentLocation, style: sf(15, weight: FontWeight.w600, color: Palette.secondary)),
            ]),
        ]),
        if (manual)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s.manualCity!, style: sf(15, weight: FontWeight.w700, color: Palette.label)),
          ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: CupertinoTextField(
              controller: _ctrl,
              placeholder: t.cityHint,
              placeholderStyle: sf(15, weight: FontWeight.w500, color: Palette.tertiary),
              style: sf(15, weight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Palette.card2, borderRadius: BorderRadius.circular(10)),
              textInputAction: TextInputAction.search,
              cursorColor: Palette.blue,
              onSubmitted: (_) => _submit(s),
            ),
          ),
          const SizedBox(width: 8),
          _busy
              ? const Padding(padding: EdgeInsets.all(10), child: CupertinoActivityIndicator())
              : CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(0, 0),
                  onPressed: () => _submit(s),
                  child: const Icon(CupertinoIcons.search, color: Palette.blue),
                ),
        ]),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!, style: sf(13, weight: FontWeight.w600, color: Palette.red)),
          ),
      ]),
    );
  }
}
