//
//  M87App.swift
//  M87
//
//  Created by Ryan Bae on 12/11/25.
//
import SwiftUI
internal import Combine

@main
struct M87App: App {
    @Environment(\.colorScheme) var colorScheme
    @StateObject var didRun = RunProgram()
    @StateObject var programText = ProgramText()
    @StateObject var test = ProgramRunner()
    @StateObject var statementParser = StatementParser()
    @StateObject var parser = ExpressionParser()

    var body: some Scene {
        WindowGroup {
            ContentView(statementParser: statementParser, test: test, programText: programText, didRun: didRun, parser: parser)
        }
        .commands {
            // Fallback custom Edit menu with standard shortcuts routed to the responder chain.
            CommandMenu("Edit") {
                Button("Undo") {
                    NSApp.sendAction(#selector(UndoManager.undo), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command])

                Button("Redo") {
                    NSApp.sendAction(#selector(UndoManager.redo), to: nil, from: nil)
                }
                .keyboardShortcut("Z", modifiers: [.command, .shift])

                Divider()

                Button("Cut") {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x", modifiers: [.command])

                Button("Copy") {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("c", modifiers: [.command])

                Button("Paste") {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("v", modifiers: [.command])

                Button("Select All") {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("a", modifiers: [.command])

                Divider()

                Button("Delete") {
                    NSApp.sendAction(#selector(NSText.delete(_:)), to: nil, from: nil)
                }
                .keyboardShortcut(.delete, modifiers: [])
            }

            // Example custom command for your app:
            CommandMenu("Run") {
                Button("Run Program") {
                    didRun.didRun = true
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
    }
}
