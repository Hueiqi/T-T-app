import 'package:flutter/material.dart';

class QuickTourStep {
  final GlobalKey? targetKey;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onActionTap;

  const QuickTourStep({
    this.targetKey,
    required this.title,
    required this.description,
    required this.icon,
    this.onActionTap,
  });
}

class QuickTour extends StatefulWidget {
  final List<QuickTourStep> steps;
  final VoidCallback? onFinished;
  final VoidCallback? onSkipped;
  final Widget child;

  const QuickTour({
    super.key,
    required this.steps,
    required this.child,
    this.onFinished,
    this.onSkipped,
  });

  @override
  QuickTourState createState() => QuickTourState();
}

class QuickTourState extends State<QuickTour> {
  OverlayEntry? _overlayEntry;
  int _currentStep = 0;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  void start() {
    if (widget.steps.isEmpty || _isRunning) return;
    _currentStep = 0;
    _isRunning = true;
    _showStep();
  }

  void _showStep() {
    _overlayEntry?.remove();
    if (_currentStep >= widget.steps.length) {
      _finish();
      return;
    }

    final step = widget.steps[_currentStep];
    final targetKey = step.targetKey;
    Rect? targetRect;

    if (targetKey != null && targetKey.currentContext != null) {
      final box = targetKey.currentContext!.findRenderObject() as RenderBox?;
      if (box != null) {
        final pos = box.localToGlobal(Offset.zero);
        targetRect = Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
      }
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => _TourOverlay(
        step: step,
        targetRect: targetRect,
        currentStep: _currentStep,
        totalSteps: widget.steps.length,
        onNext: _next,
        onPrevious: _previous,
        onSkip: _skip,
        onAction: _handleAction,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      _currentStep++;
      _showStep();
    } else {
      _finish();
    }
  }

  void _previous() {
    if (_currentStep > 0) {
      _currentStep--;
      _showStep();
    }
  }

  void _skip() {
    _finish();
    widget.onSkipped?.call();
  }

  void _finish() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isRunning = false;
    widget.onFinished?.call();
  }

  void _handleAction() {
    final step = widget.steps[_currentStep];
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isRunning = false;
    if (step.onActionTap != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        step.onActionTap!();
      });
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TourOverlay extends StatelessWidget {
  final QuickTourStep step;
  final Rect? targetRect;
  final int currentStep;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;
  final VoidCallback onAction;

  const _TourOverlay({
    required this.step,
    this.targetRect,
    required this.currentStep,
    required this.totalSteps,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = currentStep == 0;
    final isLast = currentStep == totalSteps - 1;
    final hasAction = step.onActionTap != null;

    return Stack(
      children: [
        // Dim background with cutout
        Positioned.fill(
          child: GestureDetector(
            onTap: onSkip,
            child: CustomPaint(
              painter: _SpotlightPainter(targetRect: targetRect),
            ),
          ),
        ),

        // Tooltip card
        if (targetRect != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).size.height - targetRect!.bottom - 16,
            child: _buildTooltip(context, isFirst, isLast, hasAction),
          )
        else
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.3,
            child: _buildTooltip(context, isFirst, isLast, hasAction),
          ),
      ],
    );
  }

  Widget _buildTooltip(BuildContext context, bool isFirst, bool isLast, bool hasAction) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(step.icon, color: const Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ),
                // Step indicator
                Text(
                  '${currentStep + 1}/$totalSteps',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              step.description,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: const Text('Skip', style: TextStyle(color: Color(0xFF6366F1))),
                ),
                const Spacer(),
                if (!isFirst)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: onPrevious,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  ),
                if (hasAction)
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Try It'),
                    ),
                  )
                else
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: isLast ? onSkip : onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(isLast ? 'Done' : 'Next',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;

  _SpotlightPainter({this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (targetRect != null) {
      final gap = targetRect!.inflate(8);
      path.addRRect(
        RRect.fromRectAndRadius(gap, const Radius.circular(12)),
      );
      path.fillType = PathFillType.evenOdd;
    }

    canvas.drawPath(path, paint);

    if (targetRect != null) {
      final borderPaint = Paint()
        ..color = const Color(0xFF6366F1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(targetRect!.inflate(8), const Radius.circular(12)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => targetRect != old.targetRect;
}


