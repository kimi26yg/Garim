# Garim — Real-time Deepfake Detection System

Deepfake technology can now swap a person's face onto a live video call in real time. A friend, a colleague, or an authority figure — anyone can be impersonated before you have any chance to notice. Existing security tools don't cover this vector. **Garim** was built to close that gap.

The system works end-to-end: one device runs the **attacker dashboard** (injecting a deepfake video stream via WebRTC), while the other device runs the **detector app** — analyzing every incoming frame on-device with a hybrid CNN + FFT inference engine and surfacing a real-time trust score to the user.

https://github.com/user-attachments/assets/placeholder-replace-with-uploaded-demo

> Upload `garim_landing/demo.mp4` via GitHub web editor to replace the link above.

---

## System Architecture

```
┌─────────────────────┐        WebRTC         ┌─────────────────────┐
│   garim_attack      │ ─────────────────────► │   garim_eye         │
│  (Attacker Dashboard│        via             │  (Detector App)     │
│   Flutter Web)      │  Signaling Server      │  Flutter iOS/Android│
└────────┬────────────┘                        └─────────────────────┘
         │ Socket.IO (Base64 frames)
         ▼
┌─────────────────────┐
│  garim_attack_server│
│  (Python / ONNX)    │
│  InsightFace swap   │
└─────────────────────┘
```

| Component | Stack | Role |
|---|---|---|
| [`garim_eye/`](./garim_eye/) | Flutter (iOS/Android) | Deepfake detector — on-device CNN + FFT inference on incoming WebRTC video |
| [`garim_attack/`](./garim_attack/) | Flutter Web | Attacker dashboard — injects deepfake stream via canvas pipeline + WebRTC |
| [`garim_attack_server/`](./garim_attack_server/) | Python, ONNX, InsightFace | AI inference server — real-time face-swap on received frames |
| [`garim_eye/signaling_server/`](./garim_eye/signaling_server/) | Node.js, Socket.IO | WebRTC signaling broker between attacker and detector |
| [`garim_landing/`](./garim_landing/) | HTML/CSS/JS | Project landing page |

---

## Quick Start

### 1. Signaling Server
```bash
cd garim_eye/signaling_server
npm install
npm start
```

### 2. Attack Inference Server
```bash
cd garim_attack_server
conda activate garim_env   # Python 3.10.19
pip install -r requirements.txt
# Place inswapper_128.onnx in model/
python main.py             # Runs on port 3000
```

### 3. Attacker Dashboard
```bash
cd garim_attack
flutter pub get
flutter run -d chrome
```

### 4. Detector App
```bash
cd garim_eye
flutter pub get
cd ios && pod install && cd ..
flutter run --release
```

---

## How It Works

**Attack side**: The `garim_attack` Flutter Web app captures a camera feed (or pre-recorded deepfake clip), passes it through a hidden canvas pipeline where face filters are applied pixel-by-pixel, then streams the processed output via WebRTC to the target device. The `garim_attack_server` performs AI-based face-swapping using InsightFace's `inswapper_128` ONNX model.

**Detection side**: `garim_eye` receives the WebRTC video stream and runs a hybrid inference engine on every frame:
- **CNN**: Detects spatial artifacts and facial inconsistencies
- **FFT**: Identifies frequency-domain anomalies common in GAN-generated images
- **ReliabilityManager**: Fuses both scores into a Trust Score (0–100%) using a weighted moving average

The Trust Score updates live during the call, giving the user a continuous signal without any server dependency.

---

## Model Files

The ONNX model files (`inswapper_128.onnx`, `inswapper_128_fp16.onnx`) are excluded from this repository due to size. Place them in `garim_attack_server/model/` before running the server.

---

---

# Garim — 실시간 딥페이크 탐지 시스템

딥페이크 기술은 이제 실시간 영상 통화에서 상대방의 얼굴을 즉시 합성할 수 있는 수준에 도달했습니다. 지인, 동료, 권위 있는 인물 — 눈치채기 전에 누구든 위장할 수 있습니다. 기존 보안 도구는 이 공격 벡터를 막지 못합니다. **Garim**은 이 공백을 메우기 위해 만들어졌습니다.

시스템은 엔드투엔드로 동작합니다. 한 쪽 기기는 **공격자 대시보드**를 실행해 WebRTC로 딥페이크 영상 스트림을 주입하고, 반대쪽 기기는 **탐지 앱**을 실행해 수신된 모든 프레임을 온디바이스 CNN + FFT 추론 엔진으로 분석하고 실시간 신뢰 점수를 사용자에게 표시합니다.

## 시스템 구성

| 컴포넌트 | 스택 | 역할 |
|---|---|---|
| [`garim_eye/`](./garim_eye/) | Flutter (iOS/Android) | 딥페이크 탐지기 — WebRTC 수신 영상에 온디바이스 CNN + FFT 추론 |
| [`garim_attack/`](./garim_attack/) | Flutter Web | 공격자 대시보드 — 캔버스 파이프라인 + WebRTC로 딥페이크 스트림 주입 |
| [`garim_attack_server/`](./garim_attack_server/) | Python, ONNX, InsightFace | AI 추론 서버 — 수신 프레임에 실시간 얼굴 교체 |
| [`garim_eye/signaling_server/`](./garim_eye/signaling_server/) | Node.js, Socket.IO | 공격자-탐지기 간 WebRTC 시그널링 브로커 |
| [`garim_landing/`](./garim_landing/) | HTML/CSS/JS | 프로젝트 랜딩 페이지 |

## 동작 원리

**공격 측**: `garim_attack` Flutter Web 앱이 카메라 피드(또는 사전 녹화된 딥페이크 클립)를 캡처해 히든 캔버스 파이프라인에서 픽셀 단위 필터를 적용한 뒤, 가공된 출력을 WebRTC로 대상 기기에 스트리밍합니다. `garim_attack_server`는 InsightFace의 `inswapper_128` ONNX 모델로 AI 기반 얼굴 교체를 수행합니다.

**탐지 측**: `garim_eye`는 WebRTC 영상 스트림을 수신해 매 프레임마다 하이브리드 추론 엔진을 실행합니다.
- **CNN**: 공간적 아티팩트 및 안면 불일치 탐지
- **FFT**: GAN 생성 이미지에서 흔히 나타나는 주파수 도메인 이상 징후 탐지
- **ReliabilityManager**: 두 점수를 가중 이동 평균으로 합산해 신뢰 점수(0–100%) 산출

신뢰 점수는 통화 중 실시간 갱신되며, 외부 서버 의존 없이 사용자에게 지속적인 신호를 제공합니다.
