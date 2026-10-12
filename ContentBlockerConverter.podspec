Pod::Spec.new do |spec|
  spec.name = 'ContentBlockerConverter'
  spec.version = '4.3.0'
  spec.summary = 'Converts AdGuard filtering rules into Safari content blocking rules.'
  spec.description = <<~DESC
    ContentBlockerConverter is the core module of SafariConverterLib. It turns
    AdGuard filtering rules into the JSON format that Safari content blockers
    understand, and returns advanced rules that require a web extension.
  DESC
  spec.homepage = 'https://github.com/AdguardTeam/SafariConverterLib'
  spec.license = { :type => 'GPL-3.0', :file => 'LICENSE' }
  spec.authors = { 'AdGuard' => 'devteam@adguard.com' }
  spec.source = {
    :git => 'https://github.com/AdguardTeam/SafariConverterLib.git',
    :tag => "v#{spec.version}"
  }
  spec.swift_versions = ['5.9']
  spec.ios.deployment_target = '13.0'
  spec.osx.deployment_target = '11.0'
  spec.source_files = 'Sources/ContentBlockerConverter/**/*.swift'
  spec.dependency 'PunycodeSwift'
  spec.dependency 'swift-psl'
end
