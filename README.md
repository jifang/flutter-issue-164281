# Example app hangs on launch on iOS 
This is a native iOS app with flutter module. We use the single flutter engine pattern.

## Steps to reproduce
### on simulator
1. Run the iOS app
2. App hangs on launch

### on devices
1. Turn on VoiceOver or Switch Control in Accessibility settings
2. Run the iOS app
3. App hangs on launch

## Flutter doctor output
```
[!] Flutter (Channel [user-branch], 3.27.3, on macOS 15.2 24C101 darwin-arm64, locale en-US)
    ! Flutter version 3.27.3 on channel [user-branch] at /Users/ji/Library/Developer/flutter
      Currently on an unknown channel. Run `flutter channel` to switch to an official channel.
      If that doesn't fix the issue, reinstall Flutter by following instructions at https://flutter.dev/setup.
    ! Upstream repository unknown source is not a standard remote.
      Set environment variable "FLUTTER_GIT_URL" to unknown source to dismiss this error.
    • Framework revision c519ee916e (6 weeks ago), 2025-01-21 10:32:23 -0800
    • Engine revision e672b006cb
    • Dart version 3.6.1
    • DevTools version 2.40.2
    • Pub download mirror https://mirrors.tuna.tsinghua.edu.cn/dart-pub
    • Flutter download mirror https://mirrors.tuna.tsinghua.edu.cn/git/flutter
    • If those were intentional, you can disregard the above warnings; however it is recommended to use "git" directly to perform update checks and upgrades.

[✓] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
    • Android SDK at /Users/ji/Library/Android/sdk/
    • Platform android-35, build-tools 34.0.0
    • ANDROID_HOME = /Users/ji/Library/Android/sdk/
    • Java binary at: /Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java
    • Java version OpenJDK Runtime Environment (build 17.0.11+0-17.0.11b1207.24-11852314)
    • All Android licenses accepted.

[✓] Xcode - develop for iOS and macOS (Xcode 16.2)
    • Xcode at /Applications/Xcode.app/Contents/Developer
    • Build 16C5032a
    • CocoaPods version 1.16.2

[✓] Chrome - develop for the web
    • Chrome at /Applications/Google Chrome.app/Contents/MacOS/Google Chrome

[✓] Android Studio (version 2024.1)
    • Android Studio at /Applications/Android Studio.app/Contents
    • Flutter plugin can be installed from:
      🔨 https://plugins.jetbrains.com/plugin/9212-flutter
    • Dart plugin can be installed from:
      🔨 https://plugins.jetbrains.com/plugin/6351-dart
    • Java version OpenJDK Runtime Environment (build 17.0.11+0-17.0.11b1207.24-11852314)

[✓] VS Code (version 1.97.2)
    • VS Code at /Applications/Visual Studio Code.app/Contents
    • Flutter extension version 3.104.0
```

## Further comments
App hangs with a stracktrace below
```
#0	0x0000000104343d7c in __psynch_mutexwait ()
#1	0x0000000104794adc in _pthread_mutex_firstfit_lock_wait ()
#2	0x000000010479265c in _pthread_mutex_firstfit_lock_slow ()
#3	0x0000000107fa59cc in std::_fl::mutex::lock ()
#4	0x0000000107f429b4 in flutter::PlatformViewIOS::SetOwnerViewController ()
#5	0x0000000107f32308 in -[FlutterEngine notifyViewControllerDeallocated] ()
#6	0x00000001803eb7ec in __CFNOTIFICATIONCENTER_IS_CALLING_OUT_TO_AN_OBSERVER__ ()
#7	0x00000001803eb724 in ___CFXRegistrationPost_block_invoke ()
#8	0x00000001803eac14 in _CFXRegistrationPost ()
#9	0x00000001803ea5f0 in _CFXNotificationPost ()
#10	0x0000000180ed6820 in -[NSNotificationCenter postNotificationName:object:userInfo:] ()
#11	0x0000000107f3ba7c in -[FlutterViewController deregisterNotifications] ()
#12	0x0000000107f3baf0 in -[FlutterViewController dealloc] ()
#13	0x0000000107f76b40 in flutter::AccessibilityBridge::~AccessibilityBridge ()
#14	0x0000000107f423f8 in std::_fl::unique_ptr<flutter::AccessibilityBridge, std::_fl::default_delete<flutter::AccessibilityBridge>>::reset[abi:v15000] ()
#15	0x0000000107f423c8 in flutter::PlatformViewIOS::AccessibilityBridgeManager::Clear ()
#16	0x0000000107f429e4 in flutter::PlatformViewIOS::SetOwnerViewController ()
#17	0x0000000107f3205c in -[FlutterEngine setViewController:] ()
#18	0x000000010431f8c4 in FlutterView.makeUIViewController(context:) at /Users/ji/dev/flutter/flutter_add_to_app/MyApp/flutter_add_to_app/FlutterView.swift:15

```
There is clear an re-entrance of method `flutter::PlatformViewIOS::SetOwnerViewController(fml::WeakNSObject<FlutterViewController> const&)` (in Flutter) (platform_view_ios.mm:84)

The implementation of this method
```
void PlatformViewIOS::SetOwnerViewController(__weak FlutterViewController* owner_controller) {
  FML_DCHECK(task_runners_.GetPlatformTaskRunner()->RunsTasksOnCurrentThread());
  std::lock_guard<std::mutex> guard(ios_surface_mutex_);
  if (ios_surface_ || !owner_controller) {
    NotifyDestroyed();
    ios_surface_.reset();
    accessibility_bridge_.Clear();
  }
```
std::mutex is not reentrant.

It's triggered by the enabling the AccessibilityBridge, as in the following code snippet. It may explain why this issue is reproducible in simulator or certain accessibility settings.
```
- (void)onAccessibilityStatusChanged:(NSNotification*)notification {
  if (!_engine) {
    return;
  }
  auto platformView = [_engine.get() platformView];
  int32_t flags = [self accessibilityFlags];
#if TARGET_OS_SIMULATOR
  // There doesn't appear to be any way to determine whether the accessibility
  // inspector is enabled on the simulator. We conservatively always turn on the
  // accessibility bridge in the simulator, but never assistive technology.
  platformView->SetSemanticsEnabled(true);
  platformView->SetAccessibilityFeatures(flags);
#else
  _isVoiceOverRunning = UIAccessibilityIsVoiceOverRunning();
  bool enabled = _isVoiceOverRunning || UIAccessibilityIsSwitchControlRunning();
  if (enabled) {
    flags |= static_cast<int32_t>(flutter::AccessibilityFeatureFlag::kAccessibleNavigation);
  }
  platformView->SetSemanticsEnabled(enabled || UIAccessibilityIsSpeakScreenEnabled());
  platformView->SetAccessibilityFeatures(flags);
#endif
}
```

However, on iOS 18.3.1, UIAccessibilityIsSwitchControlRunning() may return true even when the switch is off. Resulting crash on launch only on certain devices.

From the usage side, I understand that I probably shouldn't call warmupEngine in this case. But I think the engine itself should be robust enough to prevent itself from being deadlocked.

