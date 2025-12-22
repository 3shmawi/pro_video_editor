import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// A dialog that displays real-time export progress for video generation.
///
/// Listens to multiple progress sources:
/// - Native video rendering progress (timed layers, filters, transforms)
/// - FFmpeg audio merging progress
/// - FFmpeg video bubble merging progress
class VideoProgressAlert extends StatefulWidget {
  /// Creates a [VideoProgressAlert] widget.
  const VideoProgressAlert({
    super.key,
    this.taskId = '',
    this.onAudioProgress,
    this.onVideoBubbleProgress,
  });

  /// Optional taskId of the native rendering progress stream.
  final String taskId;

  /// Stream controller for audio merging progress (0.0 to 1.0)
  final StreamController<double>? onAudioProgress;

  /// Stream controller for video bubble merging progress (0.0 to 1.0)
  final StreamController<double>? onVideoBubbleProgress;

  @override
  State<VideoProgressAlert> createState() => _VideoProgressAlertState();
}

class _VideoProgressAlertState extends State<VideoProgressAlert> {
  double _audioProgress = 0.0;
  double _videoBubbleProgress = 0.0;

  StreamSubscription<double>? _audioSubscription;
  StreamSubscription<double>? _videoBubbleSubscription;

  @override
  void initState() {
    super.initState();

    if (kDebugMode) {
      print('VideoProgressAlert initState');
      print('Audio controller: ${widget.onAudioProgress}');
      print('Video bubble controller: ${widget.onVideoBubbleProgress}');
    }

    // Listen to audio progress if provided
    if (widget.onAudioProgress != null) {
      _audioSubscription = widget.onAudioProgress!.stream.listen((progress) {
        if (kDebugMode) {
          print('Audio progress received: $progress');
        }
        if (mounted) {
          setState(() {
            _audioProgress = progress;
          });
        }
      });
      if (kDebugMode) {
        print('Audio subscription created');
      }
    }

    // Listen to video bubble progress if provided
    if (widget.onVideoBubbleProgress != null) {
      _videoBubbleSubscription =
          widget.onVideoBubbleProgress!.stream.listen((progress) {
        if (kDebugMode) {
          print('Video bubble progress received: $progress');
        }
        if (mounted) {
          setState(() {
            _videoBubbleProgress = progress;
          });
        }
      });
      if (kDebugMode) {
        print('Video bubble subscription created');
      }
    }
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _videoBubbleSubscription?.cancel();
    super.dispose();
  }

  /// Calculates the overall progress based on which stages are active.
  ///
  /// The progress is weighted based on the stages that are being processed:
  /// - Native rendering: 40% of total progress
  /// - Audio merging: 30% of total progress
  /// - Video bubble merging: 30% of total progress
  double _calculateOverallProgress(double nativeProgress) {
    final hasAudio = widget.onAudioProgress != null && _audioProgress >-1;
    final hasVideoBubbles = widget.onVideoBubbleProgress != null && _videoBubbleProgress >-1;

    if (!hasAudio && !hasVideoBubbles) {
      // Only native rendering
      return nativeProgress;
    } else if (hasAudio && !hasVideoBubbles) {
      // Native + Audio
      return (nativeProgress * 0.5) + (_audioProgress * 0.5);
    } else if (!hasAudio && hasVideoBubbles) {
      // Native + Video Bubbles
      return (nativeProgress * 0.5) + (_videoBubbleProgress * 0.5);
    } else {
      // All three stages
      return (nativeProgress * 0.4) +
          (_audioProgress * 0.3) +
          (_videoBubbleProgress * 0.3);
    }
  }

  String _getProgressStage(double nativeProgress) {
    final hasAudio = widget.onAudioProgress != null && _audioProgress > -1;
    final hasVideoBubbles = widget.onVideoBubbleProgress != null && _videoBubbleProgress > -1;

    if (nativeProgress < 1.0) {
      return 'Rendering video...';
    } else if (hasAudio && _audioProgress < 1.0) {
      return 'Merging audio...';
    } else if (hasVideoBubbles && _videoBubbleProgress < 1.0) {
      return 'Adding video bubbles...';
    } else {
      return 'Finalizing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModalBarrier(
          onDismiss: kDebugMode ? LoadingDialog.instance.hide : null,
          color: Colors.black54,
          dismissible: kDebugMode,
        ),
        Center(
          child: Theme(
            data: Theme.of(context),
            child: AlertDialog(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.only(top: 3.0),
                  child: _buildProgressBody(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBody() {
    return StreamBuilder<ProgressModel>(
        stream: ProVideoEditor.instance.progressStreamById(widget.taskId),
        builder: (context, snapshot) {
          var nativeProgress = snapshot.data?.progress ?? 0;
          var overallProgress = _calculateOverallProgress(nativeProgress);
          var stage = _getProgressStage(nativeProgress);

          return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: overallProgress),
              duration: const Duration(milliseconds: 300),
              builder: (context, animatedValue, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      spacing: 10,
                      children: [
                        CircularProgressIndicator(
                          value: animatedValue,
                          // ignore: deprecated_member_use
                          year2023: false,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(animatedValue * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stage,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              });
        });
  }
}
