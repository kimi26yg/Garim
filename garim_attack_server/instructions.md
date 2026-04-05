# Instructions: Garim Eye V2 - Attack Inference Server (garim_attack_server)

## 1. [CRITICAL] Fixed Instruction: Server Role & Connectivity
- **Role**: This is a Python-based signaling and AI inference server for the 'Garim Eye V2' project.
- **Port**: ALWAYS use port **3000**.
- **Communication**: Use `python-socketio` with `eventlet` for real-time bidirectional communication.
- **CORS**: Strictly allow requests from the Flutter Web dashboard (`garim_attack`) running on `http://localhost:53363` (or all origins `*` for development).

## 2. Environment & Dependencies
- **Runtime**: Python 3.10.19 (Environment: `garim_env`).
- **Key Libraries**: `python-socketio`, `eventlet`, `onnxruntime`, `opencv-python`, `numpy`, `insightface`.
- **Latest Standards**: Use the most recent stable syntax for Python and its libraries. Avoid deprecated functions.

## 3. AI Model & Inference Context
- **Model Path**: Models are located in `model/`.
    - `model/inswapper_128.onnx`: Main deepfake inference model.
    - `model/inswapper_128_fp16.onnx`: Half-precision optimized model.
- **Task**: 
    - Receive Base64 encoded images from `garim_attack`.
    - Decode images into NumPy arrays (OpenCV format).
    - Perform face-swapping using the Inswapper model when the `attack_start` event is triggered.

## 4. Operational Requirements
- **Logging**: Every event (connection, disconnection, attack signal, inference start/end) must be logged to the terminal with a timestamp.
- **Error Handling**: Gracefully handle invalid Base64 strings or missing model files without crashing the server.