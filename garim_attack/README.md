# Garim Attack — Deepfake Attack Dashboard

The attacker-side component of the Garim system. A Flutter Web app that simulates a real-time deepfake attack on a video call — injecting a manipulated video stream to the target device via WebRTC.

## Why This Exists

To build a reliable deepfake detector, you need a realistic attacker. Garim Attack replicates how a real deepfake attack would work over a video call: the camera feed is intercepted, processed through an AI face-swap pipeline, and the result is streamed out as if it were the original camera — all in real time.

## How It Works: Canvas Pipeline

The camera feed is **never** sent directly. Instead:

1. Raw frames are drawn onto a **hidden canvas**
2. Pixel-level filters (Mosaic, Beauty, AI face-swap) are applied
3. `canvas.captureStream()` produces a fake `MediaStream`
4. That stream is sent via WebRTC to the `garim_eye` detector

For AI face-swap, frames are forwarded to `garim_attack_server` (Python/ONNX) via Socket.IO, and the swapped result is drawn back onto the canvas.

Switching to **Deepfake mode** uses `replaceTrack()` to instantly swap to a pre-recorded deepfake clip — no pipeline rebuild needed.

## Stack

- **Framework**: Flutter Web
- **State Management**: Riverpod
- **Routing**: GoRouter
- **Video Processing**: Canvas API via `dart:js`
- **Face Mesh**: MediaPipe (face landmark overlay)
- **Transport**: WebRTC (`flutter_webrtc`) + Socket.IO

## Getting Started

```bash
cd garim_attack
flutter pub get
flutter run -d chrome
```

Requires the signaling server (`garim_eye/signaling_server`) and optionally `garim_attack_server` for AI face-swap.

## Key Files

| File | Role |
|---|---|
| `lib/dashboard_screen.dart` | Main attacker control panel |
| `lib/video_feed_section.dart` | Canvas rendering + stream capture |
| `lib/video_processor.dart` | Pixel-level filter application |
| `lib/mediapipe_web.dart` | MediaPipe face mesh integration |
| `lib/providers/webrtc_provider.dart` | WebRTC peer connection + `replaceTrack()` logic |
| `lib/providers/attack_asset_provider.dart` | Deepfake video asset selection |
| `lib/control_sidebar.dart` | Filter toggles (Mosaic, Beauty, Deepfake) |

---

# Garim Attack — 딥페이크 공격 대시보드

Garim 시스템의 공격자 측 컴포넌트. 실시간 딥페이크 공격을 시뮬레이션하는 Flutter Web 앱으로, WebRTC를 통해 조작된 영상 스트림을 대상 기기에 주입합니다.

## 왜 만들었나

신뢰할 수 있는 딥페이크 탐지기를 만들려면 현실적인 공격자가 필요합니다. Garim Attack은 실제 딥페이크 공격이 영상 통화에서 어떻게 동작하는지를 재현합니다. 카메라 피드를 가로채 AI 얼굴 교체 파이프라인으로 처리한 뒤, 원본 카메라인 것처럼 스트리밍합니다 — 모두 실시간으로.

## 동작 원리: 캔버스 파이프라인

카메라 피드는 **절대 직접 전송되지 않습니다.** 대신:

1. 원본 프레임을 **히든 캔버스**에 그림
2. 픽셀 단위 필터 적용 (모자이크, 뷰티, AI 얼굴 교체)
3. `canvas.captureStream()`으로 가짜 `MediaStream` 생성
4. 해당 스트림을 WebRTC로 `garim_eye` 탐지기에 전송

AI 얼굴 교체 시, 프레임은 Socket.IO를 통해 `garim_attack_server`(Python/ONNX)로 전달되고 교체된 결과가 캔버스에 다시 그려집니다.

**딥페이크 모드** 전환 시 `replaceTrack()`을 사용해 사전 녹화된 딥페이크 클립으로 즉시 교체합니다 — 파이프라인 재구성 없이.

## 시작하기

```bash
cd garim_attack
flutter pub get
flutter run -d chrome
```

시그널링 서버(`garim_eye/signaling_server`) 실행이 필요하며, AI 얼굴 교체를 사용하려면 `garim_attack_server`도 실행해야 합니다.
