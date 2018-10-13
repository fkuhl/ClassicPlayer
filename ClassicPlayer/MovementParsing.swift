//
//  MovementParsing.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 7/21/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import Foundation
import MediaPlayer

//https://developer.apple.com/documentation/foundation/nsregularexpression?changes=_9

fileprivate let nonCapturingParen = "(?:"
fileprivate let space = " "
fileprivate let dash = "-"
fileprivate let whitespaceZeroOrMore = "\\s*"
fileprivate let whitespaceOneOrMore = "\\s+"
fileprivate let upToColon = "[^:]+"
fileprivate let upToDash = "[^-]+"
fileprivate let upToParen = "[^\\)]+"
fileprivate let upToDashOrColon = "[^-:]+"
fileprivate let anythingOneOrMore = ".+"
fileprivate let anythingZeroOrMore = ".*"
fileprivate let movementNumber = "[0-9]+"
fileprivate let period = "\\."
fileprivate let periodSpace = period + space
fileprivate let dashOrPeriod = nonCapturingParen + period + space + "|" + dash + ")"
fileprivate let romanNumber =
    nonCapturingParen + "I|II|III|IV|V|VI|VII|VIII|IX|X|XI|XII|XIII|XIV|XV|XVI|XVII|XVIII|XIX|XX" + ")"
fileprivate let colonOneOrMoreSpaces = ": +"
fileprivate let spaceDash = " -"
fileprivate let literalOpenParen = "\\("
fileprivate let literalCloseParen = "\\)"

fileprivate let composerColonWork = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        upToColon +
        ":" +
        whitespaceZeroOrMore +
        "(" + anythingOneOrMore + ")",
                                                             options: [])

fileprivate let work = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        "(" + anythingOneOrMore + ")",
                                                             options: [])

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

fileprivate let workDashMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        "(" + upToDash + ")" +
        nonCapturingParen + spaceDash + whitespaceOneOrMore + ")" +
        "(" + anythingZeroOrMore + ")",
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

fileprivate let  workNrMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        "(" + upToDash + ")" +
        whitespaceOneOrMore +
        "(" + movementNumber + period + space + anythingOneOrMore + ")",
                                                           options: [])

//need an example of this. Boccherini Cello Ctos, Adams: Century Rolls don't have composer
fileprivate let composerColonWorkRomMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        upToColon +
        ":" +
        whitespaceZeroOrMore +
        "(" + upToDash + ")" +
        whitespaceOneOrMore +
        "(" + romanNumber + dashOrPeriod + anythingOneOrMore + ")",
                                                                        options: [])

fileprivate let workRomMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        "(" + upToDash + ")" +
        whitespaceOneOrMore +
        "(" + romanNumber + dashOrPeriod + anythingOneOrMore + ")",
                                                           options: [])

fileprivate let composerColonWorkColonMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        upToColon +
        ":" +
        whitespaceZeroOrMore +
        "(" + upToColon + ")" +
        nonCapturingParen + colonOneOrMoreSpaces + ")" +
        "(" + anythingZeroOrMore + ")",
                                                                        options: [])

fileprivate let workColonMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        "(" + upToColon + ")" +
        nonCapturingParen + colonOneOrMoreSpaces + ")" +
        "(" + anythingZeroOrMore + ")",
                                                             options: [])

fileprivate let composerColonWorkParenMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        upToColon +
        ":" +
        whitespaceZeroOrMore +
        "(" + upToDash + ")" +
        whitespaceZeroOrMore +
        literalOpenParen +
        "(" + upToParen + ")" +
    literalCloseParen,
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
struct PatternEntry: Equatable {
    let pattern: NSRegularExpression
    let name: String
}

fileprivate let composerCheckSet = [ PatternEntry(pattern: workColonMovement, name: "composerCheck") ]
fileprivate let workEntry = PatternEntry(pattern: work, name: "work")

/**
 The set of r.e. patterns used to find pieces and movements.
 These are listed in order of decreasing desirability.
 */
fileprivate let composerPatterns = [
    PatternEntry(pattern: composerColonWorkRomMovement, name: "composerColonWorkRomMovement"),
    PatternEntry(pattern: composerColonWorkNrMovement, name: "composerColonWorkNrMovement"),
    PatternEntry(pattern: composerColonWorkDashMovement, name: "composerColonWorkDashMovement"),
    PatternEntry(pattern: composerColonWorkColonMovement, name: "composerColonWorkColonMovement"),
    PatternEntry(pattern: composerColonWorkParenMovement, name: "composerColonWorkParenMovement"),
    PatternEntry(pattern: composerColonWork, name: "composerColonWork"),
]

fileprivate let noComposerPatterns = [
    PatternEntry(pattern: workRomMovement, name: "workRomMovement"),
    PatternEntry(pattern: workNrMovement, name: "workNrMovement"),
    PatternEntry(pattern: workDashMovement, name: "workDashMovement"),
    PatternEntry(pattern: workColonMovement, name: "workColonMovement"),
    PatternEntry(pattern: workParenMovement, name: "workParenMovement"),
]

fileprivate let separator: Character = "|"
fileprivate let parseTemplate = "$1\(separator)$2"

fileprivate var composersFound = Set<String>()

struct ParseResult: Equatable {
    let firstMatch: String
    let secondMatch: String
    let parse: PatternEntry
    
    static let undefined = ParseResult(firstMatch: "", secondMatch: "", parse: workEntry)
}

/**
 Find the best parse of song title into work title and piece title.
 "Best" is defined as "most desirable." NOTE: We tried, in pursuit of
 efficiency, just finding a colon rather than applying the composerCheckSet,
 but that doesn't deal with whitespace properly.
 
 - Parameter in: unparsed song title
 
 - Returns: ParseResult. Always returns something, even if no match.
 */
func bestParse(in raw: String) -> ParseResult {
    if let composerCheck = apply(patternSet: composerCheckSet, to: raw) {
        if composersContains(candidate: composerCheck.firstMatch) {
            if let result = apply(patternSet: composerPatterns, to: raw) {
                return result  //some composer pattern matched
            }
        }
    }
    if let result = apply(patternSet: noComposerPatterns, to: raw) {
        return result  //some no-composer pattern matched
    }
    return ParseResult(firstMatch: raw.trimmingCharacters(in: .whitespacesAndNewlines),
                       secondMatch: "",
                       parse: workEntry)
}

/**
 Return the best parse, if any, from the set of patterns.
 Assume pattern set is ordered most to least desirable: return first match.
 
 - Parameter patternSet: Array of PatternEntry's to apply
 - Parameter to: unparsed song title
 
 - Returns: best ParseResult, if there is a match; otherwise, nil
 */
fileprivate func apply(patternSet: [PatternEntry], to raw: String) -> ParseResult? {
    let rawRange = NSRange(raw.startIndex..., in: raw)
    for pattern in patternSet {
        let checkingResult = pattern.pattern.matches(in: raw, options: [], range: rawRange)
        if checkingResult.isEmpty { continue }
        if checkingResult.count != 1 {
            //How do you get more than one match?
            NSLog("Match of raw '\(raw)' with pattern \(pattern.name) produced \(checkingResult.count) ranges!")
            return nil
        }
        if checkingResult[0].numberOfRanges < 1 {
            //not sure how you get a match and no ranges
            NSLog("Match of raw '\(raw)' with pattern \(pattern.name) but no ranges!")
            continue
        }
        //First range found is entire string; second is first match
        let firstComponent = extract(from: raw, range: checkingResult[0].range(at: 1))
        let secondComponent: String
        if checkingResult[0].numberOfRanges > 2 {
           secondComponent = extract(from: raw, range: checkingResult[0].range(at: 2))
        } else {
            secondComponent = ""
        }
        return ParseResult(firstMatch: firstComponent, secondMatch: secondComponent, parse: pattern)
    }
    return nil
}

/**
 Given the parse of the first movement, see if that parse works for a subsequent movement.
 
 - Parameter raw: unparsed song title
 - Parameter against: parse of first movement title

 - Returns: ParseResult, if it parses the same way; nil otherwise.
 */
func matchSubsequentMovement(raw: String, against: ParseResult) -> ParseResult? {
    let rawRange = NSRange(raw.startIndex..., in: raw)
    let checkingResult = against.parse.pattern.matches(in: raw, options: [], range: rawRange)
    if checkingResult.isEmpty { return nil }
    if checkingResult.count != 1 {
        print("match returned \(checkingResult.count) results--bizarre!")
        return nil
    }
    if checkingResult[0].numberOfRanges < 1 { return nil }
    //First range found is entire string; second is first match
    let firstComponent = extract(from: raw, range: checkingResult[0].range(at: 1))
    if  firstComponent == against.firstMatch {
        if checkingResult[0].numberOfRanges > 2 {
            //There was a match on second range (third in checkingResult); that's the movement title.
            let secondComponent = extract(from: raw, range: checkingResult[0].range(at: 2))
            return ParseResult(firstMatch: against.firstMatch, secondMatch: secondComponent, parse: against.parse)
        } else if checkingResult[0].numberOfRanges > 1 {
            //No match of movement title.
            return ParseResult(firstMatch: against.firstMatch, secondMatch: "", parse: against.parse)
        }
    }
    return nil
}

fileprivate func extract(from: String, range: NSRange) -> String {
    //Create string indices (UTF-8, recall) from the range
    let startIndex = from.index(from.startIndex, offsetBy: range.location)
    let endIndex = from.index(startIndex, offsetBy: range.length)
    return String(from[startIndex..<endIndex])
}

/**
 Find and store all the composers that occur in songs. Called from AppDelegate.

 */
func findComposers() {
    composersFound = Set<String>()
    let mediaAlbums = MPMediaQuery.albums()
    if mediaAlbums.collections == nil { return }
    for mediaAlbum in mediaAlbums.collections! {
        let mediaAlbumItems = mediaAlbum.items
        for item in mediaAlbumItems {
            if let composer = item.composer {
                composersFound.insert(composer)
            }
        }
    }
}

/**
 Does the set of previously found composers contain this (possibly partial) composer name?
 
 - Parameter candidate: composer name from song title, e.g., "Brahms"
 
 - Returns: true if the candidate appears somewhere in one of the stored composers, e.g., "Brahms, Johannes".
 */
fileprivate func composersContains(candidate: String) -> Bool {
    for composer in composersFound {
        if composer.range(of: candidate, options: String.CompareOptions.caseInsensitive) != nil { return true }
    }
    return false
}

