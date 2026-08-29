import Cocoa
import FlutterMacOS

/// The measurement window, pinned.
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
/// **1400x900, and not the design spec's 1600x1200.** Plan 3i's design spec
/// §5 pins 1600x1200 logical at `devicePixelRatio` 2 and prices its memory
/// predictions against the 3200x2400 device rectangle that implies. This
/// display cannot produce it: the logical desktop is 1496x967 and the panel
/// is 3456x2234, so at dpr 2 even the widest scaling mode gives 1728x1117 and
/// the height never reaches 1200 in any mode. Ruling 20 records the human's
/// choice of the largest window that does fit. Numbers taken here are
/// therefore not comparable to the spec's priced predictions -- see
/// `kMeasurementViewport` in `lib/main.dart`, which must hold the same size.
private let kMeasurementContentSize = NSSize(width: 1400, height: 900)

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // `setContentSize` and not `setFrame`: the frame includes the title bar,
    // so sizing the frame to 1400x900 would leave Flutter a view ~28 points
    // short and the harness would measure a viewport nobody named.
    self.setContentSize(kMeasurementContentSize)
    // Centred rather than left where the autosaved frame put it, so a window
    // pinned to a size cannot end up half off-screen and partly occluded.
    self.center()
    self.setFrame(self.frame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
