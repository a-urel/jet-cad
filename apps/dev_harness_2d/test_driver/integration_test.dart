// The driver `flutter drive` needs to run the integration tests in profile
// mode. `flutter test --profile` is not a thing; profile-mode frame timings
// only come out of a real run on a device.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
