import 'dart:async';
import 'dart:html' as html;
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum VideoSourceType {
  camera,
  deepfake,
}

class VideoProcessor {
  // Config
  static const int _width = 720;
  static const int _height = 1280;
  static const int _fps = 30;

  // Elements
  late html.VideoElement _cameraVideo;
  late html.VideoElement _deepfakeVideo;
  late html.CanvasElement _canvas;
  late html.CanvasRenderingContext2D _ctx;

  // State
  MediaStream? _outputStream; // This is flutter_webrtc.MediaStream
  MediaStreamTrack? _currentAudioTrack;
  MediaStreamTrack? _cameraAudioTrack;

  // Internal (Native)
  html.MediaStream? _nativeCanvasStream;
  html.MediaStream? _nativeDeepfakeStream;

  VideoSourceType _currentSource = VideoSourceType.camera;
  bool _isMosaicActive = false;
  bool _isBeautyActive = false;
  bool _isRunning = false;
  int? _animationFrameId;
  DateTime? _lastLogTime;

  // Getters
  MediaStream? get outputStream => _outputStream;
  MediaStreamTrack? get currentAudioTrack => _currentAudioTrack;

  // Callbacks
  void Function()? onVideoEnded;
  void Function(String error)? onPlayError;

  VideoProcessor() {
    _initElements();
  }

  void _initElements() {
    // Hidden Camera Video Element
    _cameraVideo = html.VideoElement()
      ..width = _width
      ..height = _height
      ..autoplay = true
      ..muted = true; // Local playback muted
    _cameraVideo.setAttribute('playsinline', 'true');

    // Hidden Deepfake Video Element
    _deepfakeVideo = html.VideoElement()
      ..width = _width
      ..height = _height
      // Autoplay removed here to rely on manual trigger
      ..loop = false // DISABLE LOOP for Auto-Revert
      ..muted = false // Capture stream needs audio
      ..crossOrigin = 'anonymous';
    _deepfakeVideo.setAttribute('playsinline', 'true');

    // Listen for end of playback
    _deepfakeVideo.onEnded.listen((_) {
      if (onVideoEnded != null) onVideoEnded!();
    });

    // LAZY CAPTURE: Listen for playing event
    _deepfakeVideo.onPlaying.listen((_) {
      print("[VideoProcessor] Deepfake started playing. Capturing stream...");
      _captureDeepfakeStream();
      // If this was a source switch, we might need to update audio now
      if (_currentSource == VideoSourceType.deepfake) {
        _switchAudioToDeepfake();
      }
    });

    // Processing Canvas
    _canvas = html.CanvasElement(width: _width, height: _height);
    _ctx = _canvas.context2D;

    // Create native output stream from canvas
    _nativeCanvasStream = _canvas.captureStream(_fps);

    // We defer _outputStream creation to initialize()
  }

  /// Initialize with camera stream and deepfake video URL
  Future<void> initialize(MediaStream cameraStream,
      [String? deepfakeUrl]) async {
    try {
      // 1. Create WebRTC Output Stream
      _outputStream = await createLocalMediaStream('garim_output');

      // 2. Add Canvas Video Track via JS Interop
      // We assume running on Web where jsStream is available
      final nativeVideoTrack = _nativeCanvasStream!.getVideoTracks().first;
      (_outputStream as dynamic).jsStream.addTrack(nativeVideoTrack);

      // 3. Handle Camera Video Input
      final nativeCameraStream =
          (cameraStream as dynamic).jsStream as html.MediaStream;
      _cameraVideo.srcObject = nativeCameraStream;
      _safePlay(_cameraVideo); // Fire and forget

      // 4. Handle Camera Audio Track (Initial)
      if (cameraStream.getAudioTracks().isNotEmpty) {
        _cameraAudioTrack = cameraStream.getAudioTracks().first;
        // Store native track for switching
        _currentAudioTrack = _cameraAudioTrack;
        _outputStream!.addTrack(_cameraAudioTrack!);
      }

      // 5. Setup Deepfake URL (Do NOT capture yet)
      if (deepfakeUrl != null) {
        _deepfakeVideo.src = deepfakeUrl;
      }
    } catch (e) {
      print("[VideoProcessor] initialize error: $e");
    }

    _startProcessing();
  }

  void _captureDeepfakeStream() {
    if (_nativeDeepfakeStream != null) return; // Already captured
    try {
      // Capture stream only when playing
      _nativeDeepfakeStream = _deepfakeVideo.captureStream();
      print("[VideoProcessor] Deepfake stream captured successfully.");
    } catch (e) {
      print("[VideoProcessor] Deepfake capture error: $e");
    }
  }

  /// Call this synchronously on user interaction (button click)
  /// to unlock audio/video playback restrictions.
  void warmUp() {
    print("[VideoProcessor] Warming up video elements...");
    _safePlay(_cameraVideo, warmUp: true);
    _safePlay(_deepfakeVideo, warmUp: true);
  }

  // FIRE-AND-FORGET PLAY (No await)
  void _safePlay(html.VideoElement video, {bool warmUp = false}) {
    // Validation
    bool hasSrc = video.src.isNotEmpty;
    bool hasSrcObject = video.srcObject != null;

    if (!hasSrc && !hasSrcObject) {
      if (!warmUp)
        print("[VideoProcessor] Warn: Attempted to play video with no source.");
      return;
    }

    // We do NOT await this. It returns a Promise (Future).
    // We attach handlers to it.
    video.play().then((_) {
      // Success
      if (warmUp) {
        video.pause();
      }
    }).catchError((e) {
      print("[VideoProcessor] Play Error: $e");
      String errorMsg = e.toString();
      if (errorMsg.contains("NotAllowedError")) {
        onPlayError?.call("Autoplay blocked. Tap to play.");
      } else if (errorMsg.contains("NotSupportedError")) {
        onPlayError?.call("Video format not supported.");
      }
    });
  }

  void updateDeepfakeUrl(String url) {
    _deepfakeVideo.src = url;
  }

  void setSource(VideoSourceType source) {
    if (_currentSource == source) return;
    _currentSource = source;

    if (source == VideoSourceType.deepfake) {
      _safePlay(_deepfakeVideo);
      // Audio switch happens in onPlaying or immediate if stream exists
      if (_nativeDeepfakeStream != null) {
        _switchAudioToDeepfake();
      }
    } else {
      _deepfakeVideo.pause();
      _safePlay(
          _cameraVideo); // Resume camera if it was paused (e.g. by warmUp)
      _switchAudioToCamera();
    }
  }

  void setMosaic(bool active) {
    _isMosaicActive = active;
  }

  void setBeauty(bool active) {
    _isBeautyActive = active;
  }

  void _switchAudioToCamera() {
    if (_outputStream == null) return;
    try {
      // Remove all audio tracks
      for (var track in _outputStream!.getAudioTracks()) {
        _outputStream!.removeTrack(track);
      }

      // Add camera audio
      if (_cameraAudioTrack != null) {
        _outputStream!.addTrack(_cameraAudioTrack!);
        _currentAudioTrack = _cameraAudioTrack;
      }
    } catch (e) {
      print("Error switching audio to camera: $e");
    }
  }

  void _switchAudioToDeepfake() {
    if (_outputStream == null || _nativeDeepfakeStream == null) return;
    try {
      // Remove all audio tracks
      for (var track in _outputStream!.getAudioTracks()) {
        _outputStream!.removeTrack(track);
      }

      // Add deepfake audio
      // Need to wrap native track into WebRTC track or add via JS
      if (_nativeDeepfakeStream!.getAudioTracks().isNotEmpty) {
        final nativeAudioTrack = _nativeDeepfakeStream!.getAudioTracks().first;
        (_outputStream as dynamic).jsStream.addTrack(nativeAudioTrack);

        // Update current track reference by fetching it back from the wrapper
        if (_outputStream!.getAudioTracks().isNotEmpty) {
          _currentAudioTrack = _outputStream!.getAudioTracks().last;
        }
      }
    } catch (e) {
      print("Error switching audio to deepfake: $e");
    }
  }

  void _startProcessing() {
    if (_isRunning) return;
    _isRunning = true;
    _processFrame();
  }

  void stop() {
    _isRunning = false;
    if (_animationFrameId != null) {
      html.window.cancelAnimationFrame(_animationFrameId!);
    }
  }

  void _processFrame() {
    if (!_isRunning) return;

    // 1. Select Source
    html.CanvasImageSource sourceElement =
        _currentSource == VideoSourceType.camera
            ? _cameraVideo
            : _deepfakeVideo;

    // Get source dimensions
    int sourceWidth = 0;
    int sourceHeight = 0;

    if (sourceElement is html.VideoElement) {
      sourceWidth = sourceElement.videoWidth;
      sourceHeight = sourceElement.videoHeight;
    }

    if (sourceWidth == 0 || sourceHeight == 0) {
      // Not ready yet, retry next frame
      _animationFrameId =
          html.window.requestAnimationFrame((_) => _processFrame());
      return;
    }

    // Debug Log (Throttled)
    final now = DateTime.now();
    if (_lastLogTime == null ||
        now.difference(_lastLogTime!) > Duration(seconds: 2)) {
      _lastLogTime = now;
      print(
          "[VideoProcessor] Input: ${sourceWidth}x$sourceHeight | Canvas: ${_width}x$_height");
    }

    // 3. Apply Beauty Filter (Optimized Soft-Skin Vignette)
    if (_isBeautyActive) {
      // Pass 1: Draw Sharp Base
      _drawAspectFill(sourceElement, sourceWidth, sourceHeight);

      _ctx.save();

      // Pass 2: Define Mask (Center Oval - assuming face is centered)
      // Adjust oval size as needed (e.g., 50% of width, 40% of height)
      _ctx.beginPath();
      _ctx.ellipse(
          _width / 2, // Center X
          _height / 2, // Center Y
          _width * 0.35, // Radius X (Face width)
          _height * 0.25, // Radius Y (Face height)
          0, // Rotation
          0,
          6.28, // 2*PI
          false // anticlockwise
          );
      _ctx.clip(); // Restrict following drawing to inside the oval

      // Pass 3: Draw Soft/Glow Overly
      _ctx.globalAlpha = 0.5; // Blending strength (0.0 - 1.0)
      _ctx.filter = 'blur(8px) brightness(115%) saturate(110%)';

      _drawAspectFill(sourceElement, sourceWidth, sourceHeight);

      _ctx.restore(); // Remove clip, filter, and alpha
    } else {
      _ctx.filter = 'none';
      if (!_isMosaicActive) {
        // If Mosaic is executing, it handles its own drawing.
        // If neither, we draw normal here.
        // Wait, the Mosaic block below handles drawing.
        // If Beauty is OFF and Mosaic is OFF, we need to draw.
        // If Beauty is ON, we ALREADY drew it above.
        // We need to restructure slightly to handle Mosaic + Beauty combo if needed,
        // but usually they are exclusive or stacked.
        // Current structure: Beauty sets filter -> Mosaic draws OR Normal draws.
        // My new Beauty logic does drawing itself.

        // Let's defer "Normal Draw" to step 4 if Beauty didn't happen.
      }
    }

    // 4. Mosaic Logic (runs after or instead of Beauty?)
    // If Mosaic is active, it invalidates the Beauty draw unless we compose them.
    // For simplicity/performance: If Mosaic is ON, we skip Beauty or apply it differently.
    // Given the request, let's treat them as separate modes or allow stack?
    // User probably switches between them.

    if (_isMosaicActive) {
      // ... existing mosaic logic ...
      // This will overwrite the Beauty draw if it runs.
      // We should apply Mosaic *on top* or instead.
      _ctx.filter = 'none';
      _ctx.imageSmoothingEnabled = false;
      _drawAspectFill(sourceElement, sourceWidth, sourceHeight);

      double scale = 0.25;
      double w = _width * scale;
      double h = _height * scale;
      _ctx.drawImageScaledFromSource(
          _canvas, 0, 0, _width, _height, 0, 0, w, h);
      _ctx.drawImageScaledFromSource(
          _canvas, 0, 0, w, h, 0, 0, _width, _height);
      _ctx.imageSmoothingEnabled = true;
    } else if (!_isBeautyActive) {
      // Only draw normal if Beauty didn't already draw
      _drawAspectFill(sourceElement, sourceWidth, sourceHeight);
    }

    _ctx.filter = 'none';

    _animationFrameId =
        html.window.requestAnimationFrame((_) => _processFrame());
  }

  void _drawAspectFill(html.CanvasImageSource source, int srcW, int srcH) {
    // Destination dimensions
    const destW = _width;
    const destH = _height;

    // Calculate Aspect Ratios
    final double srcAspect = srcW / srcH;
    final double destAspect = destW / destH;

    double sx, sy, sw, sh;

    if (srcAspect > destAspect) {
      // Source is wider than destination (e.g. 16:9 src on 4:3 dest)
      // Crop sides. Match Height.
      sh = srcH.toDouble();
      sw = sh * destAspect;
      sx = (srcW - sw) / 2;
      sy = 0;
    } else {
      // Source is taller than destination (e.g. 9:16 src on 16:9 dest)
      // Crop top/bottom. Match Width.
      sw = srcW.toDouble();
      sh = sw / destAspect;
      sx = 0;
      sy = (srcH - sh) / 2;
    }

    // Debug Crop Rect
    // print("Crop: $sx,$sy ${sw}x$sh -> $destW x $destH");

    _ctx.drawImageScaledFromSource(source, sx, sy, sw, sh, 0, 0, destW, destH);
  }

  void dispose() {
    stop();
    _cameraVideo.pause();
    _cameraVideo.removeAttribute('src');
    _cameraVideo.removeAttribute('srcObject');
    _deepfakeVideo.pause();
    _deepfakeVideo.removeAttribute('src');
  }
}
