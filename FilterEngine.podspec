Pod::Spec.new do |spec|
  spec.name = 'FilterEngine'
  spec.version = '4.3.1'
  spec.summary = 'Advanced rules engine for Safari web extensions.'
  spec.description = <<~DESC
    FilterEngine is the advanced blocking module of SafariConverterLib. It
    builds and looks up rules that cannot be expressed as Safari content
    blocking rules: CSS, extended CSS, JavaScript and scriptlets.
  DESC
  spec.homepage = 'https://github.com/AdguardTeam/SafariConverterLib'
  spec.license = { :type => 'GPL-3.0', :file => 'LICENSE' }
  spec.authors = { 'AdGuard' => 'devteam@adguard.com' }
  spec.source = {
    :git => 'https://github.com/AdguardTeam/SafariConverterLib.git',
    :tag => "v#{spec.version}"
  }
  spec.swift_versions = ['5.6']
  spec.ios.deployment_target = '13.0'
  spec.osx.deployment_target = '11.0'
  spec.source_files = 'Sources/FilterEngine/**/*.swift'
  spec.dependency 'ContentBlockerConverter'
  spec.dependency 'swift-psl'
end
