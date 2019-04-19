#
#  Be sure to run `pod spec lint ABLE.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  spec.name         = "ABLE"
  spec.version      = "0.6.0"
  spec.summary      = "A lightweight Bluetooth library for iOS."
  spec.description  = <<-DESC
  Bluetooth library for iOS.
  This lightweight library is a wrapper around the CoreBluetooth api, which adds support for closures to ease handling all ble operations.
  Additionaly, this library supports specifying custom timeouts for all ble operation, which is not possibile by default with CoreBluetooth.
  A few other utility functions are provided as well.
                   DESC
  spec.homepage     = "https://github.com/ale84/ABLE.git"
  spec.license      = "MIT"
  spec.author             = { "Alessio Orlando" => "alessioorlando@icloud.com" }
  spec.platform     = :ios
  spec.platform     = :ios, "10.3"
  spec.source       = { :git => "https://github.com/ale84/ABLE.git", :tag => "#{spec.version}" }
  spec.source_files  = "ABLE", "ABLE/**/*.swift"
  spec.swift_version = "5.0"
end
