import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Shared PillPaatha V2 building blocks (DESIGN-V2-SPEC.md):
/// green-gradient primary buttons, the big adherence ring,
/// segmented pills, and the status colour system for dose rows.

/// Full-width primary action button: green gradient, radius 16,
/// white SemiBold label, ≥54px tall. The label scales down instead
/// of wrapping mid-word.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.minHeight = 56,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PillTheme.actionGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: PillTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Container(
              constraints: BoxConstraints(minHeight: minHeight),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big circular adherence ring (Home / Reports): green stroke,
/// percentage in the centre. [percent] null shows "—".
class AdherenceRing extends StatelessWidget {
  const AdherenceRing({
    super.key,
    required this.percent,
    required this.caption,
    this.size = 132,
  });

  final double? percent;
  final String caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = percent == null ? 0.0 : (percent! / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Static painted ring — deliberately NOT a
          // CircularProgressIndicator: a progress indicator's
          // animation machinery never lets widget tests settle
          // (pumpAndSettle timed out on every V2 widget test).
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(value),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    percent == null ? '—' : '${percent!.round()}%',
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: PillTheme.ink,
                    ),
                  ),
                ),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PillTheme.inkSoft,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the adherence ring: light track + green arc from the
/// top, round-capped. Static — no animation controllers.
class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = PillTheme.neutralTint
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 6.28319, false, track);
    if (fraction > 0) {
      final arc = Paint()
        ..color = PillTheme.taken
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -1.5708, 6.28319 * fraction, false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

/// Segmented pills (boards): light track, selected = teal fill
/// with white text. Used for the language toggle and report ranges.
class SegmentedPills extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PillTheme.neutralTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onSelected(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: i == selectedIndex
                      ? PillTheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: i == selectedIndex
                        ? Colors.white
                        : PillTheme.inkSoft,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Colour + icon for one effective dose status (boards): taken =
/// green filled check, missed = red X, pending = hollow circle,
/// snoozed = amber clock, skipped = grey dash.
({Color color, Color tint, IconData icon}) statusStyle(
  EffectiveDoseStatus status,
) =>
    switch (status) {
      EffectiveDoseStatus.taken => (
          color: PillTheme.taken,
          tint: PillTheme.takenTint,
          icon: Icons.check_circle,
        ),
      EffectiveDoseStatus.skipped => (
          color: PillTheme.inkSoft,
          tint: PillTheme.neutralTint,
          icon: Icons.remove_circle,
        ),
      EffectiveDoseStatus.snoozed => (
          color: PillTheme.accent,
          tint: PillTheme.pendingTint,
          icon: Icons.snooze,
        ),
      EffectiveDoseStatus.missed => (
          color: PillTheme.missed,
          tint: PillTheme.missedTint,
          icon: Icons.cancel,
        ),
      EffectiveDoseStatus.pending => (
          color: PillTheme.accent,
          tint: PillTheme.pendingTint,
          icon: Icons.radio_button_unchecked,
        ),
    };

/// Filled status circle used at the right edge of a dose row:
/// a filled circle with a white glyph for recorded/derived
/// states, a hollow ring for pending.
class StatusCircle extends StatelessWidget {
  const StatusCircle({super.key, required this.status, this.size = 30});

  final EffectiveDoseStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = statusStyle(status);
    if (status == EffectiveDoseStatus.pending) {
      return Icon(
        Icons.radio_button_unchecked,
        color: PillTheme.inkSoft,
        size: size,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
      child: Icon(
        status == EffectiveDoseStatus.taken
            ? Icons.check
            : status == EffectiveDoseStatus.missed
                ? Icons.close
                : style.icon,
        color: Colors.white,
        size: size * 0.62,
      ),
    );
  }
}
