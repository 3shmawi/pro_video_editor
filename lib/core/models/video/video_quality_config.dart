import 'dart:ui';

import 'video_quality_preset.dart';

/// Configuration class that defines video quality parameters.
///
/// This class encapsulates the bitrate and resolution settings for a given
/// quality preset. It provides factory constructors to create configurations
/// from presets or custom values.
class VideoQualityConfig {
  /// Creates a video quality configuration with the given parameters.
  const VideoQualityConfig({
    required this.bitrate,
    required this.resolution,
    required this.preset,
  });

  /// Creates a configuration from a [VideoQualityPreset].
  ///
  /// Returns appropriate bitrate and resolution for the given preset.
  /// For [VideoQualityPreset.custom], returns null resolution and a default
  /// bitrate of 8 Mbps.
  factory VideoQualityConfig.fromPreset(VideoQualityPreset preset) {
    switch (preset) {
      case VideoQualityPreset.ultra4K:
        return VideoQualityConfig(
          bitrate: 45000000, // 45 Mbps
          resolution: const Size(3840, 2160),
          preset: preset,
        );
      case VideoQualityPreset.k4:
        return VideoQualityConfig(
          bitrate: 35000000, // 35 Mbps
          resolution: const Size(3840, 2160),
          preset: preset,
        );
      case VideoQualityPreset.p1080High:
        return VideoQualityConfig(
          bitrate: 16000000, // 16 Mbps
          resolution: const Size(1920, 1080),
          preset: preset,
        );
      case VideoQualityPreset.p1080:
        return VideoQualityConfig(
          bitrate: 8000000, // 8 Mbps
          resolution: const Size(1920, 1080),
          preset: preset,
        );
      case VideoQualityPreset.p720High:
        return VideoQualityConfig(
          bitrate: 5000000, // 5 Mbps
          resolution: const Size(1280, 720),
          preset: preset,
        );
      case VideoQualityPreset.p720:
        return VideoQualityConfig(
          bitrate: 3000000, // 3 Mbps
          resolution: const Size(1280, 720),
          preset: preset,
        );
      case VideoQualityPreset.p480:
        return VideoQualityConfig(
          bitrate: 2500000, // 2.5 Mbps
          resolution: const Size(854, 480),
          preset: preset,
        );
      case VideoQualityPreset.low:
        return VideoQualityConfig(
          bitrate: 1000000, // 1 Mbps
          resolution: const Size(640, 360),
          preset: preset,
        );
      case VideoQualityPreset.custom:
        return VideoQualityConfig(
          bitrate: 8000000, // Default 8 Mbps
          resolution: null, // Keep original resolution
          preset: preset,
        );
    }
  }

  /// Creates a custom configuration with specific bitrate and resolution.
  ///
  /// Useful when you need fine-grained control over quality settings.
  factory VideoQualityConfig.custom({
    required int bitrate,
    Size? resolution,
  }) {
    return VideoQualityConfig(
      bitrate: bitrate,
      resolution: resolution,
      preset: VideoQualityPreset.custom,
    );
  }

  /// The target bitrate in bits per second.
  ///
  /// Higher bitrates generally result in better quality but larger file sizes.
  final int bitrate;

  /// The target resolution (width x height) for the video.
  ///
  /// If null, the original video resolution will be maintained.
  final Size? resolution;

  /// The quality preset used for this configuration.
  final VideoQualityPreset preset;

  /// Creates a copy of this configuration with optional overrides.
  VideoQualityConfig copyWith({
    int? bitrate,
    Size? resolution,
    VideoQualityPreset? preset,
  }) {
    return VideoQualityConfig(
      bitrate: bitrate ?? this.bitrate,
      resolution: resolution ?? this.resolution,
      preset: preset ?? this.preset,
    );
  }

  @override
  String toString() {
    return 'VideoQualityConfig(preset: $preset, bitrate: '
        '${bitrate ~/ 1000000}Mbps, resolution: '
        '${resolution?.width.toInt()}x${resolution?.height.toInt()})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VideoQualityConfig &&
        other.bitrate == bitrate &&
        other.resolution == resolution &&
        other.preset == preset;
  }

  @override
  int get hashCode => Object.hash(bitrate, resolution, preset);
}
