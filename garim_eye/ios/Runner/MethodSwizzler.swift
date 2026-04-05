import Foundation
import Flutter

// Global variable to hold the captured plugin instance
var capturedWebRTCPlugin: AnyObject?

class MethodSwizzler {
    static func swizzleWebRTCPlugin() {
        // Find the class
        guard let pluginClass = NSClassFromString("FlutterWebRTCPlugin") else {
            print("🔴 [MethodSwizzler] FlutterWebRTCPlugin class not found")
            return
        }
        
        // Original selector provided by the plugin to handle audio route changes
        let originalSelector = NSSelectorFromString("didSessionRouteChange:")
        
        // New selector (will point to our method implementation)
        let swizzledSelector = #selector(AppDelegate.swizzled_didSessionRouteChange(_:))
        
        // Get methods
        guard let originalMethod = class_getInstanceMethod(pluginClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(AppDelegate.self, swizzledSelector) else {
            print("🔴 [MethodSwizzler] Methods not found for notification swizzling")
            return
        }
        
        // Add the new method to the plugin class
        let didAddMethod = class_addMethod(pluginClass,
                                           swizzledSelector,
                                           method_getImplementation(swizzledMethod),
                                           method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            // Method 2 (Standard): Exchange implementations
            method_exchangeImplementations(originalMethod, class_getInstanceMethod(pluginClass, swizzledSelector)!)
            
            print("✅ [MethodSwizzler] Swizzling successful (Notification Strategy)")
        } else {
            print("🔴 [MethodSwizzler] Failed to add method")
        }
    }
}

// Extension to AppDelegate to provide the swizzled method implementation
extension AppDelegate {
    @objc func swizzled_didSessionRouteChange(_ notification: Notification) {
        // Capture the plugin instance
        if capturedWebRTCPlugin == nil {
            capturedWebRTCPlugin = self
            print("🎣 [MethodSwizzler] FlutterWebRTCPlugin instance captured via Notification!")
        }
        
        // Call the original implementation
        let selector = #selector(AppDelegate.swizzled_didSessionRouteChange(_:))
        if self.responds(to: selector) {
            self.perform(selector, with: notification)
        }
    }
}
