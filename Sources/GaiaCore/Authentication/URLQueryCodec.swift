import Foundation

public enum URLQueryCodec {
  public static func queryItems(fromPercentEncodedQuery query: String) -> [URLQueryItem] {
    guard !query.isEmpty else {
      return []
    }

    var components = URLComponents()
    // Keep historical form-style behavior where '+' represents a space.
    components.percentEncodedQuery = query.replacingOccurrences(of: "+", with: "%20")
    return components.queryItems ?? []
  }

  public static func queryDictionary(fromPercentEncodedQuery query: String) -> [String: String] {
    var result: [String: String] = [:]
    for item in queryItems(fromPercentEncodedQuery: query) {
      guard !item.name.isEmpty else {
        continue
      }
      result[item.name] = item.value ?? ""
    }
    return result
  }
}
