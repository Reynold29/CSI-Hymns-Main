import 'package:flutter/material.dart';
import 'dart:async';

/// A widget that scrolls text horizontally from right to left if it overflows
/// Similar to a marquee effect
class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration scrollDuration;
  final Duration pauseDuration;

  const ScrollingText({
    super.key,
    required this.text,
    this.style,
    this.scrollDuration = const Duration(seconds: 8),
    this.pauseDuration = const Duration(seconds: 1),
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final GlobalKey _textKey = GlobalKey();
  bool _needsScroll = false;
  double _textWidth = 0;
  double _containerWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.scrollDuration,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _needsScroll && mounted) {
        // Reset and pause before restarting
        _controller.reset();
        Future.delayed(widget.pauseDuration, () {
          if (mounted && _needsScroll) {
            _controller.forward();
          }
        });
      }
    });
  }

  void _checkIfNeedsScroll([BoxConstraints? constraints]) {
    if (!mounted) return;

    // Measure text's intrinsic width using TextPainter
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();
    final textWidth = textPainter.size.width;

    // Get container width from constraints or RenderBox
    double containerWidth = 0;

    if (constraints != null) {
      containerWidth = constraints.maxWidth;
    } else {
      final RenderBox? containerBox = context.findRenderObject() as RenderBox?;
      if (containerBox != null) {
        containerWidth = containerBox.size.width;
      }
    }

    // Only update if values actually changed
    if (textWidth > 0 && containerWidth > 0) {
      final needsScroll = textWidth > containerWidth + 2; // Add 2px tolerance

      if (needsScroll != _needsScroll ||
          (needsScroll &&
              (textWidth != _textWidth || containerWidth != _containerWidth))) {
        setState(() {
          _textWidth = textWidth;
          _containerWidth = containerWidth;
          _needsScroll = needsScroll;
        });

        if (_needsScroll) {
          _startScrolling();
        } else {
          _controller.stop();
          _controller.reset();
        }
      }
    }
  }

  void _startScrolling() {
    if (!_needsScroll || !mounted) return;

    _controller.stop();
    _controller.reset();

    Future.delayed(widget.pauseDuration, () {
      if (mounted && _needsScroll) {
        _controller.forward();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure after build completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkIfNeedsScroll(constraints);
        });

        // Render text widget for measurement - ensure it can render at full width
        final textWidget = UnconstrainedBox(
          constrainedAxis: Axis.vertical,
          alignment: Alignment.centerLeft,
          child: Text(
            widget.text,
            key: _textKey,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        );

        // If text doesn't overflow, just show it normally
        if (!_needsScroll || _textWidth <= _containerWidth || _textWidth == 0) {
          return ClipRect(
            child: textWidget,
          );
        }

        // Text overflows - animate scrolling
        // Clip to container width, but allow text to scroll at full width
        return ClipRect(
          child: SizedBox(
            width: constraints.maxWidth,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final scrollOffset =
                    (_textWidth - _containerWidth) * _animation.value;
                return Transform.translate(
                  offset: Offset(-scrollOffset, 0),
                  child: textWidget,
                );
              },
            ),
          ),
        );
      },
    );
  }
}
