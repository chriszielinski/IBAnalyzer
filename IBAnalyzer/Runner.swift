//
//  Runner.swift
//  IBAnalyzer
//
//  Created by Arkadiusz Holko on 29/01/2017.
//  Copyright © 2017 Arkadiusz Holko. All rights reserved.
//

import Foundation
import SourceKittenFramework

public class Runner {
    let path: String
    let directoryEnumerator: DirectoryContentsEnumeratorType
    let nibParser: NibParserType
    let swiftParser: SwiftParserType
    let fileManager: FileManager

    public init(path: String,
         directoryEnumerator: DirectoryContentsEnumeratorType = DirectoryContentsEnumerator(),
         nibParser: NibParserType = NibParser(),
         swiftParser: SwiftParserType = SwiftParser(),
         fileManager: FileManager = FileManager()) {
        self.path = path
        self.directoryEnumerator = directoryEnumerator
        self.nibParser = nibParser
        self.swiftParser = swiftParser
        self.fileManager = fileManager
    }

    public func issues(using analyzers: [Analyzer], additionalClassData: Data? = nil) throws -> [Issue] {
        var classNameToNibMap: [String: Nib] = [:]
        var classNameToClassMap: [String: Class] = [:]

        for url in try nibFiles() {
            let connections = try nibParser.mappingForFile(at: url)
            for (key, value) in connections {
                classNameToNibMap[key] = value
            }
        }

        for url in try swiftFiles() {
            try swiftParser.mappingForFile(at: url, result: &classNameToClassMap)
        }

        var allSegueDeclarations: [SegueDeclaration] = classNameToNibMap.values.reduce(into: []) { $0.append(contentsOf: $1.segues) }
        allSegueDeclarations.forEach({ $0.resolveFile(classNameToClassMap: classNameToClassMap) })

        if let data = additionalClassData, let classNameToSegueIdentifiers = try? JSONDecoder().decode([String: [SegueIdentifier]].self, from: data) {
            for (className, identifiers) in classNameToSegueIdentifiers {
                if classNameToClassMap[className] != nil {
                    classNameToClassMap[className]!.segueIdentifiers.append(contentsOf: identifiers)
                } else {
                    let classObject = Class(outlets: [], actions: [], inherited: [], segueIdentifiers: identifiers)
                    classNameToClassMap[className] = classObject
                }
            }
        }

        let configuration = AnalyzerConfiguration(classNameToNibMap: classNameToNibMap,
                                                  classNameToClassMap: classNameToClassMap,
                                                  uiKitClassNameToClassMap: uiKitClassNameToClass(),
                                                  allNibSegues: (nibParser as? NibParser)?.allSegues ?? [])

        return analyzers.flatMap { $0.issues(for: configuration) }
    }

    func nibFiles() throws -> [URL] {
        return try files().filter { $0.pathExtension == "storyboard" || $0.pathExtension == "xib"}
    }

    func swiftFiles() throws -> [URL] {
        return try files().filter { $0.pathExtension == "swift" }
    }

    fileprivate func files() throws -> [URL] {
        let url = URL(fileURLWithPath: path)
        return try directoryEnumerator.files(at: url, fileManager: fileManager)
    }
}
