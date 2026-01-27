import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // NOTE: Native security plugins (SqlCipherPlugin, CertPinningPlugin) are available
    // in ios/Runner/ but need to be added to Xcode project to enable.
    // To add: Open Xcode → Right-click Runner folder → Add Files → select .swift files
    // Then uncomment the registrations below:
    //
    // SqlCipherPlugin.register(with: self.registrar(forPlugin: "SqlCipherPlugin")!)
    // CertPinningPlugin.register(with: self.registrar(forPlugin: "CertPinningPlugin")!)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

