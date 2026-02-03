@JS()
library mediapipe_web;

import 'dart:js_interop';

@JS('FaceLandmarker')
extension type FaceLandmarker._(JSObject _) implements JSObject {
  external static JSPromise<FaceLandmarker> createFromOptions(
      JSAny filesetResolver, JSAny options);
  external FaceLandmarkerResult detectForVideo(JSAny video, int timestampMs);
  external void close();
}

@JS('FilesetResolver')
extension type FilesetResolver._(JSObject _) implements JSObject {
  external static JSPromise<JSAny> forVisionTasks(String wasmUrl);
}

@JS()
@anonymous
extension type FaceLandmarkerOptions._(JSObject _) implements JSObject {
  external factory FaceLandmarkerOptions({
    JSAny baseOptions,
    String runningMode,
    int numFaces,
    double minFaceDetectionConfidence,
    double minFacePresenceConfidence,
    double minTrackingConfidence,
  });
}

@JS()
@anonymous
extension type BaseOptions._(JSObject _) implements JSObject {
  external factory BaseOptions({
    String modelAssetPath,
  });
}

@JS()
extension type FaceLandmarkerResult._(JSObject _) implements JSObject {
  external JSArray<JSArray<NormalizedLandmark>> get faceLandmarks;
}

@JS()
extension type NormalizedLandmark._(JSObject _) implements JSObject {
  external double get x;
  external double get y;
  external double get z;
}

Future<FaceLandmarker> loadFaceLandmarker() async {
  final resolverPromise = FilesetResolver.forVisionTasks(
    'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.0/wasm',
  );

  final resolver = await resolverPromise.toDart;

  final options = FaceLandmarkerOptions(
    baseOptions: BaseOptions(
      modelAssetPath:
          'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task',
    ),
    runningMode: 'VIDEO',
    numFaces: 1,
  );

  final landmarkerPromise = FaceLandmarker.createFromOptions(resolver, options);

  return landmarkerPromise.toDart;
}
