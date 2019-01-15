import UIKit

let articleExpression = try! NSRegularExpression(pattern:
    "(?:A|An|The)\\s+",
                                                 options: [])

fileprivate func removeArticle(from: String) -> String {
    let fromRange = NSRange(from.startIndex..., in: from)
    let checkingResult = articleExpression.matches(in: from, options: [], range: fromRange)
    if checkingResult.isEmpty { return from }
    let range = checkingResult[0].range(at: 0)
    let startIndex = from.index(from.startIndex, offsetBy: range.location)
    let endIndex = from.index(startIndex, offsetBy: range.length)
    return String(from[endIndex...])
}

removeArticle(from: "Ann      x")
