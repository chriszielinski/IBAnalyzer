//
//  Nib.swift
//  IBAnalyzer
//
//  Created by Arkadiusz Holko on 29/01/2017.
//  Copyright © 2017 Arkadiusz Holko. All rights reserved.
//

import Foundation

public struct Nib {
    var outlets: [Declaration]
    var actions: [Declaration]
    var segues: [SegueDeclaration]
}

extension Nib: Equatable {
    public static func == (lhs: Nib, rhs: Nib) -> Bool {
        return lhs.outlets == rhs.outlets && lhs.actions == rhs.actions && lhs.segues == rhs.segues
    }
}
