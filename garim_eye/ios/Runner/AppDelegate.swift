import Flutter
import UIKit
import WebRTC

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  private var predictor: Any? = nil // Type 'Any' to avoid compile error before model exists
  
  // Native-First Pipeline
  private var customVideoSink: CustomVideoSink?
  private var nativeEventChannel: FlutterEventChannel?
  private var nativeControlChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let messenger = controller.binaryMessenger
    
    // Original Method Channel (Dart → Swift path)
    let channel = FlutterMethodChannel(name: "com.garim.eye/inference",
                                              binaryMessenger: messenger)
    
    if #available(iOS 14.0, *) {
        self.predictor = DeepfakePredictor()
        
        // Initialize Native-First Pipeline
        self.customVideoSink = CustomVideoSink()
        
        // EventChannel for Native → Dart results
        nativeEventChannel = FlutterEventChannel(
            name: "com.garim.eye/native_inference",
            binaryMessenger: messenger
        )
        nativeEventChannel?.setStreamHandler(customVideoSink!)
        
        // MethodChannel for control (attach/detach sink)
        nativeControlChannel = FlutterMethodChannel(
            name: "com.garim.eye/native_control",
            binaryMessenger: messenger
        )
        
        // Set control method handler
        nativeControlChannel?.setMethodCallHandler { [weak self] (call, result) in
            self?.handleNativeControl(call: call, result: result)
        }
    }

    channel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        
      if call.method == "processFrame" {
          guard let args = call.arguments as? FlutterStandardTypedData else {
              result(FlutterError(code: "INVALID_ARGS", message: "Image bytes required", details: nil))
              return
          }
          
          if #available(iOS 14.0, *) {
              if let predictor = self?.predictor as? DeepfakePredictor {
                   // Run on background thread
                   DispatchQueue.global(qos: .userInteractive).async {
                       let response = predictor.processFrame(imageData: args)
                       DispatchQueue.main.async {
                           result(response)
                       }
                   }
              } else {
                  result(FlutterError(code: "MODEL_NOT_READY", message: "Predictor not initialized", details: nil))
              }
          } else {
              result(FlutterError(code: "UNSUPPORTED_OS", message: "iOS 14.0+ required", details: nil))
          }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    
    // Trigger plugin capture
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue]
        )
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
    // MARK: - Native Control Handler
    
    override init() {
        super.init()
        // Swizzle FlutterWebRTCPlugin to capture instance
        MethodSwizzler.swizzleWebRTCPlugin()
    }
  
    private func handleNativeControl(call: FlutterMethodCall, result: @escaping FlutterResult) {
      if call.method == "attach" {
          guard let args = call.arguments as? [String: Any],
                let trackId = args["trackId"] as? String else {
              result(FlutterError(code: "INVALID_ARGS", message: "trackId required", details: nil))
              return
          }
          
          guard let plugin = capturedWebRTCPlugin else {
              result(FlutterError(code: "PLUGIN_NOT_FOUND", message: "FlutterWebRTCPlugin not captured", details: nil))
              return
          }
          
          print("🔵 [AppDelegate] Attaching sink to track: \(trackId)")
          
          // 1. Check Local Tracks (our camera)
          print("🔍 [AppDelegate] Checking LOCAL tracks...")
          if let localTracks = plugin.value(forKey: "localTracks") as? [String: Any] {
              print("   📋 Found \(localTracks.count) local tracks")
              for (id, _) in localTracks {
                  print("   - Local track ID: \(id)")
              }
              if let track = localTracks[trackId] as? RTCVideoTrack {
                  print("✅ [AppDelegate] MATCH in LOCAL tracks: \(trackId)")
                  track.add(self.customVideoSink!)
                  result(true)
                  return
              }
          } else {
              print("   ⚠️ localTracks is nil or wrong type")
          }
          
          // 2. Check Remote Tracks (incoming video from peer) - CRITICAL FOR DEEPFAKE DETECTION
          print("🔍 [AppDelegate] Checking REMOTE tracks via peerConnections...")
          
          // Debug: Check what peerConnections contains
          if let peerConnectionsRaw = plugin.value(forKey: "peerConnections") {
              print("   📋 peerConnections type: \(type(of: peerConnectionsRaw))")
              
              if let peerConnections = peerConnectionsRaw as? [String: RTCPeerConnection] {
                  print("   📋 Found \(peerConnections.count) peer connections")
                  
                  for (connId, peerConnection) in peerConnections {
                      print("   🔍 Searching in peerConnection: \(connId)")
                      print("      Transceivers count: \(peerConnection.transceivers.count)")
                      
                      // Check all transceivers for remote tracks
                      for (index, transceiver) in peerConnection.transceivers.enumerated() {
                          print("      [Transceiver \(index)]")
                          let receiver = transceiver.receiver
                          if let remoteTrack = receiver.track {
                              print("         Track ID: \(remoteTrack.trackId)")
                              print("         Track kind: \(remoteTrack.kind)")
                              
                              if let videoTrack = remoteTrack as? RTCVideoTrack {
                                  if videoTrack.trackId == trackId {
                                      print("✅ [AppDelegate] MATCH! Attaching to REMOTE video track")
                                      videoTrack.add(self.customVideoSink!)
                                      result(true)
                                      return
                                  }
                              }
                          } else {
                              print("         No track in receiver")
                          }
                      }
                  }
              } else {
                  print("   ⚠️ peerConnections is not [String: RTCPeerConnection]")
                  print("   Trying alternative cast...")
                  
                  // Try alternative: Maybe it's stored differently
                  if let dict = peerConnectionsRaw as? [String: Any] {
                      print("   📋 peerConnections is [String: Any] with \(dict.count) entries")
                      for (key, value) in dict {
                          print("      Key: \(key), Value type: \(type(of: value))")
                      }
                  }
              }
          } else {
              print("   ⚠️ peerConnections key not found in plugin")
          }
          
          // 3. Not found anywhere
          print("🔴 [AppDelegate] Track not found with ID: \(trackId)")
          print("   Searched in local tracks and all peer connections")
          result(FlutterError(code: "TRACK_NOT_FOUND", message: "Track not found in local or remote", details: nil))
          
      } else if call.method == "detach" {
          // Detach logic (simplified)
           print("🔵 [AppDelegate] Detach called")
           // We might need to keep track of attached tracks to remove them
           result(true)
      } else {
          result(FlutterMethodNotImplemented)
      }
    }
}
