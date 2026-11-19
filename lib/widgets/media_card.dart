import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/services_scope.dart';
import '../core/settings.dart';
import '../core/style.dart';
import '../services/media.dart';
import 'ios_surface.dart';

String _mmss(int ms) {
  final s = (ms / 1000).floor();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Now Playing panel. Polls the media session only while visible.
class MediaPanel extends StatefulWidget {
  const MediaPanel({super.key, this.vertical = false});
  final bool vertical;

  @override
  State<MediaPanel> createState() => _MediaPanelState();
}

class _MediaPanelState extends State<MediaPanel> {
  late MediaService _media;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = Services.of(context).media;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _media.attach());
  }

  @override
  void dispose() {
    _media.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _media,
      builder: (context, _) {
        final t = SettingsScope.of(context).t;
        if (!_media.hasAccess) {
          return _Message(
            icon: CupertinoIcons.music_note_2,
            title: t.mediaAccessTitle,
            body: t.mediaAccessBody,
            action: t.allow,
            onAction: _media.openAccessSettings,
          );
        }
        final np = _media.current;
        if (np == null) {
          return _Message(icon: CupertinoIcons.music_note_2, title: t.notPlaying, body: t.notPlayingHint);
        }
        return _Player(np: np, media: _media, vertical: widget.vertical);
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body, this.action, this.onAction});
  final IconData icon;
  final String title, body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6482), Color(0xFFFF2D55)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 52, color: Palette.label),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: sf(26, weight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: sf(17, weight: FontWeight.w500, color: Palette.secondary, height: 1.3),
              ),
              if (action != null) ...[const SizedBox(height: 22), _Pill(label: action!, onTap: onAction)],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    color: Palette.label,
    borderRadius: BorderRadius.circular(100),
    onPressed: onTap,
    child: Text(
      label,
      style: sf(17, weight: FontWeight.w700, color: Palette.bg),
    ),
  );
}

class _Player extends StatelessWidget {
  const _Player({required this.np, required this.media, required this.vertical});
  final NowPlaying np;
  final MediaService media;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final accent = SettingsScope.of(context).accent;
    final art = np.art != null
        ? Image.memory(np.art!, fit: BoxFit.cover, gaplessPlayback: true)
        : Container(
            color: Palette.card2,
            child: const Icon(CupertinoIcons.music_note, size: 72, color: Palette.secondary),
          );

    final artBox = GestureDetector(
      onTap: media.openPlayer,
      child: AnimatedScale(
        scale: np.playing ? 1 : 0.9,
        duration: Motion.duration(context, 600),
        curve: Motion.curve,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 30, offset: Offset(0, 12))],
            ),
            clipBehavior: Clip.antiAlias,
            child: art,
          ),
        ),
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.music_note, size: 14, color: Palette.secondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                np.app,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sf(14, weight: FontWeight.w600, color: Palette.secondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          np.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: sf(30, weight: FontWeight.w800, height: 1.12),
        ),
        const SizedBox(height: 4),
        Text(
          np.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: sf(22, weight: FontWeight.w600, color: Palette.label.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 22),
        _Progress(np: np, accent: accent),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CtrlButton(icon: CupertinoIcons.backward_fill, size: 34, onTap: () => media.command('prev')),
            _CtrlButton(
              icon: np.playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              size: 48,
              onTap: () => media.command('toggle'),
            ),
            _CtrlButton(icon: CupertinoIcons.forward_fill, size: 34, onTap: () => media.command('next')),
          ],
        ),
      ],
    );

    final content = vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300), child: artBox),
              const SizedBox(height: 28),
              SizedBox(width: 360, child: info),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 260, height: 260, child: artBox),
              const SizedBox(width: 32),
              SizedBox(width: 340, child: info),
            ],
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Ambient blurred artwork
        if (np.art != null)
          Opacity(
            opacity: 0.35,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
              child: Image.memory(np.art!, fit: BoxFit.cover, gaplessPlayback: true),
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FittedBox(fit: BoxFit.contain, child: content),
          ),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.np, required this.accent});
  final NowPlaying np;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (np.duration <= 0) return const SizedBox(height: 6);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: Palette.label.withValues(alpha: 0.18)),
                FractionallySizedBox(
                  widthFactor: np.progress,
                  child: Container(color: Palette.label),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              _mmss(np.position),
              style: sf(13, weight: FontWeight.w600, color: Palette.secondary, tabular: true),
            ),
            const Spacer(),
            Text(
              '-${_mmss(np.duration - np.position)}',
              style: sf(13, weight: FontWeight.w600, color: Palette.secondary, tabular: true),
            ),
          ],
        ),
      ],
    );
  }
}

class _CtrlButton extends StatefulWidget {
  const _CtrlButton({required this.icon, required this.size, required this.onTap});
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  @override
  State<_CtrlButton> createState() => _CtrlButtonState();
}

class _CtrlButtonState extends State<_CtrlButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.82 : 1,
        duration: Motion.duration(context, 240),
        curve: Motion.curve,
        child: AnimatedContainer(
          duration: Motion.duration(context, 240),
          curve: Motion.curve,
          width: widget.size * 1.8,
          height: widget.size * 1.8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _down ? Palette.label.withValues(alpha: 0.12) : const Color(0x00000000)),
          child: AnimatedSwitcher(
            duration: Motion.duration(context, 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Icon(widget.icon, key: ValueKey(widget.icon), size: widget.size, color: Palette.label),
          ),
        ),
      ),
    );
  }
}
