import 'package:flutter/material.dart';

class QuickTourStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onActionTap;

  const QuickTourStep({
    required this.targetKey,
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
    this.onFinished,
    this.onSkipped,
    required this.child,
  });

  @override
  State<QuickTour> createState() => QuickTourState();
}

class QuickTourState extends State<QuickTour> {
  int _currentStep = -1;
  OverlayEntry? _overlayEntry;

  bool get isActive => _currentStep >= 0;

  void start() {
    if (widget.steps.isEmpty) return;
    setState(() => _currentStep = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay());
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (_) => _QuickTourOverlayContent(
        step: widget.steps[_currentStep],
        currentIndex: _currentStep,
        totalSteps: widget.steps.length,
        onNext: _next,
        onPrevious: _previous,
        onSkip: _skip,
        onFinish: _finish,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
      _refreshOverlay();
    } else {
      _finish();
    }
  }

  void _previous() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _refreshOverlay();
    }
  }

  void _skip() {
    _removeOverlay();
    setState(() => _currentStep = -1);
    widget.onSkipped?.call();
  }

  void _finish() {
    _removeOverlay();
    setState(() => _currentStep = -1);
    widget.onFinished?.call();
  }

  void _refreshOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay());
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _QuickTourOverlayContent extends StatefulWidget {
  final QuickTourStep step;
  final int currentIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  const _QuickTourOverlayContent({
    required this.step,
    required this.currentIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    required this.onFinish,
  });

  @override
  State<_QuickTourOverlayContent> createState() =>
      _QuickTourOverlayContentState();
}

class _QuickTourOverlayContentState extends State<_QuickTourOverlayContent> {
  Rect? _targetRect;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locateTarget());
  }

  @override
  void didUpdateWidget(covariant _QuickTourOverlayContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isReady = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _locateTarget());
  }

  void _locateTarget() {
    final key = widget.step.targetKey;
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      if (mounted) {
        setState(() {
          _targetRect = Rect.fromLTWH(
            position.dx, position.dy, size.width, size.height,
          );
          _isReady = true;
        });
      }
    }
  }

  void _handleActionTap() {
    if (widget.step.onActionTap != null) {
      widget.onFinish();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.step.onActionTap!();
      });
    } else {
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        GestureDetector(
          onTap: _isReady ? widget.onNext : null,
          child: RepaintBoundary(
            child: CustomPaint(
              size: screenSize,
              painter: _HolePainter(
                holeRect: _targetRect,
                screenSize: screenSize,
              ),
            ),
          ),
        ),
        if (_isReady && _targetRect != null)
          Positioned(
            left: _targetRect!.left - 4,
            top: _targetRect!.top - 4,
            width: _targetRect!.width + 8,
            height: _targetRect!.height + 8,
            child: GestureDetector(
              onTap: _handleActionTap,
              child: const SizedBox.expand(),
            ),
          ),
        if (_isReady && _targetRect != null)
          _buildTooltipCard(screenSize),
        if (_isReady)
          _buildBottomBar(screenSize),
      ],
    );
  }

  Widget _buildTooltipCard(Size screenSize) {
    final rect = _targetRect!;
    final tooltipTop = rect.bottom + 16;
    final cardHeight = widget.step.onActionTap != null ? 280.0 : 200.0;
    final fitsBelow = tooltipTop + cardHeight < screenSize.height;

    final double top;
    if (fitsBelow) {
      top = tooltipTop;
    } else {
      top = (rect.top - cardHeight - 16).clamp(16.0, screenSize.height - cardHeight - 80);
    }

    return Positioned(
      left: 16,
      right: 16,
      top: top,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.step.icon,
                      color: const Color(0xFF6366F1),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.step.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1B4B),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.currentIndex + 1}/${widget.totalSteps}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.step.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4F46E5),
                  height: 1.4,
                ),
              ),
              if (widget.step.onActionTap != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleActionTap,
                    icon: const Icon(Icons.touch_app, size: 20),
                    label: const Text('Try It Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(Size screenSize) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            TextButton(
              onPressed: widget.onSkip,
              child: const Text(
                'Skip Tour',
                style: TextStyle(color: Color(0xFF6366F1)),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.currentIndex > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: widget.onPrevious,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Icon(Icons.arrow_back, size: 20),
                      ),
                    ),
                  ),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed:
                        widget.currentIndex < widget.totalSteps - 1
                            ? widget.onNext
                            : widget.onFinish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.currentIndex < widget.totalSteps - 1
                          ? 'Next'
                          : 'Done',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
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

class _HolePainter extends CustomPainter {
  final Rect? holeRect;
  final Size screenSize;

  _HolePainter({required this.holeRect, required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (holeRect == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.55),
      );
      return;
    }

    final hole = holeRect!.inflate(8);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, screenSize.width, screenSize.height))
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(16)));

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, const Radius.circular(16)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HolePainter oldDelegate) =>
      oldDelegate.holeRect != holeRect || oldDelegate.screenSize != screenSize;
}
