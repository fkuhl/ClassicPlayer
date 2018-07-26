//
//  MovementParsing.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 7/21/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import Foundation

//https://developer.apple.com/documentation/foundation/nsregularexpression?changes=_9

fileprivate let whitespaceZeroOrMore = "\\s*"
fileprivate let whitespaceOneOrMore = "\\s+"
fileprivate let upToColon = "[^:]+"
fileprivate let upToDash = "[^-]+"
fileprivate let upToParen = "[^\\)]+"
fileprivate let upToDashOrColon = "[^-:]+"
fileprivate let anythingOneOrMore = ".+"
fileprivate let anythingZeroOrMore = ".*"
fileprivate let movementNumber = "[1-9][0-9]*"
fileprivate let period = "\\."
fileprivate let space = " "
fileprivate let nonCapturingParen = "(?:"
fileprivate let romanNumber =
    nonCapturingParen + "I|II|III|IV|V|VI|VII|VIII|IX|X|XI|XII|XIII|XIV|XV|XVI|XVII|XVIII|XIX|XX" + ")"
fileprivate let colonOneOrMoreSpaces = ": +"
fileprivate let spaceDash = " -"
fileprivate let capitalizedAlpha = "[A-Z][a-z]+"  //accented chars?
fileprivate let literalOpenParen = "\\("
fileprivate let literalCloseParen = "\\)"

fileprivate let composerColonWorkDashMovement = try! NSRegularExpression(pattern:
        whitespaceZeroOrMore +
        upToColon +
        ":" +
        whitespaceZeroOrMore +
        "(" + upToDash + ")" +
        " -" +
        whitespaceOneOrMore +
        "(" + anythingOneOrMore + ")",
                                                                         options: [])

//Chopin: Piano Sonatas, Bruckner: Symphony #9
fileprivate let composerColonWorkNrMovement = try! NSRegularExpression(pattern:
        whitespaceZeroOrMore +
        upToColon +
        ":" +
        whitespaceZeroOrMore +
        "(" + upToDash + ")" +  //see Bach Concertos
        whitespaceOneOrMore + //slight change from earlier, which allowed only string of spaces here, not whitespace
        "(" + movementNumber + period + space + anythingOneOrMore + ")",
                                                                       options: [])

//need an example of this. Boccherini Cello Ctos, Adams: Century Rolls don't have composer
fileprivate let composerColonWorkRomMovement = try! NSRegularExpression(pattern:
    capitalizedAlpha +
    ":" +
    whitespaceZeroOrMore +
    "(" + upToDash + ")" +
    whitespaceOneOrMore +
    "(" + romanNumber + period + space + anythingOneOrMore + ")",
                                                                        options: [])

fileprivate let workColonDashMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
    "(" + upToDashOrColon + ")" +
    nonCapturingParen + colonOneOrMoreSpaces + "|" + spaceDash + whitespaceOneOrMore + ")" +
    "(" + anythingZeroOrMore + ")",
                                                                 options: [])

fileprivate let  workNrMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
    "(" + upToDash + ")" +
    whitespaceOneOrMore +
    "(" + movementNumber + period + space + anythingOneOrMore + ")",
                                                           options: [])

fileprivate let workRomMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
    "(" + upToDash + ")" +
    whitespaceOneOrMore +
    "(" + romanNumber + period + space + anythingOneOrMore + ")",
                                                           options: [])

fileprivate let workParenMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
    "(" + upToDash + ")" +
    whitespaceZeroOrMore +
    literalOpenParen +
    "(" + upToParen + ")" +
    literalCloseParen,
                                                             options: [])
/**
 The entry for a r.e. pattern used to find pieces and movements.
 */
struct PatternEntry {
    let pattern: NSRegularExpression
    let name: String
}

/**
 The set of r.e. patterns used to find pieces and movements.
 */
let patterns = [
    PatternEntry(pattern: composerColonWorkDashMovement, name: "composerColonWorkDashMovement"),
    PatternEntry(pattern: composerColonWorkNrMovement, name: "composerColonWorkNrMovement"),
    PatternEntry(pattern: composerColonWorkRomMovement, name: "composerColonWorkRomMovement"),
    PatternEntry(pattern: workColonDashMovement, name: "workColonDashMovement"),
    PatternEntry(pattern: workNrMovement, name: "workNrMovement"),
    PatternEntry(pattern: workRomMovement, name: "workRomMovement"),
    PatternEntry(pattern: workParenMovement, name: "workParenMovement")
]

fileprivate let separator: Character = "|"
fileprivate let parseTemplate = "$1\(separator)$2"

struct ParseResult: Equatable {
    let pieceTitle: String
    let movementTitle: String
}

/**
 Find all successful parses of song title into work title and piece title.
 
 - Parameters:
    - in: unparsed song title
 
 - Returns:
 Array, possibly empty, of successful parse results
 */
func findParses(in raw: String) -> [ParseResult] {
    var result = [ParseResult]()
    //I re-wrote this using map and filter, and it was less clear.
    for pattern in patterns {
        let transformed = pattern.pattern.stringByReplacingMatches(
            in: raw,
            options: [],
            range: NSRange(raw.startIndex..., in: raw),
            withTemplate: parseTemplate)
        let components = transformed.split(separator: separator, maxSplits: 6, omittingEmptySubsequences: false)
        if components.count == 2 {
            result.append(ParseResult(pieceTitle: String(components[0]), movementTitle: String(components[1])))
        }
    }
    return result
}

// TODO: When looking for a second movement for a piece, compare each parse of 1st song title against each
// parsed piece title of second song title. When you find a match of titles, declare a match.
// (Or do we accumulate all such matches and prefer, e.g., the longest?)
// That becomes the definitive piece title.

// TODO: When comparing subsequent song titles, look for a match with piece title.
