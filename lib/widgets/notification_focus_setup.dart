import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/style.dart';
import '../services/notifications.dart';

/// Refresh special-access status after returning from Android settings.
class NotificationFocusSetup extends StatefulWidget {
  const NotificationFocusSetup({super.key});

  @override
  State<NotificationFocusSetup> createState() => _NotificationFocusSetupState();
}

class _NotificationFocusSetupState extends State<NotificationFocusSetup> with WidgetsBindingObserver {
  NotificationFocusStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await NotificationService.focusStatus();
    if (mounted) setState(() => _status = status);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onPressed: _status?.supported == true
          ? () async {
              final opened = await NotificationService.openFocusSettings();
              if (!opened && mounted) {
                setState(() => _status = const NotificationFocusStatus(supported: true, access: true, state: 'error'));
              }
            }
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('StandBy Focus', style: sf(16, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_status?.label ?? 'Checking access…', style: sf(13, color: Palette.secondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            _status?.access == true ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.chevron_right,
            size: 20,
            color: _status?.access == true ? Palette.blue : Palette.secondary,
          ),
        ],
      ),
    );
  }
}
