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
    @StateObject var didRun = RunProgram()
    @StateObject var programText = ProgramText()
    var body: some Scene {
        WindowGroup {
            ContentView(programText: programText, didRun: didRun)
        }
    }
}


