import 'package:flutter/material.dart';
import '../../../core/models/timed_layer_model.dart';
import '../../../core/managers/timed_layer_manager.dart';

/// Widget that displays timed overlays on top of the video player
class TimedOverlayWidget extends StatelessWidget {
  final TimedLayerManager layerManager;
  final Size videoSize;

  const TimedOverlayWidget({
    super.key,
    required this.layerManager,
    required this.videoSize,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: layerManager,
      builder: (context, child) {
        final visibleLayers = layerManager.visibleLayers;

        return Stack(
          children: visibleLayers.map((layer) {
            return _buildLayerWidget(layer);
          }).toList(),
        );
      },
    );
  }

  Widget _buildLayerWidget(TimedLayer layer) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment(
          layer.position.dx,
          layer.position.dy,
        ),
        child: Transform.rotate(
          angle: layer.rotation,
          child: Transform.scale(
            scale: layer.scale,
            child: Opacity(
              opacity: layer.opacity,
              child: _buildLayerContent(layer),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayerContent(TimedLayer layer) {
    switch (layer.type) {
      case TimedLayerType.text:
        return _buildTextLayer(layer);
      case TimedLayerType.arrow:
        return _buildArrowLayer(layer);
      case TimedLayerType.sticker:
        return _buildStickerLayer(layer);
      case TimedLayerType.emoji:
        return _buildEmojiLayer(layer);
      case TimedLayerType.drawing:
        return _buildDrawingLayer(layer);
      case TimedLayerType.shape:
        return _buildShapeLayer(layer);
    }
  }

  Widget _buildTextLayer(TimedLayer layer) {
    return Text(
      layer.content.toString(),
      style: TextStyle(
        color: layer.color ?? Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildArrowLayer(TimedLayer layer) {
    return CustomPaint(
      size: const Size(100, 100),
      painter: ArrowPainter(
        color: layer.color ?? Colors.red,
        strokeWidth: 4,
      ),
    );
  }

  Widget _buildStickerLayer(TimedLayer layer) {
    // Assume content is an image path or widget
    if (layer.content is String) {
      return Image.asset(
        layer.content,
        width: 100,
        height: 100,
        fit: BoxFit.contain,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildEmojiLayer(TimedLayer layer) {
    return Text(
      layer.content.toString(),
      style: const TextStyle(fontSize: 48),
    );
  }

  Widget _buildDrawingLayer(TimedLayer layer) {
    // For drawing layers, content would be path data
    return CustomPaint(
      size: const Size(200, 200),
      painter: DrawingPainter(
        color: layer.color ?? Colors.blue,
      ),
    );
  }

  Widget _buildShapeLayer(TimedLayer layer) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: layer.color?.withOpacity(0.5),
        border: Border.all(
          color: layer.color ?? Colors.white,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Custom painter for arrow
class ArrowPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  ArrowPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arrowPath = Path();

    // Draw arrow shaft
    arrowPath.moveTo(size.width * 0.1, size.height * 0.5);
    arrowPath.lineTo(size.width * 0.7, size.height * 0.5);

    // Draw arrowhead
    arrowPath.lineTo(size.width * 0.6, size.height * 0.3);
    arrowPath.moveTo(size.width * 0.7, size.height * 0.5);
    arrowPath.lineTo(size.width * 0.6, size.height * 0.7);

    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(ArrowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Custom painter for drawings
class DrawingPainter extends CustomPainter {
  final Color color;

  DrawingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Example drawing - you would replace this with actual path data
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.5);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.2,
      size.width * 0.8,
      size.height * 0.5,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
