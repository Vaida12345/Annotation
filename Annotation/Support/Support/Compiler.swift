//
//  Compiler.swift
//  clt
//
//  Created by Vaida on 1/1/22.
//

import Foundation

struct Compiler {
    
    static func convertForToWhile(from content: String, offset: Int = 0, isStringIndex: Bool = false) {
        guard !content.contains("\n") else { print("failed: please only enter for-in line"); return }
        guard content.contains("for") && content.contains("in") && content.contains("{") && content.firstIndex(of: "for")!.upperBound < content.firstIndex(of: "in")!.lowerBound else { print("failed"); return }
        var item = content[content.firstIndex(of: "for")!.upperBound ..< content.firstIndex(of: "in")!.lowerBound].replacingOccurrences(of: " ", with: "")
        if item == "_" {
            item = "index"
        }
        var main = ""
        
        if content.contains("..") {
            let preCount = content[content.firstIndex(of: "in")!.upperBound..<content.firstIndex(of: "..")!.lowerBound].replacingOccurrences(of: " ", with: "")
            if let preCount = Int(preCount) {
                main = "var \(item) = \(preCount - 1)\n"
            } else {
                main = "var \(item) = \(preCount) - 1\n"
            }
            if content.contains("...") {
                let laterCount = content[content.firstIndex(of: "...")!.upperBound..<content.firstIndex(of: "{")!].replacingOccurrences(of: " ", with: "")
                main += "while \(item) + 1 <= \(laterCount) {\n"
            } else if content.contains("..<") {
                let laterCount = content[content.firstIndex(of: "..<")!.upperBound..<content.firstIndex(of: "{")!].replacingOccurrences(of: " ", with: "")
                main += "while \(item) + 1 < \(laterCount) {\n"
            }
            main += "\t\(item) += 1\n"
        } else {
            var value : String {
                if offset == 0 {
                    return "index"
                } else {
                    return "index\(offset + 1)"
                }
            }
            main = "var \(value) = -1\n"
            let count = content[content.firstIndex(of: "in")!.upperBound..<content.firstIndex(of: "{")!].replacingOccurrences(of: " ", with: "")
            if content.contains("<=") {
                main += "while \(value) + 1 <= \(count).count {\n"
            } else {
                main += "while \(value) + 1 < \(count).count {\n"
            }
            main += "\t\(value) += 1\n"
            if isStringIndex {
                main += "\tlet \(item) = \(count)[\(count).index(\(count).startIndex, offsetBy: \(value))]\n"
            } else {
                main += "\tlet \(item) = \(count)[\(value)]\n"
            }
        }
        
        print(main)
    }
    
}

