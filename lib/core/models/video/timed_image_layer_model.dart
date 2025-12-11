import 'package:flutter/foundation.dart';

/// Represents an image overlay that appears at a specific time range in a video.
///
/// This model is used to add timed overlays during video export. Multiple
/// [TimedImageLayer] instances can be used to create complex overlay sequences.
///
/// Example:
/// ```dart
/// final layer = TimedImageLayer(
///   imageBytes: overlayImageBytes,
///   startTime: Duration(seconds: 2),
///   endTime: Duration(seconds: 5),
/// );
/// ```
class TimedImageLayer {
  /// Creates a [TimedImageLayer] with the given parameters.
  ///
  /// The [imageBytes] parameter contains the image data (PNG, JPG, etc.).
  /// The [startTime] is when the overlay should appear.
  /// The [endTime] is when the overlay should disappear.
  ///
  /// Throws an [AssertionError] if [startTime] is not before [endTime].
  const TimedImageLayer({
    required this.imageBytes,
    required this.startTime,
    required this.endTime,
  }) : assert(
          startTime < endTime,
          'startTime must be before endTime',
        );

  /// The image data as bytes (PNG, JPG, WebP, etc.).
  ///
  /// This image will be scaled to match the video dimensions during rendering.
  final Uint8List imageBytes;

  /// The time when this overlay should start appearing.
  ///
  /// This must be less than [endTime].
  final Duration startTime;

  /// The time when this overlay should stop appearing.
  ///
  /// This must be greater than [startTime].
  final Duration endTime;

  /// Checks if this layer should be visible at the given time.
  ///
  /// Returns `true` if [currentTime] is between [startTime] and [endTime]
  /// (inclusive), `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final layer = TimedImageLayer(
  ///   imageBytes: bytes,
  ///   startTime: Duration(seconds: 2),
  ///   endTime: Duration(seconds: 5),
  /// );
  ///
  /// layer.isVisibleAt(Duration(seconds: 1)); // false
  /// layer.isVisibleAt(Duration(seconds: 3)); // true
  /// layer.isVisibleAt(Duration(seconds: 6)); // false
  /// ```
  bool isVisibleAt(Duration currentTime) {
    return currentTime >= startTime && currentTime <= endTime;
  }

  /// Converts the model to a map suitable for platform channel communication.
  ///
  /// The map contains:
  /// - `imageBytes`: The image data
  /// - `startTimeUs`: Start time in microseconds
  /// - `endTimeUs`: End time in microseconds
  Map<String, dynamic> toMap() {
    return {
      'imageBytes': imageBytes,
      'startTimeUs': startTime.inMicroseconds,
      'endTimeUs': endTime.inMicroseconds,
    };
  }

  /// Creates a copy of this layer with the given fields replaced.
  ///
  /// If a parameter is not provided, the existing value is used.
  TimedImageLayer copyWith({
    Uint8List? imageBytes,
    Duration? startTime,
    Duration? endTime,
  }) {
    return TimedImageLayer(
      imageBytes: imageBytes ?? this.imageBytes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TimedImageLayer &&
        listEquals(other.imageBytes, imageBytes) &&
        other.startTime == startTime &&
        other.endTime == endTime;
  }

  @override
  int get hashCode {
    return imageBytes.hashCode ^ startTime.hashCode ^ endTime.hashCode;
  }

  @override
  String toString() {
    return 'TimedImageLayer(startTime: $startTime, endTime: $endTime, imageSize: ${imageBytes.length} bytes)';
  }
}
