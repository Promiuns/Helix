internal import Combine
import SwiftUI

final class RunProgram: ObservableObject {
    @Published var didRun = false
}

final class ProgramText: ObservableObject {
    @Published var programText: String = ""
}

final class Output: ObservableObject {
    @Published var terminaltext: [String] = []
    
    func resetOutput() {
        terminaltext = []
    }
}
