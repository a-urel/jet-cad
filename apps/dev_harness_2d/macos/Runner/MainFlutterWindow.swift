import Cocoa
import FlutterMacOS

/// The window-size request, and it is the same name Dart reads.
///
/// **`--dart-define` reaches Dart only, and this file is what actually sizes
/// the window**, so the request has to cross the language boundary by some
/// other route. It crosses as an environment variable: `flutter run` starts
/// the app with the parent environment inherited, so
///
/// ```sh
/// export JC_WINDOW=800x600
/// flutter run -d macos --profile --dart-define=JC_WINDOW=$JC_WINDOW ...
/// ```
///
/// gives both sides the same value from one place in the shell. The two are
/// still configured separately and can still disagree; `reportR2Window` on the
/// Dart side prints the window this file really produced and warns when it is
/// not the size Dart was told to expect, and that warning is the only check
/// there is on the boundary.
private let kWindowRequestName = "JC_WINDOW"

/// What a run that asks for nothing gets. Ruling 20 chose it, and criteria 2
/// and 4 are already measured at it, so it does not move.
private let kDefaultWindowRequest = "1400x900"

/// The smallest and largest side a request may name, in logical points. Out of
/// range, AppKit would place what it could and clamp the rest, and the run
/// would measure a window nobody named.
private let kMinWindowSide = 100
private let kMaxWindowSide = 10000

/// The measurement window, pinned to the requested size.
///
/// A measurement harness must create the same window on every launch. Frame
/// times, tile counts and the memory a tile cache holds all scale with the
/// device rectangle, so a window that is the nib default on one run and
/// whatever the operator last dragged on the next produces numbers that
/// cannot be compared with each other -- and nothing in the transcript says
/// so. Before this, `awakeFromNib` read `self.frame` and set it straight
/// back: the window was the nib default, 800x600, while the Dart side fitted
/// its camera to 1600x1200 and handed the zoom phase the same. The code
/// assumed a window it never created.
///
/// **1400x900 by default, and not the design spec's 1600x1200.** Plan 3i's
/// design spec §5 pins 1600x1200 logical at `devicePixelRatio` 2 and prices
/// its memory predictions against the 3200x2400 device rectangle that
/// implies. This display cannot produce it: the logical desktop is 1496x967
/// and the panel is 3456x2234, so at dpr 2 even the widest scaling mode gives
/// 1728x1117 and the height never reaches 1200 in any mode. Ruling 20 records
/// the human's choice of the largest window that does fit. Numbers taken there
/// are therefore not comparable to the spec's priced predictions.
///
/// **And that is why the size is a request and not a literal.** Criterion 9
/// re-measures Plan 3h's `tile pan` and `tile hold` phases against 3h's own
/// recorded figures, and 3h ran at the nib default of 800x600 because nothing
/// in this harness set a window size until 2026-08-28. A larger viewport means
/// more tiles, more bakes and more work per pan frame, so that comparison at
/// 1400x900 measures the viewport change and reads it as a regression. One run
/// at `JC_WINDOW=800x600` removes the confound. See `kMeasurementViewport` in
/// `lib/main.dart`, which parses the same request by the same rules and must
/// agree with whatever this returns.
///
/// **A malformed or absurd request stops the launch rather than falling back.**
/// A measurement that silently ran at a size nobody asked for is the failure
/// this whole area exists to prevent, and a default quietly substituted here
/// would be invisible: the Dart side would refuse the same string, but only
/// after this window already existed at some other size.
private func measurementContentSize() -> NSSize {
  let raw = ProcessInfo.processInfo.environment[kWindowRequestName]
    ?? kDefaultWindowRequest
  print("R2 app-run: \(kWindowRequestName)=\(raw)")
  let parts = raw.split(separator: "x", omittingEmptySubsequences: false)
  if parts.count == 2,
    let width = Int(parts[0]),
    let height = Int(parts[1]),
    width >= kMinWindowSide, width <= kMaxWindowSide,
    height >= kMinWindowSide, height <= kMaxWindowSide
  {
    return NSSize(width: width, height: height)
  }
  fatalError(
    "\(kWindowRequestName) must be WIDTHxHEIGHT in whole logical pixels, "
      + "each side between \(kMinWindowSide) and \(kMaxWindowSide); "
      + "got \"\(raw)\"")
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    let contentSize = measurementContentSize()

    // **`awakeFromNib` alone is not enough, and this is the whole reason the
    // first attempt at pinning the window silently did nothing.** AppKit
    // window state restoration runs ~1.4 s *after* the nib is loaded --
    // `NSPersistentUIRestorer` -> `-[NSWindow restoreStateWithCoder:]` ->
    // `_setFrameFromString:` -- and puts the window back to the frame the
    // last session left behind, which was observed resizing a correctly
    // pinned 1400x900 window down to 800x600 before the first measured frame.
    // A restored frame is exactly "whatever the operator last dragged", so a
    // measurement harness must opt out of it rather than race it.
    self.isRestorable = false

    // Belt and braces, and the part that holds for the rest of the session:
    // with the content min and max equal, AppKit clamps every later
    // `setFrame:` -- restoration, a live drag, a zoom button -- back to the
    // measurement size. Nothing can change the viewport mid-run.
    self.contentMinSize = contentSize
    self.contentMaxSize = contentSize

    // `setContentSize` and not `setFrame`: the frame includes the title bar,
    // so sizing the frame to 1400x900 would leave Flutter a view 32 points
    // short and the harness would measure a viewport nobody named.
    self.setContentSize(contentSize)
    // Centred rather than left wherever the nib put it, so a window pinned to
    // a size larger than the nib's cannot end up part way off-screen.
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
