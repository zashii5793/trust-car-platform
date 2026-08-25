import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps (Issue #43). Read the key from the `MapsApiKey` Info.plist
    // entry (populated at build time from MAPS_API_KEY). Skip when empty so the
    // app runs without a key; the in-app map is gated on MapsConfig.isConfigured.
    if let mapsKey = Bundle.main.object(forInfoDictionaryKey: "MapsApiKey") as? String,
       !mapsKey.isEmpty {
      GMSServices.provideAPIKey(mapsKey)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
