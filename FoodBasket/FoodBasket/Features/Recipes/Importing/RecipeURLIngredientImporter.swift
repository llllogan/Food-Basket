//
//  RecipeURLIngredientImporter.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import Foundation

struct ImportedRecipeIngredient: Equatable, Sendable {
    let rawLine: String
    let amountText: String?
    let quantity: Double?
    let unitText: String?
    let name: String
    let preparationMethod: String?
}

struct ImportedRecipeIngredients: Equatable, Sendable {
    let sourceURL: URL
    let title: String?
    let recipeYield: String?
    let cookingTimeMinutes: Int?
    let instructions: [String]
    let ingredients: [ImportedRecipeIngredient]

    nonisolated var ingredientLines: [String] {
        ingredients.map(\.rawLine)
    }
}

enum RecipeURLIngredientImportError: LocalizedError, Equatable {
    case unsupportedURL
    case requestFailed(Int)
    case unreadableResponse
    case noIngredientsFound

    var errorDescription: String? {
        switch self {
        case .unsupportedURL:
            return "Use an http or https recipe URL."
        case .requestFailed(let statusCode):
            return "The recipe page could not be loaded. Server response: \(statusCode)."
        case .unreadableResponse:
            return "The recipe page could not be read."
        case .noIngredientsFound:
            return "No ingredients were found on that page."
        }
    }
}

enum RecipeURLIngredientImporter {
    nonisolated static func importRecipe(from url: URL) async throws -> ImportedRecipeIngredients {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            throw RecipeURLIngredientImportError.unsupportedURL
        }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 26_5 like Mac OS X) FoodBasket/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw RecipeURLIngredientImportError.requestFailed(httpResponse.statusCode)
        }

        guard let html = decodedHTML(from: data, response: response) else {
            throw RecipeURLIngredientImportError.unreadableResponse
        }

        return try parse(html: html, sourceURL: url)
    }

    nonisolated static func parse(html: String, sourceURL: URL) throws -> ImportedRecipeIngredients {
        if let recipe = importedRecipeFromJSONLD(in: html, sourceURL: sourceURL) {
            return recipe
        }

        let ingredientLines = ingredientLinesFromHTMLFallbacks(in: html)
        guard !ingredientLines.isEmpty else {
            throw RecipeURLIngredientImportError.noIngredientsFound
        }

        return ImportedRecipeIngredients(
            sourceURL: sourceURL,
            title: titleFromHTML(in: html),
            recipeYield: nil,
            cookingTimeMinutes: nil,
            instructions: [],
            ingredients: ingredientLines.map(RecipeIngredientLineParser.parse)
        )
    }

    private nonisolated static func decodedHTML(from data: Data, response: URLResponse) -> String? {
        if let encodingName = response.textEncodingName {
            let encoding = CFStringConvertEncodingToNSStringEncoding(
                CFStringConvertIANACharSetNameToEncoding(encodingName as CFString)
            )

            if encoding != UInt(kCFStringEncodingInvalidId),
               let html = String(data: data, encoding: String.Encoding(rawValue: encoding)) {
                return html
            }
        }

        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
    }

    private nonisolated static func importedRecipeFromJSONLD(
        in html: String,
        sourceURL: URL
    ) -> ImportedRecipeIngredients? {
        let scripts = regexMatches(
            pattern: #"<script[^>]*type\s*=\s*["'][^"']*application/ld\+json[^"']*["'][^>]*>(.*?)</script>"#,
            in: html
        )

        for script in scripts {
            let cleanedJSON = script
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingHTMLCommentWrapper()

            guard let data = cleanedJSON.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) else {
                continue
            }

            let recipes = recipeObjects(from: object)
            guard let recipe = recipes
                .compactMap({ importedRecipe(from: $0, sourceURL: sourceURL) })
                .first(where: { !$0.ingredientLines.isEmpty }) else {
                continue
            }

            return recipe
        }

        return nil
    }

    private nonisolated static func recipeObjects(from object: Any) -> [[String: Any]] {
        if let array = object as? [Any] {
            return array.flatMap(recipeObjects)
        }

        guard let dictionary = object as? [String: Any] else {
            return []
        }

        var recipes: [[String: Any]] = []

        if isRecipeObject(dictionary) {
            recipes.append(dictionary)
        }

        for key in ["@graph", "graph", "mainEntity", "mainEntityOfPage", "itemListElement"] {
            if let nestedObject = dictionary[key] {
                recipes.append(contentsOf: recipeObjects(from: nestedObject))
            }
        }

        return recipes
    }

    private nonisolated static func isRecipeObject(_ dictionary: [String: Any]) -> Bool {
        if dictionary["recipeIngredient"] != nil || dictionary["ingredients"] != nil {
            return true
        }

        guard let type = dictionary["@type"] else { return false }

        if let type = type as? String {
            return type.localizedCaseInsensitiveContains("Recipe")
        }

        if let types = type as? [Any] {
            return types.contains {
                guard let type = $0 as? String else { return false }
                return type.localizedCaseInsensitiveContains("Recipe")
            }
        }

        return false
    }

    private nonisolated static func importedRecipe(
        from dictionary: [String: Any],
        sourceURL: URL
    ) -> ImportedRecipeIngredients? {
        let ingredients = dictionary["recipeIngredient"] ?? dictionary["ingredients"]
        let ingredientLines = normalizedIngredientLines(from: ingredients)

        guard !ingredientLines.isEmpty else {
            return nil
        }

        return ImportedRecipeIngredients(
            sourceURL: sourceURL,
            title: firstStringValue(for: ["name", "headline"], in: dictionary),
            recipeYield: recipeYield(from: dictionary["recipeYield"] ?? dictionary["yield"]),
            cookingTimeMinutes: durationMinutes(from: dictionary["totalTime"]),
            instructions: instructionLines(from: dictionary["recipeInstructions"]),
            ingredients: ingredientLines.map(RecipeIngredientLineParser.parse)
        )
    }

    private nonisolated static func normalizedIngredientLines(from object: Any?) -> [String] {
        let rawLines: [String]

        switch object {
        case let string as String:
            rawLines = [string]
        case let array as [Any]:
            rawLines = array.flatMap { normalizedIngredientLines(from: $0) }
        case let dictionary as [String: Any]:
            rawLines = [
                firstStringValue(for: ["text", "name", "value"], in: dictionary)
            ].compactMap { $0 }
        default:
            rawLines = []
        }

        return rawLines.normalizedIngredientLineList()
    }

    private nonisolated static func ingredientLinesFromHTMLFallbacks(in html: String) -> [String] {
        var rawLines: [String] = []

        rawLines.append(
            contentsOf: regexMatches(
                pattern: #"<[^>]+itemprop\s*=\s*["'](?:recipeIngredient|ingredients)["'][^>]*>(.*?)</[^>]+>"#,
                in: html
            )
        )

        rawLines.append(
            contentsOf: regexMatches(
                pattern: #"<li[^>]+(?:class|data-[^=]+)\s*=\s*["'][^"']*ingredient[^"']*["'][^>]*>(.*?)</li>"#,
                in: html
            )
        )

        return rawLines.normalizedIngredientLineList()
    }

    private nonisolated static func titleFromHTML(in html: String) -> String? {
        let metaTitle = regexMatches(
            pattern: #"<meta[^>]+property\s*=\s*["']og:title["'][^>]+content\s*=\s*["']([^"']+)["'][^>]*>"#,
            in: html
        ).first

        if let title = metaTitle?.cleanedIngredientLine, !title.isEmpty {
            return title
        }

        return regexMatches(
            pattern: #"<title[^>]*>(.*?)</title>"#,
            in: html
        ).first?.cleanedIngredientLine
    }

    private nonisolated static func firstStringValue(
        for keys: [String],
        in dictionary: [String: Any]
    ) -> String? {
        for key in keys {
            if let string = dictionary[key] as? String {
                return string.cleanedIngredientLine
            }
        }

        return nil
    }

    private nonisolated static func recipeYield(from object: Any?) -> String? {
        switch object {
        case let string as String:
            return string.cleanedIngredientLine
        case let number as NSNumber:
            return number.stringValue
        case let array as [Any]:
            return array
                .compactMap(recipeYield)
                .joined(separator: ", ")
                .nilIfEmpty
        default:
            return nil
        }
    }

    private nonisolated static func durationMinutes(from object: Any?) -> Int? {
        guard let duration = recipeYield(from: object) else { return nil }

        let pattern = #"^P(?:(\d+(?:\.\d+)?)D)?(?:T(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(duration.startIndex..<duration.endIndex, in: duration)
        guard let match = regex.firstMatch(in: duration, range: range) else {
            return nil
        }

        func value(at index: Int) -> Double {
            guard match.range(at: index).location != NSNotFound,
                  let range = Range(match.range(at: index), in: duration),
                  let value = Double(duration[range]) else {
                return 0
            }

            return value
        }

        let totalSeconds =
            (value(at: 1) * 24 * 60 * 60) +
            (value(at: 2) * 60 * 60) +
            (value(at: 3) * 60) +
            value(at: 4)

        guard totalSeconds > 0 else { return nil }
        return Int((totalSeconds / 60).rounded(.up))
    }

    private nonisolated static func instructionLines(from object: Any?) -> [String] {
        switch object {
        case let string as String:
            return [string.cleanedIngredientLine].filter { !$0.isEmpty }
        case let array as [Any]:
            return array
                .flatMap(instructionLines)
                .normalizedIngredientLineList()
        case let dictionary as [String: Any]:
            var lines: [String] = []

            if let text = firstStringValue(for: ["text"], in: dictionary) {
                lines.append(text)
            }

            if let nestedObject = dictionary["itemListElement"] {
                lines.append(contentsOf: instructionLines(from: nestedObject))
            }

            if lines.isEmpty,
               let directionObject = dictionary["itemListElement"] ?? dictionary["item"] {
                lines.append(contentsOf: instructionLines(from: directionObject))
            }

            return lines.normalizedIngredientLineList()
        default:
            return []
        }
    }

    private nonisolated static func regexMatches(pattern: String, in string: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.matches(in: string, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let matchRange = Range(match.range(at: 1), in: string) else {
                return nil
            }

            return String(string[matchRange])
        }
    }
}

enum RecipeIngredientLineParser {
    private nonisolated static let supportedUnits = [
        "tablespoons", "tablespoon", "tbsp", "tbsps", "tbsp.",
        "teaspoons", "teaspoon", "tsp", "tsps", "tsp.",
        "cups", "cup",
        "fluid ounces", "fluid ounce", "fl oz", "fl. oz.",
        "ounces", "ounce", "oz", "oz.",
        "pounds", "pound", "lbs", "lb", "lbs.", "lb.",
        "grams", "gram", "g",
        "kilograms", "kilogram", "kg",
        "milliliters", "millilitres", "milliliter", "millilitre", "ml",
        "liters", "litres", "liter", "litre", "l",
        "packages", "package", "packets", "packet",
        "cans", "can", "jars", "jar",
        "cloves", "clove",
        "bunches", "bunch",
        "sprigs", "sprig",
        "slices", "slice",
        "pieces", "piece",
        "sticks", "stick",
        "pinches", "pinch",
        "dashes", "dash",
        "punnets", "punnet",
        "fillets", "fillet",
        "heads", "head",
        "stalks", "stalk",
        "bottles", "bottle",
        "handfuls", "handful"
    ]

    nonisolated static func parse(_ rawLine: String) -> ImportedRecipeIngredient {
        let line = rawLine.cleanedIngredientLine
        let parseLine = normalizedLineForParsing(line)
        let amount = leadingAmount(in: parseLine)
        var remainder = parseLine

        if let amount {
            remainder = String(remainder.dropFirst(amount.matchedText.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let unit = leadingUnit(in: remainder)
        if let unit {
            remainder = String(remainder.dropFirst(unit.text.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if amount != nil {
            remainder = removingLeadingAlternateAmount(from: remainder)
        }

        let ingredientName = normalizedIngredientName(
            from: remainder,
            unit: unit?.text,
            amountIncludesPackageSize: amount?.includesPackageSize == true
        )
        let preparationMethod = preparationMethod(from: remainder)

        return ImportedRecipeIngredient(
            rawLine: line,
            amountText: amount?.text,
            quantity: amount?.quantity,
            unitText: unit?.text,
            name: ingredientName.isEmpty ? line : ingredientName,
            preparationMethod: preparationMethod
        )
    }

    private nonisolated static func normalizedLineForParsing(_ line: String) -> String {
        line
            .normalizedFractionsForParsing()
            .separatingCompactIngredientUnits(supportedUnits)
    }

    private nonisolated static func leadingAmount(in line: String) -> ParsedIngredientAmount? {
        let normalizedLine = normalizedLineForParsing(line)
        if let alternateMeasurementAmount = leadingAmountBeforeAlternateMeasurement(in: normalizedLine) {
            return alternateMeasurementAmount
        }

        let patterns = [
            #"^((?:\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)(?:\s*(?:-|–|to)\s*(?:\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?))?\s*(?:\([^)]+\))?)(?=\s|$)"#,
            #"^((?:a|an)\s+(?:few|pinch|handful|sprinkle))\b"#,
            #"^((?:a|an))\b"#
        ]

        for pattern in patterns {
            guard let match = firstRegexMatch(pattern: pattern, in: normalizedLine) else {
                continue
            }

            let quantity = quantity(from: match)
            return ParsedIngredientAmount(
                matchedText: match.cleanedIngredientLine,
                text: displayAmountText(from: match, quantity: quantity),
                quantity: quantity,
                includesPackageSize: match.contains("(") && match.contains(")")
            )
        }

        return nil
    }

    private nonisolated static func leadingAmountBeforeAlternateMeasurement(
        in line: String
    ) -> ParsedIngredientAmount? {
        let pattern = #"^(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let firstAmountRange = Range(match.range(at: 1), in: line),
              let alternateAmountRange = Range(match.range(at: 2), in: line),
              let alternateQuantity = Double(line[alternateAmountRange]),
              alternateQuantity > 16 else {
            return nil
        }

        let remainderAfterAlternateAmount = String(line[alternateAmountRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard leadingUnit(in: remainderAfterAlternateAmount) != nil else {
            return nil
        }

        let amountText = String(line[firstAmountRange])
        let quantity = Double(amountText)
        return ParsedIngredientAmount(
            matchedText: amountText,
            text: displayAmountText(from: amountText, quantity: quantity),
            quantity: quantity,
            includesPackageSize: false
        )
    }

    private nonisolated static func leadingUnit(in line: String) -> ParsedIngredientUnit? {
        for unit in supportedUnits {
            let escapedUnit = NSRegularExpression.escapedPattern(for: unit)
            guard let match = firstRegexMatch(pattern: #"^(\#(escapedUnit))\b"#, in: line) else {
                continue
            }

            return ParsedIngredientUnit(text: String(line.prefix(match.count)).cleanedIngredientLine)
        }

        return nil
    }

    private nonisolated static func removingLeadingAlternateAmount(from rawRemainder: String) -> String {
        let trimmedRemainder = rawRemainder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedRemainder.hasPrefix("/") else {
            return rawRemainder
        }

        var alternateRemainder = String(trimmedRemainder.dropFirst())
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let alternateAmount = leadingAmount(in: alternateRemainder) else {
            return rawRemainder
        }

        alternateRemainder = String(alternateRemainder.dropFirst(alternateAmount.matchedText.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let alternateUnit = leadingUnit(in: alternateRemainder) else {
            return rawRemainder
        }

        return String(alternateRemainder.dropFirst(alternateUnit.text.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func normalizedIngredientName(
        from rawRemainder: String,
        unit: String?,
        amountIncludesPackageSize: Bool
    ) -> String {
        var name = rawRemainder
            .removingParentheticalNotes()
            .removingPreparationClause()
            .cleanedIngredientLine
            .removingLeadingDescriptors()
            .removingTrailingDescriptors()

        if amountIncludesPackageSize,
           let unit,
           ["package", "packages"].contains(unit.normalizedLookupValue),
           !name.localizedCaseInsensitiveContains("package") {
            name = "\(name) \(unit)"
        }

        return name.cleanedIngredientLine
    }

    private nonisolated static func preparationMethod(from rawRemainder: String) -> String? {
        rawRemainder
            .preparationClause()
            .cleanedIngredientLine
            .nilIfEmpty
    }

    private nonisolated static func quantity(from rawAmount: String) -> Double? {
        let amount = rawAmount
            .normalizedFractionsForParsing()
            .replacingOccurrences(
                of: #"\([^)]+\)"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let firstAmount = amount
            .components(separatedBy: " to ")
            .first?
            .components(separatedBy: "-")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let firstAmount else { return nil }

        if firstAmount == "a" || firstAmount == "an" {
            return 1
        }

        let parts = firstAmount
            .split(separator: " ")
            .map(String.init)

        if parts.count == 2,
           let whole = Double(parts[0]),
           let fraction = fractionValue(from: parts[1]) {
            return whole + fraction
        }

        if let fraction = fractionValue(from: firstAmount) {
            return fraction
        }

        return Double(firstAmount)
    }

    private nonisolated static func displayAmountText(from rawAmount: String, quantity: Double?) -> String {
        let cleanedAmount = rawAmount.cleanedIngredientLine

        guard let quantity,
              !cleanedAmount.contains("("),
              !cleanedAmount.contains("-"),
              !cleanedAmount.localizedCaseInsensitiveContains(" to ") else {
            return cleanedAmount
        }

        return quantity.formatted(.number.precision(.fractionLength(0...3)))
    }

    private nonisolated static func fractionValue(from string: String) -> Double? {
        let parts = string.split(separator: "/")
        guard parts.count == 2,
              let numerator = Double(parts[0]),
              let denominator = Double(parts[1]),
              denominator != 0 else {
            return nil
        }

        return numerator / denominator
    }

    private nonisolated static func firstRegexMatch(pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, range: range),
              let matchRange = Range(match.range(at: 1), in: string) else {
            return nil
        }

        return String(string[matchRange])
    }
}

private struct ParsedIngredientAmount {
    let matchedText: String
    let text: String
    let quantity: Double?
    let includesPackageSize: Bool
}

private struct ParsedIngredientUnit {
    let text: String
}

private extension Array where Element == String {
    nonisolated func normalizedIngredientLineList() -> [String] {
        var seen = Set<String>()
        var lines: [String] = []

        for rawLine in self {
            let line = rawLine.cleanedIngredientLine
            guard !line.isEmpty else { continue }

            let lookupValue = line.normalizedLookupValue
            guard !seen.contains(lookupValue) else { continue }

            seen.insert(lookupValue)
            lines.append(line)
        }

        return lines
    }
}

private extension String {
    nonisolated var cleanedIngredientLine: String {
        strippingHTMLTags()
            .decodingHTMLEntities()
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-*• )]}"))
    }

    nonisolated func trimmingHTMLCommentWrapper() -> String {
        var value = self

        if value.hasPrefix("<!--") {
            value.removeFirst(4)
        }

        if value.hasSuffix("-->") {
            value.removeLast(3)
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated func strippingHTMLTags() -> String {
        replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
    }

    nonisolated func decodingHTMLEntities() -> String {
        var decoded = self
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: #"""#)
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")

        let pattern = #"&#(\d+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return decoded
        }

        let matches = regex.matches(
            in: decoded,
            range: NSRange(decoded.startIndex..<decoded.endIndex, in: decoded)
        ).reversed()

        for match in matches {
            guard let fullRange = Range(match.range(at: 0), in: decoded),
                  let numberRange = Range(match.range(at: 1), in: decoded),
                  let scalarValue = UInt32(decoded[numberRange]),
                  let scalar = UnicodeScalar(scalarValue) else {
                continue
            }

            decoded.replaceSubrange(fullRange, with: String(Character(scalar)))
        }

        return decoded
    }

    nonisolated func normalizedFractionsForParsing() -> String {
        var value = self
            .replacingOccurrences(of: "\u{00bc}", with: "1/4")
            .replacingOccurrences(of: "\u{00bd}", with: "1/2")
            .replacingOccurrences(of: "\u{00be}", with: "3/4")
            .replacingOccurrences(of: "\u{2153}", with: "1/3")
            .replacingOccurrences(of: "\u{2154}", with: "2/3")
            .replacingOccurrences(of: "\u{2155}", with: "1/5")
            .replacingOccurrences(of: "\u{2156}", with: "2/5")
            .replacingOccurrences(of: "\u{2157}", with: "3/5")
            .replacingOccurrences(of: "\u{2158}", with: "4/5")
            .replacingOccurrences(of: "\u{2159}", with: "1/6")
            .replacingOccurrences(of: "\u{215a}", with: "5/6")
            .replacingOccurrences(of: "\u{215b}", with: "1/8")
            .replacingOccurrences(of: "\u{215c}", with: "3/8")
            .replacingOccurrences(of: "\u{215d}", with: "5/8")
            .replacingOccurrences(of: "\u{215e}", with: "7/8")

        value = value.replacingOccurrences(
            of: #"(\d)(\d/\d)"#,
            with: "$1 $2",
            options: .regularExpression
        )

        return value
    }

    nonisolated func separatingCompactIngredientUnits(_ units: [String]) -> String {
        var value = self
        let compactUnits = units
            .filter { !$0.contains(" ") }
            .sorted { $0.count > $1.count }
        let amountPattern = #"(?:\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)"#

        for unit in compactUnits {
            let escapedUnit = NSRegularExpression.escapedPattern(for: unit)
            value = value.replacingOccurrences(
                of: #"(?i)(\#(amountPattern))(\#(escapedUnit))\b"#,
                with: "$1 $2",
                options: .regularExpression
            )
        }

        return value
    }

    nonisolated func removingParentheticalNotes() -> String {
        var value = replacingOccurrences(
            of: #"\s*\([^)]*\)"#,
            with: "",
            options: .regularExpression
        )

        if let danglingOpeningParenthesis = value.firstIndex(of: "(") {
            value = String(value[..<danglingOpeningParenthesis])
        }

        return value
            .replacingOccurrences(
                of: #"\s+\)"#,
                with: "",
                options: .regularExpression
            )
            .cleanedIngredientLine
    }

    nonisolated func removingPreparationClause() -> String {
        let commaIndex = firstIndex(of: ",")
        let semicolonIndex = firstIndex(of: ";")
        let earliestIndex = [commaIndex, semicolonIndex]
            .compactMap { $0 }
            .min()

        guard let earliestIndex else { return self }
        return String(self[..<earliestIndex])
    }

    nonisolated func preparationClause() -> String {
        let commaIndex = firstIndex(of: ",")
        let semicolonIndex = firstIndex(of: ";")
        let earliestIndex = [commaIndex, semicolonIndex]
            .compactMap { $0 }
            .min()

        guard let earliestIndex else { return "" }
        return String(self[index(after: earliestIndex)...])
    }

    nonisolated func removingLeadingDescriptors() -> String {
        let descriptorPattern = #"^(?:long-grain|short-grain|medium-grain|finely|roughly|coarsely|thinly|thickly|fresh|freshly|large|small|medium)\s+"#

        var value = self
        while value.range(of: descriptorPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            value = value.replacingOccurrences(
                of: descriptorPattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return value
    }

    nonisolated func removingTrailingDescriptors() -> String {
        replacingOccurrences(
            of: #"\s+(?:optional|for serving)$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    nonisolated var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
