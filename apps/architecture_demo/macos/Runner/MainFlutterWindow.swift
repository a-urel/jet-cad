import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // Spec 12a D11 (R-4): the close button asks like Cmd+Q. With
  // applicationShouldTerminateAfterLastWindowClosed true, AppKit would close
  // the window first and terminate after, so a cancelled exit would leave a
  // running app with no window. AppKit consults the window's own
  // windowShouldClose(_:); this class does not adopt NSWindowDelegate, so
  // the method is exposed to Objective-C with @objc (T-13). The window stays
  // open, and NSApp.terminate(nil) sends the framework's exit request
  // (FlutterAppDelegate.applicationShouldTerminate), which the app's
  // AppLifecycleListener answers: an allowed exit terminates, a cancelled one
  // leaves the window as it was.
  @objc func windowShouldClose(_ sender: NSWindow) -> Bool {
    NSApp.terminate(nil)
    return false
  }
}
