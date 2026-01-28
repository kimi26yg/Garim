import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FaceDetectionState {
  final Rect? faceRect;
  final Size? imageSize;

  FaceDetectionState({
    this.faceRect,
    this.imageSize,
  });

  FaceDetectionState copyWith({
    Rect? faceRect,
    Size? imageSize,
  }) {
    return FaceDetectionState(
      faceRect: faceRect ?? this.faceRect,
      imageSize: imageSize ?? this.imageSize,
    );
  }
}

class FaceDetectionNotifier extends Notifier<FaceDetectionState> {
  @override
  FaceDetectionState build() {
    return FaceDetectionState();
  }

  /// Update face rect from server response
  void updateFaceRect(Rect? rect, Size? imageSize) {
    if (rect != null && imageSize != null) {
      print("Server Face Rect: $rect, Image Size: $imageSize");
      state = FaceDetectionState(
        faceRect: rect,
        imageSize: imageSize,
      );
    } else {
      print("Clearing face rect");
      state = FaceDetectionState();
    }
  }

  /// Clear face detection state
  void clear() {
    state = FaceDetectionState();
  }
}

final faceDetectionProvider =
    NotifierProvider<FaceDetectionNotifier, FaceDetectionState>(() {
  return FaceDetectionNotifier();
});
