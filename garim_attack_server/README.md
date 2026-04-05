# Garim Attack Server — AI Face-Swap Inference Server

Python-based inference server for the Garim system. Receives video frames from `garim_attack` via Socket.IO and performs real-time face-swapping using InsightFace's ONNX model.

## Stack

- **Runtime**: Python 3.10.19
- **Server**: `python-socketio` + `eventlet` (port 3000)
- **Inference**: `onnxruntime`, InsightFace (`inswapper_128.onnx`)
- **Image Processing**: OpenCV, NumPy

## Setup

```bash
conda activate garim_env
pip install -r requirements.txt

# Place model files in model/
# - model/inswapper_128.onnx       (main model, ~530MB)
# - model/inswapper_128_fp16.onnx  (half-precision, ~265MB)

python main.py
```

Model files are not included in this repository due to size. Download `inswapper_128.onnx` from the InsightFace model zoo.

## How It Works

1. `garim_attack` sends Base64-encoded frames via the `frame` Socket.IO event
2. Server decodes the frame into a NumPy array (OpenCV format)
3. On `attack_start` event, face-swap inference runs via `inswapper_128.onnx`
4. Swapped frame is Base64-encoded and emitted back to `garim_attack`
5. `garim_attack` draws the result onto the canvas pipeline

## Socket.IO Events

| Event | Direction | Description |
|---|---|---|
| `frame` | client → server | Raw Base64 frame for processing |
| `attack_start` | client → server | Trigger face-swap inference |
| `attack_stop` | client → server | Stop inference |
| `processed_frame` | server → client | Swapped Base64 frame result |

---

# Garim Attack Server — AI 얼굴 교체 추론 서버

Garim 시스템의 Python 기반 추론 서버. `garim_attack`으로부터 Socket.IO를 통해 영상 프레임을 수신하고 InsightFace ONNX 모델로 실시간 얼굴 교체를 수행합니다.

## 설정

```bash
conda activate garim_env
pip install -r requirements.txt

# model/ 폴더에 모델 파일 배치
# - model/inswapper_128.onnx       (메인 모델, ~530MB)
# - model/inswapper_128_fp16.onnx  (반정밀도, ~265MB)

python main.py
```

모델 파일은 용량 문제로 이 레포지토리에 포함되지 않습니다. InsightFace model zoo에서 `inswapper_128.onnx`를 다운로드해 주세요.

## 동작 원리

1. `garim_attack`이 `frame` Socket.IO 이벤트로 Base64 인코딩된 프레임 전송
2. 서버가 프레임을 NumPy 배열(OpenCV 포맷)로 디코딩
3. `attack_start` 이벤트 수신 시 `inswapper_128.onnx`로 얼굴 교체 추론 실행
4. 교체된 프레임을 Base64로 인코딩해 `garim_attack`으로 다시 전송
5. `garim_attack`이 결과를 캔버스 파이프라인에 그림
