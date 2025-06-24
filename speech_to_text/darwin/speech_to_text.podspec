#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint speech_to_text.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'speech_to_text'
  s.version          = '7.2.0'
  s.summary          = 'Exposes iOS and macOS speech recognition capabilities to Flutter.'
  s.description      = <<-DESC
A Flutter plugin module for iOS and macOS that uses native speech recognition.
                       DESC
  s.homepage         = 'https://github.com/csdcorp/speech_to_text'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Corner Software Development' => 'info@csdcorp.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'speech_to_text/Sources/speech_to_text/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '11.00'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
  s.ios.dependency 'CwlCatchException'
  s.osx.dependency 'CwlCatchException'

end
