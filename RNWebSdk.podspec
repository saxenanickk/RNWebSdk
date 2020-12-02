Pod::Spec.new do |s|
    s.name             = 'RNWebSdk'
    s.version          = '0.0.5'
    s.description      = 'RNWebSdk Description'
    s.summary          = 'RNWebSdk Summary'
    s.homepage         = 'https://github.com/saxenanickk/RNWebSdk'
    s.license          = { type: 'MIT', file: 'LICENSE' }
    s.author           = { 'nikhil' => 'Nikhil1.saxena@ril.com' }
    s.source           = { git: 'https://github.com/saxenanickk/RNWebSdk.git', tag: s.version.to_s }
  
    s.source_files   = 'RNWebSdk/**/*.{h,m,swift,xib,plist}'
    s.platform       = :ios, '11.0'
  
    s.static_framework = true
  end
  