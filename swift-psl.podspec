Pod::Spec.new do |spec|
  spec.name = 'swift-psl'
  spec.version = '1.1.43'
  spec.module_name = 'PublicSuffixList'
  spec.summary = 'Public Suffix List support for Swift.'
  spec.description = <<~DESC
    CocoaPods bridge specification for swift-psl. It builds the
    `PublicSuffixList` module and ships its resource files. The upstream
    project publishes no podspec of its own and relies on `Bundle.module`,
    which SwiftPM generates; the spec provides that symbol for CocoaPods.
  DESC
  spec.homepage = 'https://github.com/ameshkov/swift-psl'
  spec.license = { :type => 'MIT', :file => 'LICENSE' }
  spec.authors = 'Andrey Meshkov'
  spec.source = {
    :git => 'https://github.com/ameshkov/swift-psl.git',
    :tag => "v#{spec.version}"
  }
  spec.swift_versions = ['5.9']
  spec.ios.deployment_target = '12.0'
  spec.osx.deployment_target = '10.13'
  spec.source_files = ['Sources/PublicSuffixList/**/*.swift', 'BundleModule.swift']
  spec.resource_bundles = { 'swift-psl' => ['Sources/PublicSuffixList/Resources/*'] }
  spec.prepare_command = <<~CMD
    cat > BundleModule.swift <<'SWIFT'
    import Foundation

    /// CocoaPods shim for `Bundle.module`, which SwiftPM generates and
    /// CocoaPods does not. swift-psl uses that symbol to locate its resource
    /// files, so the shim resolves the resource bundle shipped by this pod.
    private final class BundleToken {}

    extension Bundle {
        static let module: Bundle = {
            let bundleName = "swift-psl"
            let candidates = [
                Bundle(for: BundleToken.self).resourceURL,
                Bundle.main.resourceURL
            ].compactMap { $0 }

            for candidate in candidates {
                let bundleURL = candidate.appendingPathComponent(bundleName + ".bundle")
                if let bundle = Bundle(url: bundleURL) {
                    return bundle
                }
            }

            return Bundle(for: BundleToken.self)
        }()
    }
    SWIFT
  CMD
end
