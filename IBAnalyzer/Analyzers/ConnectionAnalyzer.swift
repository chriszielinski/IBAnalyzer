//
//  ConnectionAnalyzer.swift
//  IBAnalyzer
//
//  Created by Arkadiusz Holko on 14/01/2017.
//  Copyright © 2017 Arkadiusz Holko. All rights reserved.
//

import Foundation
import SourceKittenFramework

class Declaration {
    var name: String
    var line: Int
    var column: Int
    var url: URL?
    var isOptional: Bool
    var parentClass: String?
    var parentClassPath: String?

    init(name: String, line: Int, column: Int, url: URL? = nil, isOptional: Bool = false, customClass: String? = nil) {
        self.name = name
        self.line = line
        self.column = column
        self.url = url
        self.isOptional = isOptional
        self.parentClass = customClass
    }

    convenience init(name: String, file: File, offset: Int64, isOptional: Bool = false) {
        let fileOffset = type(of: self).getLineColumnNumber(of: file, offset: Int(offset))
        var url: URL?
        if let path = file.path {
            url = URL(fileURLWithPath: path)
        }
        self.init(name: name, line: fileOffset.line, column: fileOffset.column, url: url, isOptional: isOptional)
    }

    var description: String {
        return "\(parentClassPath ?? filePath):\(line):\(column)"
    }

    var filePath: String {
        if let path = url?.absoluteString {
            return path.replacingOccurrences(of: "file://", with: "").replacingOccurrences(of: "%20", with: " ")
        }
        return name.replacingOccurrences(of: ":", with: "")
    }

    func fileName(className: String) -> String {
        if let filename = url?.lastPathComponent {
            return filename
        }
        return className
    }

    private static func getLineColumnNumber(of file: File, offset: Int) -> (line: Int, column: Int) {
        let range = file.contents.startIndex..<file.contents.index(file.contents.startIndex, offsetBy: offset)
        let subString = file.contents[range]
        let lines = subString.components(separatedBy: "\n")

        if let column = lines.last?.count {
            return (line: lines.count, column: column)
        }
        return (line: lines.count, column: 0)
    }
}

extension Declaration: Equatable {
    public static func == (lhs: Declaration, rhs: Declaration) -> Bool {
        return lhs.name == rhs.name
    }
}

class DeclarationNode {
    var name: String
    var line: Int
    var column: Int
    var url: URL?
    var isOptional: Bool
    var parentClass: String?
    var parentClassPath: String?

    init(name: String, line: Int, column: Int, url: URL?, isOptional: Bool) {
        self.name = name
        self.line = line
        self.column = column
        self.url = url
        self.isOptional = isOptional
    }
}

protocol ImplicitlyUnwrappedOptionalNameTag {}
extension ImplicitlyUnwrappedOptional: ImplicitlyUnwrappedOptionalNameTag {}

protocol OptionalNameTag {}
extension Optional: OptionalNameTag {}

/// A nib segue declaration.
@objc class SegueDeclaration: NSObject {
    @objc var id: String!
    @objc var kind: String!
    @objc var destination: String!
    @objc var identifier: String?
    @objc var relationship: String?
    @objc var unwindAction: String?
    var destinationClassName: String?

    var parentClassName: String?
    var classObject: Class?

    override var description: String {
        if let klass = classObject {
            return "\(klass.path ?? parentClassName ?? ""):\(klass.line ?? 1):0"
        }

        return ":1:0"
    }

    var isUnwindSegue: Bool {
        return unwindAction != nil
    }

    init(attributes: [String: String]) {
        super.init()

        setProperties(from: attributes)
    }

    func resolveFile(classNameToClassMap: [String: Class]) {
        if let parentClassName = parentClassName, let klass = classNameToClassMap[parentClassName] {
            classObject = klass
        } else {
            // TODO: find out if and when
            fatalError("why?")
        }
    }

    /// Assumes non-optional typed properties are constants, so ignores them
    private func set(properties: Mirror.Children, attributes: [String: String]) {
//        let propertyList = properties.flatMap({ $0.label })

        let propertyList = properties.flatMap({ $0.label != nil ? (label: $0.label!, value: $0.value) : nil }).flatMap {
            if $0.value is ImplicitlyUnwrappedOptionalNameTag {
                assert(attributes[$0.label] != nil, "Should never happen. Means an implicitly unwrapped property will be nil.")
            }

            return $0.value is ExpressibleByNilLiteral ? $0.label : nil
        }

//        for propertyName in propertyList.flatMap({ $0.label }) {
//            if let value = attributes[propertyName] {
//                self.setValue(value, forKey: propertyName)
//            }
//        }

        for (propertyName, value) in attributes {
            if propertyList.contains(propertyName) {
                self.setValue(value, forKey: propertyName)
            }
        }
    }

    func setProperties(from attributes: [String: String]) {
        set(properties: Mirror(reflecting: self).children, attributes: attributes)
    }

}

enum ConnectionIssue: Issue {
    case missingOutlet(className: String, outlet: Declaration)
    case missingAction(className: String, action: Declaration)
    case unnecessaryOutlet(className: String, outlet: Declaration)
    case unnecessaryAction(className: String, action: Declaration)
    case unknownSegueIdentifier(className: String, segueIdentifier: SegueIdentifier)
    case brokenUnwindSegue(className: String, segueDeclaration: SegueDeclaration)

    var description: String {
        switch self {
        case let .missingOutlet(_, outlet):
            return "\(outlet.description): \(Configuration.shared.missingIssueType): \(formattedDescription)"
        case let .missingAction(_, action):
            return "\(action.description): \(Configuration.shared.missingIssueType): \(formattedDescription)"
        case let .unnecessaryOutlet(_, outlet):
            if Configuration.shared.isEnabled(.ignoreOptionalProperty) && outlet.isOptional {
                return ""
            }
            return "\(outlet.description): warning: \(formattedDescription)"
        case let .unnecessaryAction(_, action):
            return "\(action.description): warning: \(formattedDescription)"
        case .unknownSegueIdentifier(_, let segueIdentifier):
            return "\(segueIdentifier.description): warning: \(formattedDescription)"
        case .brokenUnwindSegue(_, let segueDeclaration):
            return "\(segueDeclaration.description): \(Configuration.shared.missingIssueType): \(formattedDescription)"
        }
    }

    private var formattedDescription: String {
        switch self {
        case let .missingOutlet(className: className, outlet: outlet):
            let interfaceObjectDescription = outlet.parentClass != nil ? "in \(outlet.parentClass!) " : ""
            return "IBOutlet missing: \(outlet.name) is not connected " + interfaceObjectDescription + "in \(outlet.fileName(className: className))"
        case let .missingAction(className: className, action: action):
            return "IBAction missing: '\(action.name)' is not implemented in \(action.fileName(className: className))"
        case let .unnecessaryOutlet(className: className, outlet: outlet):
            let suggestion = outlet.isOptional
                ? ", remove warning by adding '\(Rule.ignoreOptionalProperty.rawValue)' argument"
                : ", consider set '\(outlet.name)' Optional"
            return "IBOutlet unused: \(outlet.name) not linked in \(outlet.fileName(className: className))" + suggestion
        case let .unnecessaryAction(className: className, action: action):
            return "IBAction unused: '\(action.name)' not linked in \(action.fileName(className: className))"
        case let .unknownSegueIdentifier(className, segueIdentifier):
            // TODO: remove hardcoded Main.storyboard
            return "Unknown Identifier: '\(segueIdentifier.identifier)' does not identify any segues from \(className) in Main.storyboard"
        case .brokenUnwindSegue(let className, let segueDeclaration):
            assert(segueDeclaration.unwindAction != nil, "Made a wrong turn somewhere.")
            return "Broken Connection: '\(segueDeclaration.unwindAction!)' does not identify any @IBAction functions (\(className))"
        }
    }

    var isSeriousViolation: Bool {
        switch self {
        case .missingOutlet, .missingAction, .brokenUnwindSegue:
            return true
        default:
            return false
        }
    }
}

enum Rule: String {
    /// Track optional properties
    case ignoreOptionalProperty
    /// Report missing outlets/actions as an error, instead of a warning.
    case reportMissingAsError
    /// Report missing outlets to the respective view controller, instead of the storyboard file.
    case reportMissingToController
}

public class Configuration {

    public static let shared = Configuration()

    var configuration: [Rule: Bool] = [
        .ignoreOptionalProperty: false,
        .reportMissingAsError: false,
        .reportMissingToController: false
    ]

    #if TEST
    var missingIssueType: String {
        return isEnabled(.reportMissingAsError) ? "error" : "warning"
    }
    #else
    lazy var missingIssueType: String = {
        return isEnabled(.reportMissingAsError) ? "error" : "warning"
    }()
    #endif

    private init() { }

    public func setup(with arguments: [String]) {
        for argument in arguments {
            if let rule = Rule(rawValue: argument) {
                self.configuration[rule] = true
            }
        }
    }

    func isEnabled(_ rule: Rule) -> Bool {
        return configuration[rule] ?? false
    }
}

/// Represents a source location in a Swift file.
public struct SourceLocation: Codable {
    /// The line in the file where this location resides.
    public let line: Int

    /// The UTF-8 byte offset from the beginning of the line where this location
    /// resides.
    public let column: Int

    /// The UTF-8 byte offset into the file where this location resides.
    public let offset: Int

    /// The file in which this location resides.
    public let file: String

    public init(line: Int, column: Int, offset: Int, file: String) {
        self.line = line
        self.column = column
        self.offset = offset
        self.file = file
    }
}

public struct SegueIdentifier: Codable {
    let sourceLocation: SourceLocation
    let identifier: String

    var description: String {
        return "\(sourceLocation.file):\(sourceLocation.line):\(sourceLocation.column)"
    }
}

public struct ConnectionAnalyzer: Analyzer {

    public init() {}

    public func issues(for configuration: AnalyzerConfiguration) -> [Issue] {
        var result: [Issue] = missingElements(for: configuration)
        result.append(contentsOf: unnecessaryElements(for: configuration))

        let tmp = configuration.classNameToNibMap
        let cls = tmp["SignupViewController"]!
//        print(cls)

        return result
    }

    // MARK: - Private

    private func missingElements(for configuration: AnalyzerConfiguration) -> [Issue] {
        var result: [ConnectionIssue] = []

        for (className, nib) in configuration.classNameToNibMap {
            guard nib.actions.count > 0 || nib.outlets.count > 0 || nib.segues.count > 0 else { continue }

            for outlet in nib.outlets {
                let matchOutlet: (Class) -> Bool = { $0.outlets.contains(outlet) }

                if !classOrInheritedTypeOf(className: className, configuration: configuration, matches: matchOutlet) {
                    if Configuration.shared.isEnabled(.reportMissingToController),
                        let classObject = configuration.classNameToClassMap[className] {

                        outlet.parentClassPath = classObject.path
                        if let line = classObject.line {
                            outlet.line = line
                        }
                    }

                    result.append(.missingOutlet(className: className, outlet: outlet))
                }
            }

            for action in nib.actions {
                let matchAction: (Class) -> Bool = { $0.actions.contains(action) }

                if !classOrInheritedTypeOf(className: className, configuration: configuration, matches: matchAction) {
                    result.append(.missingAction(className: className, action: action))
                }
            }

            for segue in nib.segues {
                unwind: if segue.isUnwindSegue {
                    for klass in configuration.classNameToClassMap.values {
                        if klass.actions.contains(where: { print("\($0.name) == \(segue.unwindAction ?? "")"); return $0.name == segue.unwindAction }) {
                            break unwind
                        }
                    }

                    result.append(ConnectionIssue.brokenUnwindSegue(className: className, segueDeclaration: segue))
                }
            }

//            var segues = nib.segues
//            for segue in nib.segues {
//
//            }

//            for segue in nib.segues {
//                print(segue.identifier)
//                if let identifier = segue.identifier {
//                    let matchAction: (Class) -> Bool = { $0.segueIdentifiers.contains(where: { $0.identifier == identifier }) }
//
//                    if !classOrInheritedTypeOf(className: className, configuration: configuration, matches: matchAction) {
//                        print()
////                        result.append(.missingAction(className: className, action: action))
//                    }
//                }
//            }
        }

        return result
    }

    private func unnecessaryElements(for configuration: AnalyzerConfiguration) -> [Issue] {
        var result: [Issue] = []

        for (className, klass) in configuration.classNameToClassMap {
            guard klass.actions.count > 0 || klass.outlets.count > 0 || klass.segueIdentifiers.count > 0 else {
                continue
            }

            guard let nib = configuration.classNameToNibMap[className] else {
                // This can happen when for example an outlet/action is in a superclass
                // that doesn't have its own nib.
                continue
            }

            for outlet in klass.outlets {
                if !nib.outlets.contains(outlet) {
                    result.append(ConnectionIssue.unnecessaryOutlet(className: className, outlet: outlet))
                }
            }

            actionLoop: for action in klass.actions {
                for nib in configuration.classNameToNibMap.values {
                    if nib.segues.contains(where: { $0.unwindAction == action.name }) || nib.actions.contains(action) {
                        continue actionLoop
                    }
                }

                result.append(ConnectionIssue.unnecessaryAction(className: className, action: action))
            }

            for segueIdentifier in klass.segueIdentifiers {
                if !nib.segues.contains { $0.identifier == segueIdentifier.identifier } {
                    result.append(ConnectionIssue.unknownSegueIdentifier(className: className, segueIdentifier: segueIdentifier))
                }
            }
        }

        return result
    }

    private func classOrInheritedTypeOf(className: String,
                                        configuration: AnalyzerConfiguration,
                                        matches match: (Class) -> Bool) -> Bool {
        guard let klass = configuration.classNameToClassMap[className] else {
            // Shouldn't really happen.
            return false
        }

        guard !match(klass) else {
            return true
        }

        var inheritedTypes = klass.inherited

        while inheritedTypes.count > 0 {
            // Removes first because it's most likely to be a class.
            let typeName = inheritedTypes.removeFirst()

            if let uiKitClass = configuration.uiKitClassNameToClassMap[typeName] {
                // It's possible that we're working with an outlet included in one of UIKit classes.
                if match(uiKitClass) {
                    return true
                }
            } else if let klass = configuration.classNameToClassMap[typeName] {
                if match(klass) {
                    return true
                } else {
                    inheritedTypes.append(contentsOf: klass.inherited)
                }
            }
        }

        return false
    }
}
