import 'package:flutter/material.dart';

/// Represents a visual overlay (text, arrow, graphic) with timing information
class TimedLayer {
  /// Unique identifier for this layer
  final String id;

  /// Type of layer (text, arrow, sticker, etc.)
  final TimedLayerType type;

  /// Start time in milliseconds when this layer should appear
  final int startMs;

  /// End time in milliseconds when this layer should disappear
  final int endMs;

  /// Layer content/data (text content, image path, etc.)
  final dynamic content;

  /// Position offset from center (in percentage: -1.0 to 1.0)
  final Offset position;

  /// Scale factor
  final double scale;

  /// Rotation in radians
  final double rotation;

  /// Color (for text and drawing layers)
  final Color? color;

  /// Opacity (0.0 to 1.0)
  final double opacity;

  const TimedLayer({
    required this.id,
    required this.type,
    required this.startMs,
    required this.endMs,
    required this.content,
    this.position = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.color,
    this.opacity = 1.0,
  });

  /// Check if this layer should be visible at the given time
  bool isVisibleAt(int currentMs) {
    return currentMs >= startMs && currentMs < endMs;
  }

  /// Create a copy with updated values
  TimedLayer copyWith({
    String? id,
    TimedLayerType? type,
    int? startMs,
    int? endMs,
    dynamic content,
    Offset? position,
    double? scale,
    double? rotation,
    Color? color,
    double? opacity,
  }) {
    return TimedLayer(
      id: id ?? this.id,
      type: type ?? this.type,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      content: content ?? this.content,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
    );
  }

  /// Convert to JSON for storage/export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'startMs': startMs,
      'endMs': endMs,
      'content': content,
      'positionX': position.dx,
      'positionY': position.dy,
      'scale': scale,
      'rotation': rotation,
      'color': color?.value,
      'opacity': opacity,
    };
  }

  /// Create from JSON
  factory TimedLayer.fromJson(Map<String, dynamic> json) {
    return TimedLayer(
      id: json['id'],
      type: TimedLayerType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      startMs: json['startMs'],
      endMs: json['endMs'],
      content: json['content'],
      position: Offset(json['positionX'], json['positionY']),
      scale: json['scale'],
      rotation: json['rotation'],
      color: json['color'] != null ? Color(json['color']) : null,
      opacity: json['opacity'],
    );
  }
}

/// Types of timed layers
enum TimedLayerType {
  text,
  arrow,
  sticker,
  emoji,
  drawing,
  shape,
}
