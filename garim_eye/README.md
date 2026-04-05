# Garim Eye v2

**Real-time Deepfake Detection & Protection System**

Garim Eye v2 is a cutting-edge mobile application designed to detect deepfake threats in real-time video calls. Powered by a **Hybrid Inference Engine** (CNN + FFT Analysis), it provides users with immediate visual feedback on the authenticity of the video feed, ensuring secure and trustworthy communications.

## Key Features

### 🛡️ Hybrid Inference Engine (v4.5)

Combines multiple detection methodologies for maximum accuracy:

- **CNN (Convolutional Neural Network)**: Analyzes spatial artifacts and facial inconsistencies.
- **FFT (Fast Fourier Transform)**: Detects frequency domain anomalies common in GAN-generated images.
- **Reliability Fusion**: Intelligently weighs scores from different models based on scene conditions.

### 📊 Deepfake Insight Panel

A real-time dashboard providing users with actionable intelligence:

- **Trust Score**: A dynamic reliability metric (0-100%) indicating confidence in the video's authenticity.
- **Real/Fake Probability**: Live probability bars showing the model's instantaneous output.
- **System Stats**: Monitors inference latitude, FPS, and resource usage.

### 🌡️ Dynamic Thermal Management

Optimizes performance and battery life based on device state:

- **Standard Mode**: Balanced performance for normal operation.
- **Stable Mode**: Prioritizes consistency during extended calls.
- **Deep Sleep**: Minimizes resource usage when confidence is high or activity is low.

### 🧪 Deepfake Simulation

Built-in tools for testing and demonstration:

- **Virtual Camera**: Injests test footage into the detection pipeline.
- **Asset Mapping**: Select specific deepfake examples to verify system response.

## Technical Architecture

### Frontend

- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **State Management**: Riverpod
- **Routing**: GoRouter
- **UI Components**: Custom "Glassmorphism" design system

### Native Modules

- **iOS**: Swift, `AVFoundation` for camera access, `Vision` framework for face tracking, `CoreML` for on-device inference (`DeepfakeDetector_Int8.mlpackage`).
- **Android**: Kotlin, CameraX, TensorFlow Lite (In progres).

### Core Services

- **`FrameExtractor`**: High-performance image buffer management for efficient model input.
- **`ReliabilityManager`**: Central brain for scoring logic, implementing inverted scales and hysteresis to prevent false alarms.
- **`SocketService`**: WebRTC signaling and connection management using Socket.IO.

## Getting Started

1. **Prerequisites**
   - Flutter SDK (>=3.10.4)
   - Xcode (for iOS) / Android Studio (for Android)
   - CocoaPods (for iOS dependencies)

2. **Installation**

   ```bash
   # Clone the repository
   git clone https://github.com/yourusername/garim_eye_v2.git

   # Install dependencies
   flutter pub get

   # Install iOS pods
   cd ios && pod install && cd ..
   ```

3. **Running the App**
   ```bash
   flutter run --release
   ```
   _Note: Release mode is recommended for accurate performance testing of the inference engine._

## Recent Updates

- **Icon Update**: Refreshed app iconography.
- **Scoring Logic**: Recalibrated reliability scores to correctly interpret inverted model outputs (0 = Real, 1 = Fake).
- **Video Playback**: Fixed issues with local asset playback for deepfake simulation.

---

# Garim Eye v2 (한국어)

**실시간 딥페이크 탐지 및 보호 시스템**

Garim Eye v2는 실시간 영상 통화에서 딥페이크 위협을 탐지하도록 설계된 최첨단 모바일 애플리케이션입니다. **하이브리드 추론 엔진** (CNN + FFT 분석)을 기반으로 구동되며, 영상의 진위 여부에 대한 즉각적인 시각적 피드백을 제공하여 안전하고 신뢰할 수 있는 커뮤니케이션을 보장합니다.

## 주요 기능

### 🛡️ 하이브리드 추론 엔진 (v4.5)

최대 정확도를 위해 여러 탐지 방법론을 결합합니다:

- **CNN (합성곱 신경망)**: 공간적 아티팩트와 안면 불일치를 분석합니다.
- **FFT (고속 푸리에 변환)**: GAN 생성 이미지에서 흔히 발생하는 주파수 영역의 이상 징후를 탐지합니다.
- **신뢰도 융합 (Reliability Fusion)**: 장면 조건에 따라 여러 모델의 점수를 지능적으로 가중치화합니다.

### 📊 딥페이크 인사이트 패널

사용자에게 실행 가능한 정보를 제공하는 실시간 대시보드입니다:

- **신뢰 점수 (Trust Score)**: 영상의 진위에 대한 확신을 나타내는 동적 신뢰도 지표(0-100%)입니다.
- **진짜/가짜 확률**: 모델의 즉각적인 출력을 보여주는 실시간 확률 바입니다.
- **시스템 통계**: 추론 지연 시간, FPS 및 리소스 사용량을 모니터링합니다.

### 🌡️ 동적 발열 관리

장치 상태에 따라 성능과 배터리 수명을 최적화합니다:

- **표준 모드**: 일반적인 작동을 위한 균형 잡힌 성능.
- **안정 모드**: 장시간 통화 중 일관성을 우선시합니다.
- **딥 슬립 (Deep Sleep)**: 신뢰도가 높거나 활동이 적을 때 리소스 사용을 최소화합니다.

### 🧪 딥페이크 시뮬레이션

테스트 및 시연을 위한 내장 도구입니다:

- **가상 카메라**: 테스트 영상을 탐지 파이프라인으로 주입합니다.
- **에셋 매핑**: 시스템 반응을 확인하기 위해 특정 딥페이크 예시를 선택합니다.

## 기술 아키텍처

### 프론트엔드

- **프레임워크**: [Flutter](https://flutter.dev) (Dart)
- **상태 관리**: Riverpod
- **라우팅**: GoRouter
- **UI 컴포넌트**: 커스텀 "글래스모피즘(Glassmorphism)" 디자인 시스템

### 네이티브 모듈

- **iOS**: Swift, 카메라 액세스를 위한 `AVFoundation`, 얼굴 추적을 위한 `Vision` 프레임워크, 온디바이스 추론을 위한 `CoreML` (`DeepfakeDetector_Int8.mlpackage`).
- **Android**: Kotlin, CameraX, TensorFlow Lite (진행 중).

### 핵심 서비스

- **`FrameExtractor`**: 효율적인 모델 입력을 위한 고성능 이미지 버퍼 관리.
- **`ReliabilityManager`**: 점수 로직을 위한 중앙 두뇌로, 오경보를 방지하기 위해 반전된 스케일과 히스테리시스를 구현합니다.
- **`SocketService`**: Socket.IO를 사용한 WebRTC 시그널링 및 연결 관리.

## 시작하기

1. **사전 요구 사항**
   - Flutter SDK (>=3.10.4)
   - Xcode (iOS용) / Android Studio (Android용)
   - CocoaPods (iOS 종속성용)

2. **설치**

   ```bash
   # 저장소 복제
   git clone https://github.com/yourusername/garim_eye_v2.git

   # 종속성 설치
   flutter pub get

   # iOS 팟 설치
   cd ios && pod install && cd ..
   ```

3. **앱 실행**
   ```bash
   flutter run --release
   ```
   _참고: 추론 엔진의 정확한 성능 테스트를 위해서는 릴리스 모드를 권장합니다._

## 최근 업데이트

- **아이콘 업데이트**: 앱 아이콘을 새롭게 단장했습니다.
- **점수 로직**: 반전된 모델 출력(0 = 진짜, 1 = 가짜)을 올바르게 해석하도록 신뢰도 점수를 재조정했습니다.
- **비디오 재생**: 딥페이크 시뮬레이션을 위한 로컬 에셋 재생 문제를 수정했습니다.

---

_Garim Eye Project - Protecting Digital Authenticity_
