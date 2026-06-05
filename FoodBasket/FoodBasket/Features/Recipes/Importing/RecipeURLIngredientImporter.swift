//
//  RecipeURLIngredientImporter.swift
//  Food Basket
//
//  Created by Codex on 5/6/2026.
//

import Foundation

struct ImportedRecipeIngredients: Equatable, Sendable {
    let sourceURL: URL
    let title: String?
    let ingredientLines: [String]
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
            ingredientLines: ingredientLines
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
            ingredientLines: ingredientLines
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
            .trimmingCharacters(in: CharacterSet(charactersIn: "-*• "))
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
}
