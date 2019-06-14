Pod::Spec.new do |s|
  s.name         = "DVBluetoothSwift"
  s.version      = "0.1.0"
  s.summary      = "A bluetooth manager written by Swift."

  s.description  = "The DVBluetooth help us easier connect and control bluetooth peripheral. 
  It depends on CoreBluetooth."

  s.homepage     = "https://github.com/HeDefine/DVBluetoothSwift.git"
  # s.screenshots  = "www.example.com/screenshots_1.gif", "www.example.com/screenshots_2.gif"

  s.license      = "MIT"

  s.author             = { "Devine He" => "hedingfei1993@126.com" }

  s.platform     = :ios
  #s.platform     = :ios, "9.0"
  s.ios.deployment_target  = '9.0'
  s.source       = { :git => "https://github.com/HeDefine/DVBluetoothSwift.git", :tag => "0.1.0" }
  s.source_files  = "DVBluetoothSwift/**/*.{h,m}"
  s.exclude_files = "DVBluetoothSwiftExample"
  # s.public_header_files = "Classes/**/*.h"


  s.frameworks = "Foundation", "CoreBluetooth"

end
