import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    let applicationSupportsPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]
    let controller = self.window.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel.init(name: "methods", binaryMessenger: controller as! FlutterBinaryMessenger)

    channel.setMethodCallHandler { (call, result) in
        Thread {
            if call.method == "dataRoot" {
                result(applicationSupportsPath)
            } else if call.method == "documentRoot" {
               result(documentsPath)
            } else if call.method == "getKeepScreenOn" {
                result(application.isIdleTimerDisabled)
            }
            else if call.method == "setKeepScreenOn" {
                if let args = call.arguments as? Bool {
                    DispatchQueue.main.async { () -> Void in
                        application.isIdleTimerDisabled = args
                    }
                }
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }.start()
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
