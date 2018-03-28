//
//  Class.swift
//  IBAnalyzer
//
//  Created by Arkadiusz Holko on 29/01/2017.
//  Copyright © 2017 Arkadiusz Holko. All rights reserved.
//

import Foundation

public struct Class {
    var path: String?
    var line: Int?
    var outlets: [Declaration]
    var actions: [Declaration]
    var inherited: [String]
    var segueIdentifiers: [SegueIdentifier]

    init(path: String?, line: Int?, outlets: [Declaration], actions: [Declaration], inherited: [String], segueIdentifiers: [SegueIdentifier]) {
        self.path = path
        self.line = line
        self.outlets = outlets
        self.actions = actions
        self.inherited = inherited
        self.segueIdentifiers = segueIdentifiers
    }

    init(outlets: [Declaration], actions: [Declaration], inherited: [String], segueIdentifiers: [SegueIdentifier]) {
        self.init(path: nil, line: nil, outlets: outlets, actions: actions, inherited: inherited, segueIdentifiers: segueIdentifiers)
    }
}

extension Class: Equatable {
    public static func == (lhs: Class, rhs: Class) -> Bool {
        return lhs.outlets == rhs.outlets
            && lhs.actions == rhs.actions
            && lhs.inherited == rhs.inherited
    }
}
