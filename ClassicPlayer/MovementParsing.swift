//
//  MovementParsing.swift
//  ClassicPlayer
//
//  Created by Frederick Kuhl on 7/21/18.
//  Copyright © 2018 TyndaleSoft LLC. All rights reserved.
//

import Foundation

/**
 Everything associated with parsing pieces and movements.
 This is used by ClassicPrinter as well as ClassicPlayer, so it imports
 nothing not common to iOS and macOS.
 */

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
fileprivate let anythingOneOrMoreWithDashes = ".+" + nonCapturingParen + "-" + ".+" + ")+"
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

//Chopin: Piano Sonata #2 In B Flat Minor, Op. 35, B 128, "Funeral March" - 1. Grave
fileprivate let composerColonWorkNrMovement = try! NSRegularExpression(pattern:
        whitespaceZeroOrMore +
        upToColon +
        ":" +
        whitespaceZeroOrMore +
        "(" + upToDash + ")" +  //see Bach Concertos
        whitespaceOneOrMore + //slight change from earlier, which allowed only string of spaces here, not whitespace
        "(" + movementNumber + period + space + anythingOneOrMore + ")",
                                                                       options: [])

//BWV 249 Easter Oratorio - 4. Rec. (C, S, T, B): O Kalter Mánner Sinn
fileprivate let  workNrMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        "(" + upToDash + ")" +
        whitespaceOneOrMore +
        "(" + movementNumber + period + space + anythingOneOrMore + ")",
                                                           options: [])

//Brahms: Clarinet Sonata No. 2 in E-Flat Major, Op. 120: II. Appassionato; Ma non troppo allegro
fileprivate let composerColonWorkRomMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        upToColon +
        ":" +
        whitespaceZeroOrMore +
        "(" + upToDash + ")" +
        whitespaceOneOrMore +
        "(" + romanNumber + dashOrPeriod + anythingOneOrMore + ")",
                                                                        options: [])

//Boccherini
//Cello concerto #1, G 474. I-Allegro moderato
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

//Boccherini
//Quintetto No. 4 In Re Maggiore "Fandango" Per Corda e Chitarra (G. 448): Pastorale
fileprivate let workColonMovement = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        "(" + upToColon + ")" +
        nonCapturingParen + colonOneOrMoreSpaces + ")" +
        "(" + anythingZeroOrMore + ")",
                                                             options: [])

fileprivate let composerColonWorkColonMovementIncludingDashes = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        upToColon +
        ":" +
        whitespaceZeroOrMore +
        "(" + upToColon + ")" +
        nonCapturingParen + colonOneOrMoreSpaces + ")" +
        "(" + anythingOneOrMoreWithDashes + ")",
                                                                          options: [])

//Corelli
//No. 1 in D: Largo - Allegro - Largo - Allegro
fileprivate let workColonMovementIncludingDashes = try! NSRegularExpression(pattern:
    whitespaceZeroOrMore +
        "(" + upToColon + ")" +
        nonCapturingParen + colonOneOrMoreSpaces + ")" +
        "(" + anythingOneOrMoreWithDashes + ")",
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
    let allowedSubsequentPatterns: [NSRegularExpression]
}

fileprivate let composerCheckSet = [ PatternEntry(pattern: workColonMovement, name: "composerCheck", allowedSubsequentPatterns: []) ]
fileprivate let workEntry = PatternEntry(pattern: work, name: "work", allowedSubsequentPatterns: [])

/**
 The set of r.e. patterns used to find pieces and movements.
 These are listed in order of decreasing desirability.
 */
fileprivate let composerPatterns = [
    PatternEntry(pattern: composerColonWorkRomMovement, name: "composerColonWorkRomMovement",
                 allowedSubsequentPatterns: [composerColonWorkRomMovement]),
    PatternEntry(pattern: composerColonWorkNrMovement, name: "composerColonWorkNrMovement",
                 allowedSubsequentPatterns: [composerColonWorkNrMovement]),
    PatternEntry(pattern: composerColonWorkColonMovementIncludingDashes, name: "composerColonWorkColonMovementIncludingDashes",
                 allowedSubsequentPatterns: [composerColonWorkColonMovement, composerColonWorkColonMovementIncludingDashes]),
    PatternEntry(pattern: composerColonWorkDashMovement, name: "composerColonWorkDashMovement",
                 allowedSubsequentPatterns: [composerColonWorkDashMovement]),
    PatternEntry(pattern: composerColonWorkColonMovement, name: "composerColonWorkColonMovement",
                 allowedSubsequentPatterns: [composerColonWorkColonMovement, composerColonWorkColonMovementIncludingDashes]),
    PatternEntry(pattern: composerColonWorkParenMovement, name: "composerColonWorkParenMovement",
                 allowedSubsequentPatterns: [composerColonWorkParenMovement]),
    PatternEntry(pattern: composerColonWork, name: "composerColonWork",
                 allowedSubsequentPatterns: [composerColonWork]),
]

/*
 If dash comes before colon, then this parses correctly:
 BWV 10 Cantata "Meine Seel Erhebt Den Herren" - 1. Chor: Meine Seel Erhebt Den Herren
 and this:
 No. 1 in D: Largo - Allegro - Largo - Allegro
 is parsed picked up by the "including dashes" patterns.
 */

fileprivate let noComposerPatterns = [
    PatternEntry(pattern: workRomMovement, name: "workRomMovement",
                 allowedSubsequentPatterns: [workRomMovement]),
    PatternEntry(pattern: workNrMovement, name: "workNrMovement",
                 allowedSubsequentPatterns: [workNrMovement]),
//    Corelli
//    No. 2 in F: Vivace - Allegro - Adagio - Vivace - Allegro - Largo andante
//    No. 2 in F: Allegro
//    No. 2 in F: Grave - Andante largo - Allegro
    PatternEntry(pattern: workColonMovementIncludingDashes, name: "workColonMovementIncludingDashes",
                 allowedSubsequentPatterns: [workColonMovement, workColonMovementIncludingDashes]),
    PatternEntry(pattern: workDashMovement, name: "workDashMovement",
                 allowedSubsequentPatterns: [workDashMovement]),
    PatternEntry(pattern: workColonMovement, name: "workColonMovement",
                 allowedSubsequentPatterns: [workColonMovement, workColonMovementIncludingDashes]),
    PatternEntry(pattern: workParenMovement, name: "workParenMovement",
                 allowedSubsequentPatterns: [workParenMovement]),
]

fileprivate let separator: Character = "|"
fileprivate let parseTemplate = "$1\(separator)$2"

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
    for pattern in patternSet {
        if let result = apply(expression: pattern.pattern, to: raw) {
            return ParseResult(firstMatch: result.firstMatch, secondMatch: result.secondMatch, parse: pattern)
        }
    }
    return nil
}

fileprivate func apply(expression: NSRegularExpression, to raw: String) -> (firstMatch: String, secondMatch: String)? {
    let rawRange = NSRange(raw.startIndex..., in: raw)
    let checkingResult = expression.matches(in: raw, options: [], range: rawRange)
    if checkingResult.isEmpty { return nil }
    if checkingResult.count != 1 {
        //How do you get more than one match?
        NSLog("Match of raw '\(raw)' with pattern \(expression) produced \(checkingResult.count) ranges!")
        return nil
    }
    if checkingResult[0].numberOfRanges < 1 {
        //not sure how you get a match and no ranges
        NSLog("Match of raw '\(raw)' with pattern \(expression) but no ranges!")
        return nil
    }
    //First range found is entire string; second is first match
    let firstComponent = extract(from: raw, range: checkingResult[0].range(at: 1))
    let secondComponent: String
    if checkingResult[0].numberOfRanges > 2 {
        secondComponent = extract(from: raw, range: checkingResult[0].range(at: 2))
    } else {
        secondComponent = ""
    }
    return (firstMatch: firstComponent, secondMatch: secondComponent)
}

/**
 Given the parse of the first movement, see if any of the allowed subsequent parses work for a subsequent movement.
 Require that the parse of the subsequent title return the same piece name.
 
 - Parameter raw: unparsed song title
 - Parameter against: parse of first movement title

 - Returns: ParseResult, if it parses the same way; nil otherwise.
 */
func matchSubsequentMovement(raw: String, against: ParseResult) -> ParseResult? {
    for pattern in against.parse.allowedSubsequentPatterns {
        if let result = apply(expression: pattern, to: raw) {
            if against.firstMatch == result.firstMatch {
                return ParseResult(firstMatch: result.firstMatch, secondMatch: result.secondMatch, parse: against.parse)
            }
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

private enum ParsingState {
    case beginPiece
    case continuePiece
}

/**
 Take the track titles from an album and find pieces and movements.
 The rationale for this function is that it abstracts the parsing away from the details
 of the media library, so the same parsing can be applied to track titles reported by a user.
 
 - Parameter titles: unparsed track titles in the order they appear in the album
 - Parameter recordPiece: function to call when a piece has been found
 - Parameter collectionIndex: index of the first track in the piece
 - Parameter pieceTitle: title parsed for piece
 - Parameter parseResult: the parse that yielded this piece
 - Parameter recordMovement: function to call when a movement has been found in a piece
 - Parameter collectionIndex: track index of this movement
 - Parameter pieceTitle: title parsed for movement
 - Parameter parseResult: the parse that yielded this movement

 */
func parsePieces(from titles: [String],
                 recordPiece: (_ collectionIndex: Int, _ pieceTitle: String, _ parseResult: ParseResult) -> (),
                 recordMovement: (_ collectionIndex: Int, _ movementTitle: String, _ parseResult: ParseResult) -> ()) {
    if titles.count < 1 { return }
    var state = ParsingState.beginPiece
    var i = 0
    var firstParse = ParseResult.undefined //compiler needs a default value
    var nextParse: ParseResult?
    repeat {
        let unwrappedTitle = titles[i]
        switch state {
        case .beginPiece:
            firstParse = bestParse(in: unwrappedTitle)
            if i + 1 >= titles.count {
                //no more songs to be movements
                //so piece name is the track name
                recordPiece(i, firstParse.firstMatch, firstParse)
                i += 1
                continue
            }
            let secondTitle = titles[i + 1]
            nextParse = matchSubsequentMovement(raw: secondTitle, against: firstParse)
            if let matchedNext = nextParse {
                //at least two movements: record piece, then first two movements
                recordPiece(i, firstParse.firstMatch, firstParse)
                recordMovement(i,     firstParse.secondMatch,  matchedNext)
                recordMovement(i + 1, matchedNext.secondMatch, matchedNext)
                //see what other movement(s) you can find
                i += 2
                state = .continuePiece
            } else {
                //next is different piece
                //so piece name is what we found at first
                recordPiece(i, firstParse.firstMatch, firstParse)
                i += 1
                state = .beginPiece
            }
        case .continuePiece:
            if i >= titles.count { continue }
            let subsequentTitle = titles[i]
            let subsequentParse = matchSubsequentMovement(raw: subsequentTitle, against: firstParse)
            if let matchedSubsequent = subsequentParse {
                recordMovement(i, matchedSubsequent.secondMatch, matchedSubsequent)
                i += 1
            } else {
                state = .beginPiece //don't increment i
            }
        }
    } while i < titles.count
}
