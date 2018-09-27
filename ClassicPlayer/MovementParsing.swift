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
fileprivate struct PatternEntry {
    let pattern: NSRegularExpression
    let name: String
}

fileprivate let composerCheckSet = [ PatternEntry(pattern: workColonMovement, name: "composerCheck") ]

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
    let parseName: String
}

/**
 Find the best parse of song title into work title and piece title.
 "Best" is defined as "most desirable."
 
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
    return ParseResult(firstMatch: raw, secondMatch: "", parseName: "no match")
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
        let matchCount = pattern.pattern.numberOfMatches(
            in: raw,
            options: [],
            range: rawRange)
        if  matchCount == 1 {
            let transformed = pattern.pattern.stringByReplacingMatches(
                in: raw,
                options: [],
                range: rawRange,
                withTemplate: parseTemplate)
            let components = transformed.split(separator: separator, maxSplits: 6, omittingEmptySubsequences: false)
            return ParseResult(firstMatch: String(components[0]), secondMatch: String(components[1]), parseName: pattern.name)
        }
    }
    return nil
}

/**
 Given the parse of the first movement, find a matching parse of a subsequent movement.
 
 - Parameter raw: unparsed song title
 - Parameter against: parse of first movement title

 - Returns: ParseResult, if there is a parse; nil otherwise.
 */
func matchSubsequentMovement(raw: String, against: ParseResult) -> ParseResult? {
    let rawRange = NSRange(raw.startIndex..., in: raw)
    for pattern in composerPatterns + noComposerPatterns {
        let matchCount = pattern.pattern.numberOfMatches(
            in: raw,
            options: [],
            range: rawRange)
        if  matchCount == 1 {
            let transformed = pattern.pattern.stringByReplacingMatches(
                in: raw,
                options: [],
                range: rawRange,
                withTemplate: parseTemplate)
            let components = transformed.split(separator: separator, maxSplits: 6, omittingEmptySubsequences: false)
            if String(components[0]) == against.firstMatch {
                return ParseResult(firstMatch: against.firstMatch, secondMatch: String(components[1]), parseName: pattern.name)
            }
        }
    }
    return nil
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

