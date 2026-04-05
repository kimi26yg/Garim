import Foundation
import WebRTC
import Flutter
// Note: libyuv functions are available through WebRTC framework

// MARK: - Custom Video Sink for Deepfake Detection
class CustomVideoSink: NSObject {
    // Reference to predictor
    // private var predictor: DeepfakePredictor?
    
    // EventSink for sending results to Dart
    private var eventSink: FlutterEventSink?
    
    // Thread-safe processing flag
    private var isProcessing = false
    private let processingQueue = DispatchQueue(label: "com.garim.eye.video.processing")
    
    // Statistics
    private var frameCount: Int = 0
    private var lastLogTime: CFAbsoluteTime = 0
    
    // override init() {
    //     super.init()
    //     if #available(iOS 14.0, *) {
    //         // self.predictor = DeepfakePredictor()
    //         // print("✅ [CustomVideoSink] Initialized with predictor")
    //     } else {
    //         print("⚠️ [CustomVideoSink] iOS 14.0+ required for predictor")
    //     }
    // }
}

// MARK: - RTCVideoRenderer Protocol
extension CustomVideoSink: RTCVideoRenderer {
    func setSize(_ size: CGSize) {
        // Required by protocol, but we don't need to do anything
        // Frame size is handled per-frame
    }
    
    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame = frame else {
            return
        }
        
        // Frame statistics
        frameCount += 1
        let currentTime = CFAbsoluteTimeGetCurrent()
        if currentTime - lastLogTime >= 1.0 {
            print("📊 [CustomVideoSink] Received \(frameCount) frames in last second")
            frameCount = 0
            lastLogTime = currentTime
        }
        
        // Use autoreleasepool for memory management
        autoreleasepool {
            // Skip if already processing (prevent queue buildup)
            processingQueue.async { [weak self] in
                guard let self = self else { return }
                
                if self.isProcessing {
                    // Skip this frame
                    return
                }
                
                self.isProcessing = true
                defer { self.isProcessing = false }
                
                // Extract CVPixelBuffer
                if let pixelBuffer = self.extractPixelBuffer(from: frame) {
                    self.processPixelBuffer(pixelBuffer)
                } else {
                    print("⚠️ [CustomVideoSink] Failed to extract CVPixelBuffer")
                }
            }
        }
    }
}

// MARK: - CVPixelBuffer Extraction
extension CustomVideoSink {
    private func extractPixelBuffer(from frame: RTCVideoFrame) -> CVPixelBuffer? {
        let buffer = frame.buffer
        
        // Case A: Direct CVPixelBuffer access (optimal)
        if let cvBuffer = buffer as? RTCCVPixelBuffer {
            print("✅ [CustomVideoSink] Direct CVPixelBuffer access")
            return cvBuffer.pixelBuffer
        }
        
        // Case B: Convert any buffer to I420 first, then to CVPixelBuffer
        print("🔄 [CustomVideoSink] Converting buffer to I420 format...")
        let i420Buffer = buffer.toI420()
        return convertI420ToCVPixelBuffer(i420Buffer, width: Int(frame.width), height: Int(frame.height))
    }
    
    /// Convert I420 (YUV420) buffer to CVPixelBuffer
    /// Uses manual YUV to RGB conversion since libyuv is not available
    private func convertI420ToCVPixelBuffer(_ i420Buffer: RTCI420BufferProtocol, width: Int, height: Int) -> CVPixelBuffer? {
        // Create CVPixelBuffer in BGRA format
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
            ] as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("🔴 [CustomVideoSink] Failed to create CVPixelBuffer: \(status)")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let destAddress = CVPixelBufferGetBaseAddress(buffer) else {
            print("🔴 [CustomVideoSink] Failed to get CVPixelBuffer base address")
            return nil
        }
        
        let destStride = CVPixelBufferGetBytesPerRow(buffer)
        let dest = destAddress.assumingMemoryBound(to: UInt8.self)
        
        // Get YUV data
        let srcY = i420Buffer.dataY
        let srcU = i420Buffer.dataU
        let srcV = i420Buffer.dataV
        let strideY = Int(i420Buffer.strideY)
        let strideU = Int(i420Buffer.strideU)
        let strideV = Int(i420Buffer.strideV)
        
        // Manual YUV to RGB conversion
        for y in 0..<height {
            for x in 0..<width {
                let yIndex = y * strideY + x
                let uvY = y / 2
                let uvX = x / 2
                let uIndex = uvY * strideU + uvX
                let vIndex = uvY * strideV + uvX
                
                let yValue = Int(srcY[yIndex])
                let uValue = Int(srcU[uIndex]) - 128
                let vValue = Int(srcV[vIndex]) - 128
                
                // YUV to RGB conversion formula
                var r = Double(yValue) + (1.370705 * Double(vValue))
                var g = Double(yValue) - (0.337633 * Double(uValue)) - (0.698001 * Double(vValue))
                var b = Double(yValue) + (1.732446 * Double(uValue))
                
                // Clamp to 0-255
                r = min(max(r, 0), 255)
                g = min(max(g, 0), 255)
                b = min(max(b, 0), 255)
                
                // Write BGRA
                let destIndex = y * destStride + x * 4
                dest[destIndex] = UInt8(b)     // B
                dest[destIndex + 1] = UInt8(g) // G
                dest[destIndex + 2] = UInt8(r) // R
                dest[destIndex + 3] = 255      // A
            }
        }
        
        print("✅ [CustomVideoSink] I420 -> CVPixelBuffer conversion successful (\(width)x\(height))")
        return buffer
    }
}

// MARK: - Frame Processing
extension CustomVideoSink {
    private func processPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        // guard let predictor = self.predictor else {
        //     print("⚠️ [CustomVideoSink] Predictor not available")
        //     return
        // }
        
        // // Call DeepfakePredictor's new method
        // if let result = predictor.processPixelBuffer(pixelBuffer) {
        //     sendResultToDart(result)
        // }
    }
    
    private func sendResultToDart(_ result: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let sink = self.eventSink else {
                return
            }
            sink(result)
        }
    }
}

// MARK: - FlutterStreamHandler
extension CustomVideoSink: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, 
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("✅ [CustomVideoSink] EventSink attached")
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("⚠️ [CustomVideoSink] EventSink detached")
        self.eventSink = nil
        return nil
    }
}
