//
//  ConnectionAnalyzerTests.swift
//  IBAnalyzer
//
//  Created by Arkadiusz Holko on 14/01/2017.
//  Copyright © 2017 Arkadiusz Holko. All rights reserved.
//

import XCTest
@testable import IBAnalyzer

extension ConnectionIssue: Equatable {
    public static func == (lhs: ConnectionIssue, rhs: ConnectionIssue) -> Bool {
        // Not pretty but probably good enough for tests.
        return String(describing: lhs) == String(describing: rhs)
    }
}

class ConnectionAnalyzerTests: XCTestCase {

    /// Default configuration.
    override func tearDown() {
        Configuration.shared.configuration = [
            .ignoreOptionalProperty: false,
            .reportMissingAsError: false,
            .reportMissingToController: false
        ]
    }

    func testNoOutletsAndActions() {
        let nib = Nib(outlets: [], actions: [])
        let klass = Class(outlets: [], actions: [], inherited: [])
        let configuration = AnalyzerConfiguration(classNameToNibMap: ["A": nib],
                                                  classNameToClassMap: ["A": klass])
        XCTAssertEqual(issues(for: configuration), [])
    }

    func testMissingOutletWarning() {
        let label = Declaration(name: "label", line: 1, column: 0)
        let nib = Nib(outlets: [label], actions: [])
        let klass = Class(outlets: [], actions: [], inherited: [])
        let configuration = AnalyzerConfiguration(classNameToNibMap: ["A": nib],
                                                  classNameToClassMap: ["A": klass])
        let connectionIssues = issues(for: configuration)
        XCTAssertEqual(connectionIssues, [ConnectionIssue.missingOutlet(className: "A", outlet: label)])
        XCTAssertEqual(connectionIssues.first!.description, "label:1:0: warning: IBOutlet missing: label is not connected in A")
    }

    func testMissingOutletError() {
        let label = Declaration(name: "label", line: 1, column: 0)
        let nib = Nib(outlets: [label], actions: [])
        let klass = Class(outlets: [], actions: [], inherited: [])
        let configuration = AnalyzerConfiguration(classNameToNibMap: ["A": nib],
                                                  classNameToClassMap: ["A": klass])

        Configuration.shared.configuration[.reportMissingAsError] = true

        let connectionIssues = issues(for: configuration)
        XCTAssertEqual(connectionIssues, [ConnectionIssue.missingOutlet(className: "A", outlet: label)])
        XCTAssertEqual(connectionIssues.first!.description, "label:1:0: error: IBOutlet missing: label is not connected in A")
    }

    func testMissingActionWarning() {
        let didTapButton = Declaration(name: "didTapButton:", line: 1, column: 0)
        let nib = Nib(outlets: [], actions: [didTapButton])
        let klass = Class(outlets: [], actions: [], inherited: [])
        let configuration = AnalyzerConfiguration(classNameToNibMap: ["A": nib],
                                                  classNameToClassMap: ["A": klass])
        let connectionIssues = issues(for: configuration)
        XCTAssertEqual(connectionIssues,
                       [ConnectionIssue.missingAction(className: "A", action: didTapButton)])
        XCTAssertEqual(connectionIssues.first!.description, "didTapButton:1:0: warning: IBAction missing: didTapButton: is not implemented in A")
    }

    func testMissingActionError() {
        let didTapButton = Declaration(name: "didTapButton:", line: 1, column: 0)
        let nib = Nib(outlets: [], actions: [didTapButton])
        let klass = Class(outlets: [], actions: [], inherited: [])
        let configuration = AnalyzerConfiguration(classNameToNibMap: ["A": nib],
                                                  classNameToClassMap: ["A": klass])

        Configuration.shared.configuration[.reportMissingAsError] = true

        let connectionIssues = issues(for: configuration)
        XCTAssertEqual(connectionIssues,
                       [ConnectionIssue.missingAction(className: "A", action: didTapButton)])
        XCTAssertEqual(connectionIssues.first!.description, "didTapButton:1:0: error: IBAction missing: didTapButton: is not implemented in A")
    }

    func testUnnecessaryOutlet() {
        let nib = Nib(outlets: [], actions: [])
        let label = Declaration(name: "label", line: 1, column: 0)
        let klass = Class(outlets: [label], actions: [], inherited: [])
        let configuration = AnalyzerConfiguration(classNameToNibMap: ["A": nib],
                                                  classNameToClassMap: ["A": klass])
        XCTAssertEqual(issues(for: configuration),
                       [ConnectionIssue.unnecessaryOutlet(className: "A", outlet: label)])
    }

    func testUnnecessaryAction() {
        let nib = Nib(outlets: [], actions: [])
        let didTapButton = Declaration(name: "didTapButton:", line: 1, column: 0)
        let klass = Class(outlets: [], actions: [didTapButton], inherited: [])
        let configuration = AnalyzerConfiguration(classNameToNibMap: ["A": nib],
                                                  classNameToClassMap: ["A": klass])
        XCTAssertEqual(issues(for: configuration),
                       [ConnectionIssue.unnecessaryAction(className: "A", action: didTapButton)])
    }

    func testNoIssueWhenOutletInSuperClass() {
        let label = Declaration(name: "label", line: 1, column: 0)
        let nib = Nib(outlets: [label], actions: [])
        let map = ["A": Class(outlets: [label], actions: [], inherited: []),
                   "B": Class(outlets: [], actions: [], inherited: ["A"])]
        let configuration = AnalyzerConfiguration(classNameToNibMap: ["B": nib],
                                                  classNameToClassMap: map)
        XCTAssertEqual(issues(for: configuration), [])
    }

    func testNoIssueWhenOutletInSuperSuperClass() {
        let label = Declaration(name: "label", line: 1, column: 0)
        let nib = Nib(outlets: [label], actions: [])
        let map = ["A": Class(outlets: [label], actions: [], inherited: []),
                   "B": Class(outlets: [], actions: [], inherited: ["A"]),
                   "C": Class(outlets: [], actions: [], inherited: ["B"])]
        let configuration = AnalyzerConfiguration(classNameToNibMap: ["C": nib],
                                                  classNameToClassMap: map)
        XCTAssertEqual(issues(for: configuration), [])
    }

    func testNoIssueWhenActionInSuperClass() {
        let didTapButton = Declaration(name: "didTapButton:", line: 1, column: 0)
        let nib = Nib(outlets: [], actions: [didTapButton])
        let map = ["A": Class(outlets: [], actions: [didTapButton], inherited: []),
                   "B": Class(outlets: [], actions: [], inherited: ["A"]),
                   "C": Class(outlets: [], actions: [], inherited: ["B"])]
        let configuration = AnalyzerConfiguration(classNameToNibMap: ["C": nib],
                                                  classNameToClassMap: map)
        XCTAssertEqual(issues(for: configuration), [])
    }

    func testUsesUIKitClasses() {
        let delegate = Declaration(name: "delegate:", line: 1, column: 0)
        let nib = Nib(outlets: [delegate], actions: [])
        let klass = Class(outlets: [], actions: [], inherited: ["UITextField"])
        let textField = Class(outlets: [delegate], actions: [], inherited: [])
        let configuration = AnalyzerConfiguration(classNameToNibMap: ["A": nib],
                                                  classNameToClassMap: ["A": klass],
                                                  uiKitClassNameToClassMap: ["UITextField": textField])
        XCTAssertEqual(issues(for: configuration), [])
    }

    private func issues(for configuration: AnalyzerConfiguration) -> [ConnectionIssue] {
        let analyzer = ConnectionAnalyzer()
        return (analyzer.issues(for: configuration) as? [ConnectionIssue]) ?? []
    }
}
