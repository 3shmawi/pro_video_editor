import 'dart:async';
import 'package:flutter/material.dart';
import '../models/timed_layer_model.dart';

/// Manages timed layers and their visibility based on video playback position
class TimedLayerManager extends ChangeNotifier {
  final List<TimedLayer> _layers = [];
  int _currentTimeMs = 0;
  StreamController<int>? _positionStreamController;

  /// Get all layers
  List<TimedLayer> get layers => List.unmodifiable(_layers);

  /// Get current playback position in milliseconds
  int get currentTimeMs => _currentTimeMs;

  /// Get layers visible at current time
  List<TimedLayer> get visibleLayers {
    return _layers.where((layer) => layer.isVisibleAt(_currentTimeMs)).toList();
  }

  /// Stream of position changes
  Stream<int> get positionStream {
    _positionStreamController ??= StreamController<int>.broadcast();
    return _positionStreamController!.stream;
  }

  /// Add a new layer
  void addLayer(TimedLayer layer) {
    _layers.add(layer);
    notifyListeners();
  }

  /// Remove a layer by ID
  void removeLayer(String layerId) {
    _layers.removeWhere((layer) => layer.id == layerId);
    notifyListeners();
  }

  /// Update a layer
  void updateLayer(String layerId, TimedLayer updatedLayer) {
    final index = _layers.indexWhere((layer) => layer.id == layerId);
    if (index != -1) {
      _layers[index] = updatedLayer;
      notifyListeners();
    }
  }

  /// Get a layer by ID
  TimedLayer? getLayer(String layerId) {
    try {
      return _layers.firstWhere((layer) => layer.id == layerId);
    } catch (e) {
      return null;
    }
  }

  /// Update current playback position
  void setCurrentTime(Duration position) {
    final newTimeMs = position.inMilliseconds;
    if (_currentTimeMs != newTimeMs) {
      _currentTimeMs = newTimeMs;
      _positionStreamController?.add(_currentTimeMs);
      notifyListeners();
    }
  }

  /// Clear all layers
  void clearLayers() {
    _layers.clear();
    notifyListeners();
  }

  /// Get layers within a time range (for export)
  List<TimedLayer> getLayersInRange(int startMs, int endMs) {
    return _layers.where((layer) {
      // Check if layer overlaps with the time range
      return !(layer.endMs <= startMs || layer.startMs >= endMs);
    }).toList();
  }

  /// Adjust layer timing relative to trim
  TimedLayer adjustLayerForTrim(
      TimedLayer layer, int trimStartMs, int trimEndMs) {
    // Calculate the new start and end times relative to the trim
    int newStartMs = layer.startMs - trimStartMs;
    int newEndMs = layer.endMs - trimStartMs;

    // Clamp to the trimmed range
    newStartMs = newStartMs.clamp(0, trimEndMs - trimStartMs);
    newEndMs = newEndMs.clamp(0, trimEndMs - trimStartMs);

    return layer.copyWith(
      startMs: newStartMs,
      endMs: newEndMs,
    );
  }

  @override
  void dispose() {
    _positionStreamController?.close();
    super.dispose();
  }
}
