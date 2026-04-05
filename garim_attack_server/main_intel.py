import base64
import os
import cv2
import time
import numpy as np
import onnxruntime
import socketio
import eventlet
import insightface
from insightface.app import FaceAnalysis

# --- Configuration ---
PORT = 3000
MODEL_PATH = os.path.join('model', 'inswapper_128_fp16.onnx')
SOURCE_IMAGE_PATH = 'source.jpg'

# --- Server Setup ---
sio = socketio.Server(
    cors_allowed_origins='*',
    max_http_content_length=25165824,  # 24MB
    ping_timeout=120,
    ping_interval=25,
    logger=True,
    engineio_logger=True
)
app = socketio.WSGIApp(sio)

# --- AI / Model Logic ---
class FaceSwapper:
    def __init__(self, model_path):
        self.model_path = model_path
        self.face_evaluator = None
        self.face_swapper = None
        self.source_face = None
        
        # Optimized OpenVINO Configuration for Intel CPU/iGPU
        self.providers = [
            'OpenVINOExecutionProvider',
            'CPUExecutionProvider'
        ]
        
        self.load_models()

    def load_models(self):
        try:
            print("[AI] Initializing FaceAnalysis (buffalo_l) for Intel OpenVINO...")
            self.face_evaluator = FaceAnalysis(name='buffalo_l', providers=self.providers)
            try:
                # Optimized for Cropped Faces: (640, 640) for high precision
                self.face_evaluator.prepare(ctx_id=0, det_size=(640, 640))
                print(f"[AI] FaceAnalysis prepared (640x640). Providers: {self.providers}")
            except Exception as e:
                print(f"[Warning] Failed to use GPU/OpenVINO for FaceAnalysis: {e}")
                self.face_evaluator.prepare(ctx_id=-1, det_size=(640, 640))
        except Exception as e:
             print(f"[Error] Critical failure initializing FaceAnalysis: {e}")
             return

        if not os.path.exists(self.model_path):
            print(f"[Error] Swap model not found at {self.model_path}")
            return
            
        try:
            print(f"[AI] Loading Swapper model from {self.model_path} with OpenVINO...")
            self.face_swapper = insightface.model_zoo.get_model(
                self.model_path, 
                download=False, 
                download_zip=False,
                providers=self.providers
            )
            
            if hasattr(self.face_swapper, 'session'):
                active = self.face_swapper.session.get_providers()
                print(f"[System] Swapper Active Providers: {active}")
            else:
                print(f"[System] Swapper loaded.")

        except Exception as e:
            print(f"[Error] Failed to load swapper model: {e}")

    def set_source_identity(self, img_bgr):
        if self.face_evaluator is None:
            return False

        faces = self.face_evaluator.get(img_bgr)
        if len(faces) == 0:
            print("[Warning] No face detected in source image.")
            return False
        
        faces = sorted(faces, key=lambda x: x.bbox[2]*x.bbox[3], reverse=True)
        self.source_face = faces[0]
        print("[AI] Source Updated.")
        return True

    def process_image(self, target_img):
        """
        Returns: (result_image, inference_time_ms, fps)
        """
        start_time = time.time()
        
        if self.face_swapper is None or self.source_face is None:
            return target_img, 0, 0

        target_faces = self.face_evaluator.get(target_img, max_num=1)
        if len(target_faces) == 0:
            end_time = time.time()
            print("[AI] No face found in target")
            return target_img, (end_time - start_time) * 1000, 0
        
        print(f"[AI] Face detected. Det-Box: {target_faces[0].bbox.astype(int)}")
        res_img = target_img.copy()
        for face in target_faces:
            res_img = self.face_swapper.get(res_img, face, self.source_face, paste_back=True)
        
        end_time = time.time()
        duration = end_time - start_time
        inference_time_ms = duration * 1000
        fps = 1.0 / duration if duration > 0 else 0
        
        return res_img, inference_time_ms, fps

swapper = FaceSwapper(MODEL_PATH)

if os.path.exists(SOURCE_IMAGE_PATH):
    print(f"[System] Found {SOURCE_IMAGE_PATH}. Loading identity...")
    src_img = cv2.imread(SOURCE_IMAGE_PATH)
    if src_img is not None:
        swapper.set_source_identity(src_img)

def decode_base64_image(base64_string):
    try:
        if ',' in base64_string:
            base64_string = base64_string.split(',')[1]
        img_bytes = base64.b64decode(base64_string)
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        return img
    except Exception as e:
        print(f"[Error] Image decoding failed: {e}")
        return None

def encode_base64_image(cv2_img):
    try:
        _, buffer = cv2.imencode('.jpg', cv2_img)
        b64_str = base64.b64encode(buffer).decode('utf-8')
        return f"data:image/jpeg;base64,{b64_str}"
    except Exception as e:
        print(f"[Error] Image encoding failed: {e}")
        return None

# --- Socket.IO Events ---

@sio.event
def connect(sid, environ):
    print(f'[Network] Client connected: {sid}')

@sio.event
def disconnect(sid):
    print(f'[Network] Client disconnected: {sid}')

@sio.event
def set_source(sid, data):
    image_data = data.get('image') if isinstance(data, dict) else data
    if not image_data: return
    img = decode_base64_image(image_data)
    if img is not None:
        if swapper.set_source_identity(img):
             sio.emit('source_updated', {'status': 'success'}, room=sid)

@sio.event
def attack_start(sid, data):
    if not isinstance(data, dict):
        return

    eventlet.sleep(0) # Yield

    # Source Face Check
    if swapper.source_face is None:
        if not data.get('source_image'):
             print("[AI] Error: Source face missing! Requesting source from client...")
             sio.emit('request_source', {}, room=sid)
             return

    # T1 Start
    t_start = time.time()
    
    if data.get('source_image'):
        src_img = decode_base64_image(data['source_image'])
        if src_img is not None:
            swapper.set_source_identity(src_img)
    
    target_b64 = data.get('target_frame') or data.get('image')
    if not target_b64:
        return

    raw_img = decode_base64_image(target_b64)
    if raw_img is None:
        return
        
    t1_end = time.time()
    t1_ms = (t1_end - t_start) * 1000

    # T2 (Inference)
    result_img, t2_ms, fps = swapper.process_image(raw_img)
    
    # T3 (Encode & Emit)
    t3_start = time.time()
    result_b64 = encode_base64_image(result_img)
    if result_b64:
        sio.emit('attack_complete', {
            'image': result_b64,
            'inference_time': round(t2_ms, 2),
            'fps': round(fps, 2)
        }, room=sid)
    
    t3_end = time.time()
    t3_ms = (t3_end - t3_start) * 1000

    total_ms = (t3_end - t_start) * 1000
    
    print(f"[Perf] Total: {total_ms:.1f}ms | T1(Rx/Dec): {t1_ms:.1f}ms | T2(Infer): {t2_ms:.1f}ms | T3(Tx/Enc): {t3_ms:.1f}ms")

if __name__ == '__main__':
    print(f"[System] Starting Socket.IO server (OpenVINO Optimized) on port {PORT}...")
    eventlet.wsgi.server(eventlet.listen(('', PORT)), app)
