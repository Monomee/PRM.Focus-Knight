import 'package:flutter/material.dart';
import '../game/sprites.dart';

const String kPixelFont = 'PixelifySans';

/// Plays a sprite strip with plain widgets (no Canvas): the full strip is laid out
/// inside a clipped square and shifted frame by frame via [Alignment].
class SpriteAnim extends StatefulWidget {
  const SpriteAnim({
    super.key,
    required this.sheet,
    required this.size,
    this.flipX = false,
    this.playing = true,
    this.fps = 10,
    this.loop = true,
    this.onComplete,
  });

  final SpriteSheet sheet;
  final double size;
  final bool flipX;
  final bool playing;
  final int fps;
  final bool loop;
  final VoidCallback? onComplete;

  @override
  State<SpriteAnim> createState() => _SpriteAnimState();
}

class _SpriteAnimState extends State<SpriteAnim> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete?.call();
    });

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SpriteAnim oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sheet != widget.sheet) _controller.value = 0;
    _sync();
  }

  void _sync() {
    _controller.duration = Duration(microseconds: widget.sheet.frames * 1000000 ~/ widget.fps);
    if (!widget.playing) {
      _controller.stop();
    } else if (widget.loop) {
      _controller.repeat();
    } else if (!_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = widget.sheet.frames;
    return SizedBox.square(
      dimension: widget.size,
      child: Transform.flip(
        flipX: widget.flipX,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final frame = (_controller.value * frames).floor().clamp(0, frames - 1);
              return OverflowBox(
                maxWidth: widget.size * frames,
                minWidth: widget.size * frames,
                maxHeight: widget.size,
                alignment: Alignment(frames == 1 ? 0 : -1 + 2 * frame / (frames - 1), 0),
                child: child,
              );
            },
            child: Image.asset(
              widget.sheet.asset,
              width: widget.size * frames,
              height: widget.size,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pixel icon from `ui/icons/<name>.png`.
class PixelIcon extends StatelessWidget {
  const PixelIcon(this.name, {super.key, this.size = 24});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'ui/icons/$name.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.none,
      );
}
