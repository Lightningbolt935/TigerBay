import AuthenticationServices
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, ASWebAuthenticationPresentationContextProviding {
  private var currentAuthSession: ASWebAuthenticationSession?
  private var authChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      setupAuthChannel(messenger: messenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let messenger = engineBridge.pluginRegistry.registrar(forPlugin: "TigerBayAuthSession")?.messenger() {
      setupAuthChannel(messenger: messenger)
    }
  }

  private func setupAuthChannel(messenger: FlutterBinaryMessenger) {
    guard authChannel == nil else { return }
    let channel = FlutterMethodChannel(name: "io.tigerbay.app/auth_session", binaryMessenger: messenger)
    channel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }
      if call.method == "authenticate" {
        guard let args = call.arguments as? [String: Any],
              let urlString = args["url"] as? String,
              let url = URL(string: urlString),
              let scheme = args["callbackUrlScheme"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing url or callbackUrlScheme", details: nil))
          return
        }

        self.currentAuthSession?.cancel()
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] callbackURL, error in
          self?.currentAuthSession = nil
          if let error = error {
            let nsError = error as NSError
            if nsError.domain == ASWebAuthenticationSessionErrorDomain &&
               nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
              result(FlutterError(code: "CANCELED", message: "User canceled authentication", details: nil))
            } else {
              result(FlutterError(code: "AUTH_ERROR", message: error.localizedDescription, details: nil))
            }
            return
          }
          if let callbackURL = callbackURL {
            result(callbackURL.absoluteString)
          } else {
            result(FlutterError(code: "NO_URL", message: "No callback URL received", details: nil))
          }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        self.currentAuthSession = session
        session.start()
      } else if call.method == "cancel" {
        self.currentAuthSession?.cancel()
        self.currentAuthSession = nil
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    self.authChannel = channel
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    if let window = self.window {
      return window
    }
    if #available(iOS 13.0, *) {
      for scene in UIApplication.shared.connectedScenes {
        if let windowScene = scene as? UIWindowScene {
          for window in windowScene.windows where window.isKeyWindow {
            return window
          }
        }
      }
    }
    return ASPresentationAnchor()
  }
}
