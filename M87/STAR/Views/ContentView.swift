import SwiftUI
struct ContentView: View {
    @ObservedObject var statementParser: StatementParser
    @ObservedObject var test: ProgramRunner
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var programText: ProgramText
    @ObservedObject var didRun: RunProgram
    @ObservedObject var parser: ExpressionParser
    let baseSize = CGSize(width: 1600, height: 900)

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(scheme.opacity(0.3))
            
            GeometryReader { geo in
                let scale = min(
                    geo.size.width / baseSize.width,
                    geo.size.height / baseSize.height
                )
                let xOffset = (geo.size.width -  baseSize.width * scale) / 2
                let yOffset = (geo.size.height - baseSize.height * scale) / 2
                
                ZStack {
                    Combined(out: test.output, programText: programText, didRun: didRun)
                        .frame(width: baseSize.width, height: baseSize.height)
                        .scaleEffect(scale, anchor: .topLeading)
                        .offset(x: xOffset, y: yOffset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: didRun.didRun, {
                    if didRun.didRun {
                        
                            /*
                             for tmp in 0->4 {
                             print(tmp)
                             }
                             */
                            /*
                             test.output.resetOutput()
                             test.scope.resetScope()
                             test.program = try statementParser.statement_parse(paintext: programText.programText, starting_index: 0)
                             didRun.didRun = false
                             
                             try test.run()
                             */
                            do {
                                test.output.resetOutput()
                                test.scope.resetScope()
                                test.program = try statementParser.statement_parse(paintext: programText.programText, starting_index: 0)
                                didRun.didRun = false
                                
                                try test.run()
                            } catch(let error) {
                                print("Runtime error:", error)
                                didRun.didRun = false
                            }
                    }
                })
            }
        }
    }
    
    var scheme: Color {
        return colorScheme == .dark ? .black : .gray
    }
}

#Preview {
    ContentView(statementParser: StatementParser(), test: ProgramRunner(program: []) ,programText: ProgramText(), didRun: RunProgram(), parser: ExpressionParser())
}
