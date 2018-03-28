//
//  NibParser.swift
//  IBAnalyzer
//
//  Created by Arkadiusz Holko on 24-12-16.
//  Copyright © 2016 Arkadiusz Holko. All rights reserved.
//

import Foundation

public protocol NibParserType {
    func mappingForFile(at url: URL) throws -> [String: Nib]
}

public class NibParser: NibParserType {

    var allSegues: [SegueDeclaration]

    public init() {
        allSegues = []
    }

    public func mappingForFile(at url: URL) throws -> [String: Nib] {
        let parser = XMLParser(data: try Data(contentsOf: url))

        let delegate = ParserDelegate()
        delegate.url = url
        parser.delegate = delegate
        parser.parse()

        allSegues = delegate.allSegues

        let keyValues = delegate.tmp
        print("\(delegate.tmpCount) segues")
        for (key, valueList) in keyValues {
            print("\n\n\(key) (\(valueList.count))")
            for value in valueList {
                print("\t\(value)")
            }
        }

        return delegate.classNameToNibMap
    }
}

// Thanks to SwiftGen for the inspiration :)

private class ParserDelegate: NSObject, XMLParserDelegate {

    private struct Element {
        let tag: String
        let customClassName: String?
    }

    var url: URL!
    var inObjects = false
    var inConnections = false
    private var stack: [Element] = []

    var classNameToNibMap: [String: Nib] = [:]
    var idToCustomClassMap: [String: String] = [:]
    var allSegues: [SegueDeclaration] = []

    var tmp: [String: [String]] = [:]
    var tmpCount = 0

    func parserDidEndDocument(_ parser: XMLParser) {
//        for (_, nib) in classNameToNibMap {
//            var unwindSegues: [SegueDeclaration] = []
//            var exitSegues: [SegueDeclaration] = []
//            for segue in nib.segues {
//                if segue.unwindAction != nil {
//                    unwindSegues.append(segue)
//                }
//            }
//        }
    }

    @objc func parser(_ parser: XMLParser, didStartElement elementName: String,
                      namespaceURI: String?, qualifiedName qName: String?,
                      attributes attributeDict: [String: String]) {

        switch elementName {
        case "objects":
            inObjects = true
            stack = []
        case "connections":
            inConnections = true
        case "outlet" where inConnections, "outletCollection" where inConnections:
            guard let property = attributeDict["property"],
                let customClassName = stack.last?.customClassName else {
                    break
            }

            let outlet = Declaration(name: property, line: parser.lineNumber, column: parser.columnNumber, url: url, customClass: customClassName)
            classNameToNibMap[customClassName]?.outlets.append(outlet)
        case "action" where inConnections:
            guard let selector = attributeDict["selector"],
                let destination = attributeDict["destination"],
                let customClassName = idToCustomClassMap[destination] else {
                    break
            }
            let action = Declaration(name: selector, line: parser.lineNumber, column: parser.columnNumber, url: url)
            classNameToNibMap[customClassName]?.actions.append(action)
        case "segue" where inConnections:
            guard let destination = attributeDict["destination"],
                let customClassName = stack.reversed().first(where: { $0.customClassName != nil })?.customClassName
                else {
                    print("CANT FIND CUSTOM CLASS FOR SEGUE: \(attributeDict)")
                    break
            }

            print("SEGUE!!!: \(attributeDict)")

            let segue = SegueDeclaration(attributes: attributeDict)
            segue.parentClassName = customClassName

            if let className = idToCustomClassMap[destination] {
                segue.destinationClassName = className
            }

            classNameToNibMap[customClassName]!.segues.append(segue)
            allSegues.append(segue)

            print("\t\tbelongs to \(customClassName)")

//            for (key, value) in attributeDict {
//                if tmp[key] == nil {
//                    tmp[key] = [value]
//                } else {
//                    tmp[key]!.append(value)
//                }
//            }
//            tmpCount += 1
        case let tag where (inObjects && tag != "viewControllerPlaceholder"):
            let customClass = attributeDict["customClass"]
            let id = attributeDict["id"]
            stack.append(Element(tag: tag, customClassName: customClass))

            if let customClass = customClass, let id = id {
                idToCustomClassMap[id] = customClass
                classNameToNibMap[customClass] = Nib(outlets: [], actions: [], segues: [])
            }
        default:
            break
        }
    }

    @objc func parser(_ parser: XMLParser, didEndElement elementName: String,
                      namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "objects":
            inObjects = false
            assert(stack.count == 0)
        case "connections":
            inConnections = false
        case "outlet", "outletCollection", "action", "segue":
            break
        case let tag where (inObjects && tag != "viewControllerPlaceholder"):
            stack.removeLast()
        default:
            break
        }
    }
}
