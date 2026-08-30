import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';

/// One stop on the Guided Tour: which widget to spotlight (via [targetKey])
/// and what to say about it.
class GuidedTourStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final IconData? icon;

  /// If this step's target lives on a different bottom-nav tab than the one
  /// currently showing, the tour will switch to this tab (via
  /// [GuidedTour.maybeShow]'s `onTabChange`) before spotlighting it — so a
  /// single tour can walk through every screen of the app, not just widgets
  /// that are visible on the Home tab.
  final int? tabIndex;

  const GuidedTourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.icon,
    this.tabIndex,
  });
}

/// Shows a first-launch "Guided Tour" (a.k.a. Feature Tour): a dimmed overlay
/// with a spotlight hole punched around one real widget at a time (found via
/// its [GlobalKey], so the highlight always lines up with the actual screen —
/// no hardcoded coordinates), a tooltip card explaining that part of the app,
/// and Skip / Next / Got it controls.
///
/// Usage — from the screen that owns the widgets you want to spotlight:
/// ```dart
/// WidgetsBinding.instance.addPostFrameCallback((_) {
///   GuidedTour.maybeShow(context, steps: [
///     GuidedTourStep(targetKey: _servicesKey, title: 'Services', description: '...'),
///     ...
///   ]);
/// });
/// ```
class GuidedTour {
  static const _prefsKey = 'guided_tour_seen_v1';

  /// Shows the tour once per install (persisted via SharedPreferences) unless
  /// [force] is true — pass force: true for a "Replay Tour" entry in Settings.
  static Future<void> maybeShow(
    BuildContext context, {
    required List<GuidedTourStep> steps,
    bool force = false,
    /// Called whenever the tour needs to switch bottom-nav tabs to reach a
    /// step's target (see [GuidedTourStep.tabIndex]). Typically
    /// `(i) => setState(() => _selectedIndex = i)`.
    ValueChanged<int>? onTabChange,
    /// Called once the tour is dismissed (finished or skipped) — e.g. to
    /// navigate back to the Home tab afterwards.
    VoidCallback? onTourEnd,
  }) async {
    if (steps.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool(_prefsKey) ?? false)) return;
    if (!context.mounted) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GuidedTourOverlay(
        steps: steps,
        onTabChange: onTabChange,
        onDone: () async {
          entry.remove();
          await prefs.setBool(_prefsKey, true);
          onTourEnd?.call();
        },
      ),
    );
    overlay.insert(entry);
  }

  /// Clears the "seen" flag — handy for a "Replay Tour" button.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

class _GuidedTourOverlay extends StatefulWidget {
  final List<GuidedTourStep> steps;
  final VoidCallback onDone;
  final ValueChanged<int>? onTabChange;

  const _GuidedTourOverlay({required this.steps, required this.onDone, this.onTabChange});

  @override
  State<_GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends State<_GuidedTourOverlay> {
  int _index = 0;
  int? _requestedTab;

  Rect? _targetRect() {
    final key = widget.steps[_index].targetKey;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return (topLeft & box.size).inflate(8);
  }

  /// If the current step lives on a different tab, ask the host screen to
  /// switch to it, then re-check the target's position once that tab has
  /// actually been built/painted (a couple of frames later).
  void _syncTab(int? tabIndex) {
    if (tabIndex == null || tabIndex == _requestedTab) return;
    _requestedTab = tabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTabChange?.call(tabIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      });
    });
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      widget.onDone();
    } else {
      setState(() => _index++);
    }
  }

  void _skip() => widget.onDone();

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    _syncTab(step.tabIndex);
    final rect = _targetRect();
    final screen = MediaQuery.of(context).size;
    final isLast = _index == widget.steps.length - 1;

    // Tooltip card goes below the spotlight if there's room, otherwise above it.
    final placeBelow = rect == null || (rect.bottom + 190) < screen.height;
    final cardTop = rect == null
        ? screen.height / 2 - 90
        : (placeBelow ? rect.bottom + 16 : rect.top - 190);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dimmed backdrop with a spotlight hole cut around the target widget.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SpotlightPainter(rect: rect),
              ),
            ),
          ),
          // Highlight ring around the spotlighted widget.
          if (rect != null)
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryColor, width: 2.5),
                  ),
                ),
              ),
            ),
          // Step counter, top-right.
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: Text(
              '${_index + 1} / ${widget.steps.length}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          // Tooltip card.
          Positioned(
            left: 20,
            right: 20,
            top: cardTop.clamp(
              MediaQuery.of(context).padding.top + 40,
              screen.height - 210,
            ),
            child: _TourCard(
              step: step,
              isLast: isLast,
              onSkip: _skip,
              onNext: _next,
            ),
          ),
        ],
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  final GuidedTourStep step;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _TourCard({
    required this.step,
    required this.isLast,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (step.icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(step.icon, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(step.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(step.description, style: TextStyle(fontSize: 13.5, color: Colors.grey[700], height: 1.4)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onSkip,
                child: const Text('Skip', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                child: Text(isLast ? 'Got it' : 'Next', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Paints a semi-transparent black backdrop over the whole screen with a
/// rounded-rect "hole" cut out around [rect] so the real widget underneath
/// shows through untouched — that's the spotlight effect.
class _SpotlightPainter extends CustomPainter {
  final Rect? rect;
  _SpotlightPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final backdrop = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (rect == null) {
      canvas.drawPath(backdrop, Paint()..color = Colors.black.withValues(alpha: 0.75));
      return;
    }
    final hole = Path()..addRRect(RRect.fromRectAndRadius(rect!, const Radius.circular(16)));
    final punched = Path.combine(PathOperation.difference, backdrop, hole);
    canvas.drawPath(punched, Paint()..color = Colors.black.withValues(alpha: 0.75));
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => oldDelegate.rect != rect;
}