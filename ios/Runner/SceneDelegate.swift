import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let windowScene = scene as? UIWindowScene {
      let activeWindow = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first ?? self.window
      (UIApplication.shared.delegate as? FlutterAppDelegate)?.window = activeWindow
    }
  }
}
