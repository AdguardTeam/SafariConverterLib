Pod::Spec.new do |spec|
  spec.name = 'PunycodeSwift'
  spec.version = '3.0.0'
  spec.module_name = 'Punycode'
  spec.summary = 'Punycode converter for Swift.'
  spec.description = <<~DESC
    CocoaPods bridge specification for PunycodeSwift. It builds the `Punycode`
    module from the upstream repository, so that SafariConverterLib can be
    consumed as a pod. The upstream project publishes no podspec of its own.
  DESC
  spec.homepage = 'https://github.com/gumob/PunycodeSwift'
  spec.license = { :type => 'MIT', :file => 'LICENSE' }
  spec.authors = 'Gumob'
  spec.source = {
    :git => 'https://github.com/gumob/PunycodeSwift.git',
    :tag => spec.version.to_s
  }
  spec.swift_versions = ['5.9']
  spec.ios.deployment_target = '12.0'
  spec.osx.deployment_target = '10.13'
  spec.source_files = 'Sources/**/*.swift'
end
