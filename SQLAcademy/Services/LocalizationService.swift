import Foundation

final class LocalizationService: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            userDefaults.set(language.rawValue, forKey: languageKey)
        }
    }

    private let userDefaults: UserDefaults
    private let languageKey = "sqlacademy.language.v1"
    private let dictionaries: [AppLanguage: [String: String]]

    init(
        bundle: Bundle = .main,
        userDefaults: UserDefaults = .standard,
        preload: [AppLanguage: [String: String]]? = nil
    ) {
        self.userDefaults = userDefaults
        if
            let raw = userDefaults.string(forKey: languageKey),
            let selected = AppLanguage(rawValue: raw) {
            self.language = selected
        } else {
            self.language = .en
        }

        if let preload {
            self.dictionaries = preload
        } else {
            self.dictionaries = Self.loadDictionaries(bundle: bundle)
        }
    }

    func text(_ key: String) -> String {
        dictionaries[language]?[key]
        ?? dictionaries[.en]?[key]
        ?? key
    }

    private static func loadDictionaries(bundle: Bundle) -> [AppLanguage: [String: String]] {
        var output: [AppLanguage: [String: String]] = [:]
        for language in AppLanguage.allCases {
            let filename = "strings_\(language.rawValue)"
            guard let url = resourceURL(forResource: filename, withExtension: "json", preferredBundle: bundle),
                  let data = try? Data(contentsOf: url),
                  let dictionary = try? JSONDecoder().decode([String: String].self, from: data) else {
                output[language] = [:]
                continue
            }
            output[language] = dictionary
        }
        return output
    }

    private static func resourceURL(forResource name: String, withExtension ext: String, preferredBundle: Bundle) -> URL? {
        for bundle in candidateBundles(preferredBundle: preferredBundle) {
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private static func candidateBundles(preferredBundle: Bundle) -> [Bundle] {
        var bundles: [Bundle] = [
            preferredBundle,
            .main,
            Bundle(for: LocalizationBundleMarker.self)
        ]
        bundles.append(contentsOf: Bundle.allBundles)
        bundles.append(contentsOf: Bundle.allFrameworks)

        var seen: Set<String> = []
        return bundles.filter { bundle in
            let path = bundle.bundleURL.path
            if seen.contains(path) {
                return false
            }
            seen.insert(path)
            return true
        }
    }
}

private final class LocalizationBundleMarker {}
