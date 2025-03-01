import SwiftUI
import Flutter
// The following library connects plugins with iOS platform code to this app.
import FlutterPluginRegistrant

@Observable
class FlutterDependencies {
 let flutterEngine = FlutterEngine(name: "my flutter engine")
 init() {
   // Runs the default Dart entrypoint with a default Flutter route.
   flutterEngine.run()
   self.warmupFlutterEngine()
   // Connects plugins with iOS platform code to this app.
   GeneratedPluginRegistrant.register(with: self.flutterEngine);
 }

 private func warmupFlutterEngine() {
    let vc = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
    vc.beginAppearanceTransition(true, animated: false)
    vc.endAppearanceTransition()
    vc.beginAppearanceTransition(false, animated: false)
    vc.endAppearanceTransition()
 }
}

@main
struct MyApp: App {
   // flutterDependencies will be injected through the view environment.
   @State var flutterDependencies = FlutterDependencies()
   var body: some Scene {
     WindowGroup {
         FlutterView(flutter: flutterDependencies)
         .environment(flutterDependencies)
     }
   }
}
