import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'frame_extractor.dart';
import 'reliability_manager.dart';

// --- DTOs ---

class DetectionStatus {
  static const safe = const DetectionStatus._('safe');
  static const warning = const DetectionStatus._('warning');
  static const danger = const DetectionStatus._('danger');

  final String name;
  const DetectionStatus._(this.name);

  @override
  String toString() => name;
}

class DeepfakeState {
  final double rawScore;
  final double confidence; // Legacy EMA
  final DetectionStatus status;

  // v4.5 Hybrid Metadata
  final double fftScore;
  final double fftVariance;
  final bool isPenalized;
  final double aiScore;
  final double finalScore; // Native calculated
  final double interval;

  DeepfakeState({
    required this.rawScore,
    required this.confidence,
    required this.status,
    this.fftScore = 0.0,
    this.fftVariance = 0.0,
    this.isPenalized = false,
    this.aiScore = 0.0,
    this.finalScore = 0.0,
    this.interval = 1.25,
    this.cpuUsage = 0.0,
    this.memoryUsage = 0.0,
    this.thermalState = 'nominal',
  });

  // System Stats
  final double cpuUsage;
  final double memoryUsage;
  final String thermalState;

  @override
  String toString() =>
      'State(final: $finalScore, status: ${status.name}, interval: $interval)';
}

// --- Service ---

class DeepfakeInferenceService {
  // Original Method Channel (Dart → Swift → Dart)
  static const MethodChannel _channel = MethodChannel(
    'com.garim.eye/inference',
  );

  // Native-First Pipeline channels
  static const EventChannel _nativeEventChannel = EventChannel(
    'com.garim.eye/native_inference',
  );
  static const MethodChannel _nativeControlChannel = MethodChannel(
    'com.garim.eye/native_control',
  );

  final FrameExtractor _frameExtractor = FrameExtractor();
  StreamSubscription? _frameSub;
  StreamSubscription? _nativeResultSub; // For native event channel

  // Intelligent Engine State
  final _stateController = StreamController<DeepfakeState>.broadcast();
  Stream<DeepfakeState> get stateStream => _stateController.stream;

  final _autoStopController = StreamController<void>.broadcast();
  Stream<void> get autoStopStream => _autoStopController.stream;

  // EMA State
  // Reliability Manager
  final ReliabilityManager _reliabilityManager = ReliabilityManager();

  // Logging
  IOSink? _logSink;

  // Pipeline Stats
  int _pipelineFpsCounter = 0;
  DateTime _lastFpsTime = DateTime.now();

  Future<void> initialize() async {
    debugPrint("[InferenceService] Initialized (Full-Native Pipeline).");
  }

  Future<void> start(MediaStreamTrack track) async {
    // Phase 4.5: Attach Native Sink (PRIORITY 1) - Must happen before anything else
    debugPrint(
      "🚀 [InferenceService] STARTING PIPELINE for track: ${track.id}",
    );
    try {
      debugPrint("🔗 [InferenceService] Attempting to attach native sink...");
      final result = await _nativeControlChannel.invokeMethod('attach', {
        'trackId': track.id,
      });
      debugPrint("✅ [InferenceService] Native sink attached result: $result");
    } catch (e) {
      debugPrint("❌ [InferenceService] Failed to attach native sink: $e");
    }

    await _initLogger();

    // Subscribe to native event channel for results
    _nativeResultSub = _nativeEventChannel.receiveBroadcastStream().listen(
      (result) {
        if (result is Map) {
          _handleNativeResult(Map<String, dynamic>.from(result));
        }
      },
      onError: (error) {
        debugPrint("❌ [InferenceService] Native channel error: $error");
      },
    );

    // Pure Native Mode: Disable Dart frame extraction to verify Native connection
    // v5.0 Optimization: If Native Sink attached successfully, DO NOT run Dart extraction
    // logic: We blindly attached above. Ideally we track result.
    // simpler: Let's assume Native is PRIMARY. Only run Dart if Native failed?
    // consistent with plan: "Ensure Dart-side _frameExtractor is PAUSED"
    // We simply COMMENT OUT the startExtraction for now as we are 100% native.
    // RESTORED: Native Sink proved unreliable/silent. We enable Dart as backup.
    await _frameExtractor.startExtraction(track);

    // Process all frames for maximum accuracy
    // Expected: 20 frames in ~3 seconds at 16.8 FPS
    _frameSub = _frameExtractor.frameStream.listen((bytes) {
      unawaited(_handleFrame(bytes));
    });

    debugPrint(
      "[InferenceService] Pipeline Started (Dart -> Swift Bridge Restored).",
    );
  }

  Future<void> _handleFrame(Uint8List bytes) async {
    try {
      // 1. Send to Native Pipeline
      //    We send raw bytes. Native does Detection -> Crop -> Buffer -> Inference.
      final result = await _channel.invokeMethod('processFrame', bytes);

      if (result != null && result is Map) {
        _handleNativeResult(result);
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [InferenceService] Pipeline Error: $e");
      debugPrint("Stack trace: $stackTrace");
    }
  }

  void _handleNativeResult(Map result) {
    // debugPrint("🔄 [InferenceService] Processing native result: $result");
    final status = result['status'] as String;
    // debugPrint("📊 [InferenceService] Status: $status");

    // Update Pipeline FPS
    _pipelineFpsCounter++;
    final now = DateTime.now();
    if (now.difference(_lastFpsTime).inSeconds >= 1) {
      final fps = _pipelineFpsCounter;
      // Log FPS
      _logSink?.writeln("${now.toIso8601String()},PIPELINE_FPS,,,,,$fps");
      _pipelineFpsCounter = 0;
      _lastFpsTime = now;
    }

    final detectMs = (result['detection_ms'] as num?)?.toDouble() ?? 0.0;
    final cropMs = (result['cropping_ms'] as num?)?.toDouble() ?? 0.0;

    if (status == "skipped" || status == "collecting") {
      // debugPrint("⏭️ [InferenceService] Frame skipped/collecting: $status");
      // Do NOT emit state update here to prevent UI flicker (0.0 score)
      return;
    }

    // v5.1 Auto-Stop Handling
    if (status == "auto_stopped") {
      debugPrint("🛑 [InferenceService] Auto-Stop Triggered (5m Stability).");
      _autoStopController.add(null);
      // We don't stop() immediately here, we let the UI decide?
      // Actually plan says "Completely stop".
      stop();
      return;
    }

    if (status == "inference") {
      final score = (result['score'] as num?)?.toDouble() ?? 0.0;
      final inferMs = (result['inference_ms'] as num?)?.toDouble() ?? 0.0;

      // v4.5 Metadata
      final fftScore = (result['fft_score'] as num?)?.toDouble() ?? 0.0;
      final fftVariance = (result['fft_variance'] as num?)?.toDouble() ?? 0.0;
      final isPenalized = (result['is_penalized'] as bool?) ?? false;
      final aiScore = (result['ai_score'] as num?)?.toDouble() ?? 0.0;
      final finalScore = (result['final_score'] as num?)?.toDouble() ?? 0.0;
      final interval = (result['interval'] as num?)?.toDouble() ?? 1.25;

      // System Stats
      final sys = result['system_usage'] as Map? ?? {};
      final cpuUsage = (sys['cpu_usage'] as num?)?.toDouble() ?? 0.0;
      final memoryUsage = (sys['memory_mb'] as num?)?.toDouble() ?? 0.0;
      final thermalState = (sys['thermal_state'] as String?) ?? 'unknown';

      // Intelligent Engine Logic
      _processIntelligentScore(
        score,
        detectMs,
        cropMs,
        inferMs,
        fftScore,
        fftVariance,
        isPenalized,
        aiScore,
        finalScore,
        interval,
        cpuUsage,
        memoryUsage,
        thermalState,
      );
    }
  }

  // --- Intelligent Reliability Engine ---

  void _processIntelligentScore(
    double rawCnnScore,
    double detectMs,
    double cropMs,
    double inferMs,
    double fftScore,
    double fftVariance,
    bool isPenalized,
    double aiScore,
    double finalScore,
    double interval,
    double cpuUsage,
    double memoryUsage,
    String thermalState,
  ) {
    // v4.5 Logic: Trust Native Final Score (0.0 ~ 10.0)
    // Map Final Score to DetectionStatus
    // Safe: >= 9.5 (Ultra), >= 8.0 (High)
    // Warning: ???
    // The previous logic used 0.7 (7.0) threshold for Danger.

    // v5.2 Reliability Logic: Use Weighted Moving Average
    // Input: finalScore (0.0 ~ 100.0) IS A DANGER SCORE (High = Fake)
    // We need a SAFETY SCORE for Reliability (High = Real/Safe)
    double safetyScore = 100.0 - finalScore;

    // Invert Component Scores for UI (Display Safety instead of Danger)
    // AI Score (0~90 Danger) -> (0~90 Safety)
    double safetyAiScore = 90.0 - aiScore;
    if (safetyAiScore < 0) safetyAiScore = 0.0;

    // FFT Score (0~10 Danger) -> (0~10 Safety)
    double safetyFftScore = 10.0 - fftScore;
    if (safetyFftScore < 0) safetyFftScore = 0.0;

    // Output: reliableScore (0.0 ~ 100.0) -> High means Safe
    final double reliableScore = _reliabilityManager.addAndCalculate(
      safetyScore,
    );

    DetectionStatus status;
    String triggerType = "HYBRID_v4.5";

    // v5.3 CORRECTED Reliability Score Thresholds (Applied to reliableScore)
    // Score Interpretation: 100 = Safe (Real), 0 = Danger (Deepfake)
    // Safe: > 40.0 (High confidence in being real)
    // Warning: 25.0 ~ 40.0 (Uncertain)
    // Danger: < 25.0 (High confidence in being deepfake)
    if (reliableScore > 40.0) {
      status = DetectionStatus.safe;
    } else if (reliableScore > 25.0) {
      status = DetectionStatus.warning;
    } else {
      status = DetectionStatus.danger;
    }

    final state = DeepfakeState(
      rawScore: rawCnnScore,
      confidence:
          reliableScore / 100.0, // Norm 0.0-1.0 for UI % using Smoothed Score
      status: status,
      fftScore: safetyFftScore, // Display Safety Score
      fftVariance: fftVariance,
      isPenalized: isPenalized,
      aiScore: safetyAiScore, // Display Safety Score
      finalScore: safetyScore, // Display Safety Score
      interval: interval,
      cpuUsage: cpuUsage,
      memoryUsage: memoryUsage,
      thermalState: thermalState,
    );
    _stateController.add(state);

    // 6. Log
    _logInference(
      state,
      fftScore,
      triggerType,
      detectMs,
      cropMs,
      inferMs,
      cpuUsage,
      memoryUsage,
      reliableScore, // Log valid smoothed score
    );

    // debugPrint(
    //   "🎯 [Engine] Hybrid: ${finalScore.toStringAsFixed(2)} | AI: $aiScore | FFT: $fftScore | Interval: $interval",
    // );
  }

  // --- Logging & Utilities ---

  Future<void> _initLogger() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${docDir.path}/logs');
      if (!await logDir.exists()) await logDir.create(recursive: true);

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final logFile = File('${logDir.path}/log_native_$timestamp.txt');

      _logSink = logFile.openWrite();
      _logSink?.writeln(
        'Timestamp,Raw_CNN,Raw_FFT,Fused,EMA,Status,Trigger_Type,Detect_ms,Crop_ms,Inference_ms,Pipeline_FPS,CPU,Memory,Reliable_Score',
      );
    } catch (e) {
      debugPrint("[InferenceService] Failed to init logger: $e");
    }
  }

  void _logInference(
    DeepfakeState state,
    double fft,
    String trigger,
    double detectMs,
    double cropMs,
    double inferMs,
    double cpu,
    double mem,
    double reliableScore,
  ) {
    if (_logSink != null) {
      final time = DateTime.now().toIso8601String();
      _logSink?.writeln(
        '$time,${state.rawScore.toStringAsFixed(4)},${fft.toStringAsFixed(4)},'
        '${state.rawScore.toStringAsFixed(4)},${state.confidence.toStringAsFixed(4)},'
        '${state.status.name},$trigger,${detectMs.toStringAsFixed(2)},${cropMs.toStringAsFixed(2)},${inferMs.toStringAsFixed(2)},$_pipelineFpsCounter,$cpu,$mem,${reliableScore.toStringAsFixed(2)}',
      );
    }
  }

  Future<void> stop() async {
    await _frameSub?.cancel();
    _frameSub = null;

    await _nativeResultSub?.cancel();
    _nativeResultSub = null;
    _frameExtractor.stopExtraction();

    // Close log file safely
    if (_logSink != null) {
      try {
        await _logSink!.flush();
        await _logSink!.close();
      } catch (e) {
        // Ignore flush errors during shutdown
        debugPrint("[InferenceService] Log flush error (safe to ignore): $e");
      }
      _logSink = null;
    }

    debugPrint("[InferenceService] Pipeline Stopped.");
  }

  void dispose() {
    stop();
    _stateController.close();
  }
}
