import Foundation

/// Fixed language options for summarization output.
///
/// This list is intentionally finite and based on Gemma 3 multilingual support references:
/// - Gemma 3 model card claims support for over 140 languages.
/// - Gemma 3 multilingual evaluation highlights WMT24++ languages (plus Icelandic from WMT24).
public enum OutputLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case englishUS = "en-US"
    case arabicEgypt = "ar-EG"
    case arabicSaudiArabia = "ar-SA"
    case bengaliIndia = "bn-IN"
    case bulgarianBulgaria = "bg-BG"
    case catalanSpain = "ca-ES"
    case chineseSimplified = "zh-CN"
    case chineseTraditional = "zh-TW"
    case croatianCroatia = "hr-HR"
    case czechCzechia = "cs-CZ"
    case danishDenmark = "da-DK"
    case dutchNetherlands = "nl-NL"
    case estonianEstonia = "et-EE"
    case filipinoPhilippines = "fil-PH"
    case finnishFinland = "fi-FI"
    case frenchCanada = "fr-CA"
    case frenchFrance = "fr-FR"
    case germanGermany = "de-DE"
    case greekGreece = "el-GR"
    case gujaratiIndia = "gu-IN"
    case hebrewIsrael = "he-IL"
    case hindiIndia = "hi-IN"
    case hungarianHungary = "hu-HU"
    case icelandicIceland = "is-IS"
    case indonesianIndonesia = "id-ID"
    case italianItaly = "it-IT"
    case japaneseJapan = "ja-JP"
    case kannadaIndia = "kn-IN"
    case koreanSouthKorea = "ko-KR"
    case latvianLatvia = "lv-LV"
    case lithuanianLithuania = "lt-LT"
    case malayalamIndia = "ml-IN"
    case marathiIndia = "mr-IN"
    case norwegianNorway = "no-NO"
    case persianIran = "fa-IR"
    case polishPoland = "pl-PL"
    case portugueseBrazil = "pt-BR"
    case portuguesePortugal = "pt-PT"
    case punjabiIndia = "pa-IN"
    case romanianRomania = "ro-RO"
    case russianRussia = "ru-RU"
    case serbianSerbia = "sr-RS"
    case slovakSlovakia = "sk-SK"
    case slovenianSlovenia = "sl-SI"
    case spanishMexico = "es-MX"
    case swahiliKenya = "sw-KE"
    case swahiliTanzania = "sw-TZ"
    case swedishSweden = "sv-SE"
    case tamilIndia = "ta-IN"
    case teluguIndia = "te-IN"
    case thaiThailand = "th-TH"
    case turkishTurkey = "tr-TR"
    case ukrainianUkraine = "uk-UA"
    case urduPakistan = "ur-PK"
    case vietnameseVietnam = "vi-VN"
    case zuluSouthAfrica = "zu-ZA"

    public static let defaultSelection: OutputLanguage = .englishUS

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .englishUS:
            return "English (United States)"
        case .arabicEgypt:
            return "Arabic (Egypt)"
        case .arabicSaudiArabia:
            return "Arabic (Saudi Arabia)"
        case .bengaliIndia:
            return "Bengali (India)"
        case .bulgarianBulgaria:
            return "Bulgarian (Bulgaria)"
        case .catalanSpain:
            return "Catalan (Spain)"
        case .chineseSimplified:
            return "Chinese, Simplified (China)"
        case .chineseTraditional:
            return "Chinese, Traditional (Taiwan)"
        case .croatianCroatia:
            return "Croatian (Croatia)"
        case .czechCzechia:
            return "Czech (Czechia)"
        case .danishDenmark:
            return "Danish (Denmark)"
        case .dutchNetherlands:
            return "Dutch (Netherlands)"
        case .estonianEstonia:
            return "Estonian (Estonia)"
        case .filipinoPhilippines:
            return "Filipino (Philippines)"
        case .finnishFinland:
            return "Finnish (Finland)"
        case .frenchCanada:
            return "French (Canada)"
        case .frenchFrance:
            return "French (France)"
        case .germanGermany:
            return "German (Germany)"
        case .greekGreece:
            return "Greek (Greece)"
        case .gujaratiIndia:
            return "Gujarati (India)"
        case .hebrewIsrael:
            return "Hebrew (Israel)"
        case .hindiIndia:
            return "Hindi (India)"
        case .hungarianHungary:
            return "Hungarian (Hungary)"
        case .icelandicIceland:
            return "Icelandic (Iceland)"
        case .indonesianIndonesia:
            return "Indonesian (Indonesia)"
        case .italianItaly:
            return "Italian (Italy)"
        case .japaneseJapan:
            return "Japanese (Japan)"
        case .kannadaIndia:
            return "Kannada (India)"
        case .koreanSouthKorea:
            return "Korean (South Korea)"
        case .latvianLatvia:
            return "Latvian (Latvia)"
        case .lithuanianLithuania:
            return "Lithuanian (Lithuania)"
        case .malayalamIndia:
            return "Malayalam (India)"
        case .marathiIndia:
            return "Marathi (India)"
        case .norwegianNorway:
            return "Norwegian (Norway)"
        case .persianIran:
            return "Persian (Iran)"
        case .polishPoland:
            return "Polish (Poland)"
        case .portugueseBrazil:
            return "Portuguese (Brazil)"
        case .portuguesePortugal:
            return "Portuguese (Portugal)"
        case .punjabiIndia:
            return "Punjabi (India)"
        case .romanianRomania:
            return "Romanian (Romania)"
        case .russianRussia:
            return "Russian (Russia)"
        case .serbianSerbia:
            return "Serbian (Serbia)"
        case .slovakSlovakia:
            return "Slovak (Slovakia)"
        case .slovenianSlovenia:
            return "Slovenian (Slovenia)"
        case .spanishMexico:
            return "Spanish (Mexico)"
        case .swahiliKenya:
            return "Swahili (Kenya)"
        case .swahiliTanzania:
            return "Swahili (Tanzania)"
        case .swedishSweden:
            return "Swedish (Sweden)"
        case .tamilIndia:
            return "Tamil (India)"
        case .teluguIndia:
            return "Telugu (India)"
        case .thaiThailand:
            return "Thai (Thailand)"
        case .turkishTurkey:
            return "Turkish (Turkey)"
        case .ukrainianUkraine:
            return "Ukrainian (Ukraine)"
        case .urduPakistan:
            return "Urdu (Pakistan)"
        case .vietnameseVietnam:
            return "Vietnamese (Vietnam)"
        case .zuluSouthAfrica:
            return "Zulu (South Africa)"
        }
    }

    public var detailText: String {
        "\(displayName) [\(rawValue)]"
    }

    public var summarizationSystemInstruction: String {
        """
        Output language requirement:
        MANDATORY RULE: Write all user-visible JSON string values in \(displayName) (\(rawValue)).
        This requirement overrides conflicting language output instructions elsewhere in the prompt.
        Preserve technical terms, code tokens, APIs, and proper nouns when needed for correctness.
        """
    }

    public var summarizationUserInstruction: String {
        """
        Output language for this request: \(displayName) (\(rawValue)).
        Apply this to all JSON string values.
        """
    }

    public static func resolved(from rawValue: String?) -> OutputLanguage {
        guard let rawValue, let value = OutputLanguage(rawValue: rawValue) else {
            return AppConfiguration.Defaults.defaultOutputLanguage
        }
        return value
    }
}
