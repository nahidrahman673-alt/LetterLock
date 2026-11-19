//
//  WordList.swift
//  LetterLock
//
//  Known answers for each category. An answer found here is marked with a ✓ at the reveal, and other
//  names for the same thing count as the same answer ("UK" and "United Kingdom", "Bombay" and "Mumbai").
//  An answer that isn't here plays as before: players decide with Veto.
//

import Foundation

/// An answer the app recognises.
struct VerifiedName: Hashable, Sendable {
    /// What scoring compares, so other names for the same thing match.
    let key: String
    /// Countries and first names are settled facts, so they can't be vetoed. Everything else can
    /// (a town nobody has heard of, a "celebrity" only one player knows).
    let canVeto: Bool
}

nonisolated enum WordList {
    static func verify(_ text: String, category: String) -> VerifiedName? {
        let typed = normalized(text)
        guard !typed.isEmpty, let list = list(for: category) else { return nil }
        var main = list.table[typed]
        // "Lions" counts as Lion, "Strawberries" as Strawberry.
        if main == nil, list.allowsPlurals {
            main = singulars(of: typed).lazy.compactMap { list.table[$0] }.first
        }
        return main.map { VerifiedName(key: category + ":" + $0, canVeto: list.canVeto) }
    }

    /// Reads the big lists ahead of time, so the first reveal doesn't wait for them.
    static func preload() {
        for list in [cities, boys, girls, animals, food, movies, celebrities, brands] { _ = list.table.count }
    }

    private struct List: Sendable {
        let table: [String: String]
        let canVeto: Bool
        var allowsPlurals = false
    }

    private static func list(for category: String) -> List? {
        switch category {
        case "Country": countries
        case "City": cities
        case "Boy's Name": boys
        case "Girl's Name": girls
        case "Animal": animals
        case "Food/Drink": food
        case "Movies/Series": movies
        case "Celebrity": celebrities
        case "Brand": brands
        default: nil   // Book/Movie Character is left to the players.
        }
    }

    private static let countries = List(table: countryTable, canVeto: false)
    /// GeoNames (geonames.org, CC BY 4.0): every city of 15,000 people or more.
    private static let cities = List(table: load("cities"), canVeto: true)
    /// Wikidata first names (CC0). Unisex names are on both lists.
    private static let boys = List(table: load("boys"), canVeto: false)
    private static let girls = List(table: load("girls"), canVeto: false)
    /// Hand-written: Tools/word_sources/.
    private static let animals = List(table: load("animals"), canVeto: true, allowsPlurals: true)
    private static let food = List(table: load("food"), canVeto: true, allowsPlurals: true)
    /// Wikidata (CC0): the best-known films, series, people and brands.
    private static let movies = List(table: load("movies"), canVeto: true)
    private static let celebrities = List(table: load("celebrities"), canVeto: true)
    private static let brands = List(table: load("brands"), canVeto: true)

    /// Reads one of the WordLists files: a line per thing, best known first, main name then other names,
    /// all already in `normalized` form. Main names beat other names, so "Paris" is Paris, France,
    /// and all the Springfields are one answer.
    private static func load(_ name: String) -> [String: String] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var table: [String: String] = [:]
        var otherNames: [(String, String)] = []
        for line in text.split(separator: "\n") {
            let names = line.split(separator: " ").map(String.init)
            guard let main = names.first else { continue }
            if table[main] == nil { table[main] = main }
            for name in names.dropFirst() { otherNames.append((name, main)) }
        }
        for (name, main) in otherNames where table[name] == nil { table[name] = main }
        return table
    }

    /// What a plural might be the plural of: "foxes" → "foxe", "fox"; "cherries" → "cherry".
    private static func singulars(of word: String) -> [String] {
        var options: [String] = []
        if word.hasSuffix("ies") { options.append(String(word.dropLast(3)) + "y") }
        if word.hasSuffix("es") { options.append(String(word.dropLast(2))) }
        if word.hasSuffix("s") { options.append(String(word.dropLast())) }
        return options
    }

    /// Lowercase, no accents, "&" read as "and", a leading "The" dropped, "St" read as "Saint", then only
    /// letters and digits: "The Hague" is "hague", "St. Louis" is "saintlouis".
    /// Tools/make_word_lists.py writes the lists in this form, so the two must stay in step.
    static func normalized(_ text: String) -> String {
        let folded = text.lowercased()
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .map { special[$0] ?? String($0) }
            .joined()
            .replacingOccurrences(of: "&", with: " and ")
        var words = folded
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
            .map { String($0.filter { $0.isLetter || $0.isNumber }) }
            .filter { !$0.isEmpty }
        if words.count > 1, words[0] == "the" { words.removeFirst() }
        if words.first == "st" { words[0] = "saint" }
        return words.joined()
    }

    /// Letters that keep their mark when accents are stripped.
    private static let special: [Character: String] = [
        "ø": "o", "ł": "l", "ß": "ss", "æ": "ae", "œ": "oe", "đ": "d", "ð": "d", "þ": "th", "ı": "i",
    ]

    /// Every name a country goes by, mapped to its main name.
    private static let countryTable: [String: String] = {
        var table: [String: String] = [:]
        for line in countryNames {
            let names = line.split(separator: "|").map { normalized(String($0)) }
            for name in names where table[name] == nil { table[name] = names[0] }
        }
        return table
    }()

    /// The 193 UN members, Kosovo, Palestine, Taiwan, Vatican City and the four UK nations.
    /// First name is the main one; the rest are other names it goes by.
    private static let countryNames: [String] = [
        "Afghanistan", "Albania", "Algeria", "Andorra", "Angola",
        "Antigua and Barbuda|Antigua", "Argentina", "Armenia", "Australia", "Austria",
        "Azerbaijan", "Bahamas", "Bahrain", "Bangladesh", "Barbados",
        "Belarus|Byelorussia|Belorussia", "Belgium", "Belize", "Benin|Dahomey", "Bhutan",
        "Bolivia", "Bosnia and Herzegovina|Bosnia|Bosnia Herzegovina", "Botswana", "Brazil|Brasil",
        "Brunei|Brunei Darussalam", "Bulgaria", "Burkina Faso", "Burundi", "Cape Verde|Cabo Verde",
        "Cambodia|Kampuchea", "Cameroon", "Canada", "Central African Republic", "Chad",
        "Chile", "China|People's Republic of China|PRC", "Colombia", "Comoros",
        "Congo|Republic of the Congo|Congo Brazzaville",
        "DR Congo|Democratic Republic of the Congo|Democratic Republic of Congo|DRC|Congo Kinshasa|Zaire",
        "Costa Rica", "Ivory Coast|Côte d'Ivoire", "Croatia", "Cuba", "Cyprus",
        "Czechia|Czech Republic", "Denmark", "Djibouti", "Dominica", "Dominican Republic",
        "Ecuador", "Egypt", "El Salvador", "Equatorial Guinea", "Eritrea",
        "Estonia", "Eswatini|Swaziland", "Ethiopia|Abyssinia", "Fiji", "Finland",
        "France", "Gabon", "Gambia", "Georgia", "Germany|Deutschland",
        "Ghana", "Greece|Hellas", "Grenada", "Guatemala", "Guinea",
        "Guinea-Bissau", "Guyana", "Haiti", "Honduras", "Hungary",
        "Iceland", "India", "Indonesia", "Iran|Persia", "Iraq",
        "Ireland|Republic of Ireland|Eire", "Israel", "Italy|Italia", "Jamaica", "Japan|Nippon",
        "Jordan", "Kazakhstan", "Kenya", "Kiribati", "Kuwait",
        "Kyrgyzstan|Kirghizia", "Laos|Lao", "Latvia", "Lebanon", "Lesotho",
        "Liberia", "Libya", "Liechtenstein", "Lithuania", "Luxembourg|Luxemburg",
        "Madagascar", "Malawi", "Malaysia", "Maldives", "Mali",
        "Malta", "Marshall Islands", "Mauritania", "Mauritius", "Mexico",
        "Micronesia|Federated States of Micronesia", "Moldova", "Monaco", "Mongolia", "Montenegro",
        "Morocco", "Mozambique", "Myanmar|Burma", "Namibia", "Nauru",
        "Nepal", "Netherlands|Holland", "New Zealand|Aotearoa", "Nicaragua", "Niger",
        "Nigeria", "North Korea|DPRK|Democratic People's Republic of Korea", "North Macedonia|Macedonia",
        "Norway", "Oman",
        "Pakistan", "Palau", "Palestine|State of Palestine", "Panama", "Papua New Guinea|PNG",
        "Paraguay", "Peru", "Philippines", "Poland", "Portugal",
        "Qatar", "Romania|Rumania", "Russia|Russian Federation", "Rwanda",
        "Saint Kitts and Nevis|Saint Kitts", "Saint Lucia", "Saint Vincent and the Grenadines|Saint Vincent",
        "Samoa", "San Marino", "Sao Tome and Principe|Sao Tome", "Saudi Arabia", "Senegal",
        "Serbia", "Seychelles", "Sierra Leone", "Singapore", "Slovakia",
        "Slovenia", "Solomon Islands", "Somalia", "South Africa", "South Korea|Korea|Republic of Korea",
        "South Sudan", "Spain|España", "Sri Lanka|Ceylon", "Sudan", "Suriname|Surinam",
        "Sweden", "Switzerland", "Syria", "Taiwan", "Tajikistan",
        "Tanzania", "Thailand|Siam", "East Timor|Timor-Leste", "Togo", "Tonga",
        "Trinidad and Tobago|Trinidad", "Tunisia", "Turkey|Türkiye", "Turkmenistan", "Tuvalu",
        "Uganda", "Ukraine", "United Arab Emirates|UAE|Emirates",
        "United Kingdom|UK|Great Britain|Britain|GB",
        "United States|USA|US|America|United States of America",
        "Uruguay", "Uzbekistan", "Vanuatu", "Vatican City|Vatican|Holy See", "Venezuela",
        "Vietnam|Viet Nam", "Yemen", "Zambia", "Zimbabwe", "Kosovo",
        "England", "Scotland", "Wales", "Northern Ireland",
    ]
}
