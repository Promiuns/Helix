import SwiftUI

struct ContentView: View {
    @State var statementParser = StatementParser()
    @State var lexer = Lexer()
    @State var parser = ExpressionParser()
    @State var test = ProgramRunner(program: [])
    @ObservedObject var programText: ProgramText
    @ObservedObject var didRun: RunProgram
    let baseSize = CGSize(width: 1600, height: 900)

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(RGB(24, 28, 32))
            
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
                        do {
                            test.output.resetOutput()
                            test.scope.resetScope()
                            test.program = try statementParser.statement_parse(paintext: programText.programText)
                            
                            test.test()
                            didRun.didRun = false
                        } catch {
                            print("did not work")
                        }
                    }
                })
            }
        }
    }
}

#Preview {
    ContentView(programText: ProgramText(), didRun: RunProgram())
}
