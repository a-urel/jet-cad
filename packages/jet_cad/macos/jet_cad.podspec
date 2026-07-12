#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint jet_cad.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'jet_cad'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # macOS ships a pure-Swift plugin (JetCadPlugin.swift, registering the
  # jet_cad/texture MethodChannel); the toy C forwarder that used to relatively
  # import `../src/jet_cad.c` (shared with the linux/windows FFI scaffolds) was
  # removed once the real texture-channel implementation landed, so the glob
  # is narrowed to .swift to say so explicitly instead of matching "anything
  # dropped into Classes/".
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.swift'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'jet_cad_privacy' => ['jet_cad/Sources/jet_cad/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
