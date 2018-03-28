//
//  Analyzer.swift
//  IBAnalyzer
//
//  Created by Arkadiusz Holko on 29/01/2017.
//  Copyright © 2017 Arkadiusz Holko. All rights reserved.
//

import Foundation

public struct AnalyzerConfiguration {
    let classNameToNibMap: [String: Nib]
    let classNameToClassMap: [String: Class]
    let uiKitClassNameToClassMap: [String: Class]
    let allNibSegues: [SegueDeclaration]

    init(classNameToNibMap: [String: Nib],
         classNameToClassMap: [String: Class],
         uiKitClassNameToClassMap: [String: Class] = uiKitClassNameToClass(),
         allNibSegues: [SegueDeclaration]) {
        self.classNameToNibMap = classNameToNibMap
        self.classNameToClassMap = classNameToClassMap
        self.uiKitClassNameToClassMap = uiKitClassNameToClassMap
        self.allNibSegues = allNibSegues
    }
}

public protocol Issue: CustomStringConvertible {
    var isSeriousViolation: Bool { get }
}

public protocol Analyzer {
    func issues(for configuration: AnalyzerConfiguration) -> [Issue]
}
