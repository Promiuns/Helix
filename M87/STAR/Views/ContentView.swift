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
            GeometryReader { geo in
                let scale = min(
                    geo.size.width / baseSize.width,
                    geo.size.height / baseSize.height
                )
                let xOffset = (geo.size.width -  baseSize.width * scale) / 2
                let yOffset = (geo.size.height - baseSize.height * scale) / 2
                
                ZStack {
                    Combined(out: test.output, programText: programText, didRun: didRun, programRunner: test)
                        .frame(width: baseSize.width, height: baseSize.height)
                        .scaleEffect(scale, anchor: .topLeading)
                        .offset(x: xOffset, y: yOffset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: didRun.didRun, {
                    if didRun.didRun {
                            /*
                             test.output.resetOutput()
                             test.scope.resetScope()
                             test.program = try statementParser.statement_parse(paintext: programText.programText, starting_index: 0)
                             didRun.didRun = false
                             
                             try test.run()
                             */
                        /*
                         struct A {
                         var x: number = 6
                         }
                         
                         struct B {
                         var y: A = create A()
                         }
                         
                         var x: B = create B()
                         */
                        do {
                            test.message = nil
                            test.waitingForInput = false
                            test.output.resetOutput()
                            test.scope.resetScope()
                            // try statementParser.statement_parse(paintext: programText.programText)
							test.program = try statementParser.statement_parse(paintext: programText.programText)
                            test.current_statement_index = 0
                            didRun.didRun = false
                            try test.run()
                        } catch let error as ErrorInformation {
                            switch error.error {
                            case .astError(let errorBubbles):
                                test.output.terminaltext = ["Source Location: AST\n\(errorBubbles) at \(error.line+1)"]
                            case .statementParserError(let statementError):
                                test.output.terminaltext = ["Source Location: Statement Parser\n\(statementError) at \(error.line+1)"]
                            case .expressionParserError(let parserErrors):
                                test.output.terminaltext = ["Source Location: Expression Parser\n\(String(describing: parserErrors)) at \(error.line+1)"]
                            }
                            didRun.didRun = false
                        } catch {
                            test.output.terminaltext = ["\(error)"]
							didRun.didRun = false
                        }
                    }
                })
            }
        }
        .background(
            Rectangle()
                .foregroundStyle(switchColorForScheme(colorScheme, color1: Color(hex: 0xE2D8C2), color2: Color(hex: 0x232323)))
        )
    }
}

#Preview {
    ContentView(statementParser: StatementParser(), test: ProgramRunner() ,programText: ProgramText(), didRun: RunProgram(), parser: ExpressionParser())
}

/*
 struct Counter {
 var value: number = 0
 
 fn inc() => void {
 self.value = self.value + 1
 }
 
 fn add(n: number) => void {
 self.value = self.value + n
 }
 }
 
 var c: Counter = create Counter()
 c.inc()
 c.add(4)
 print(c.value)
 
 "ewhruiewrhiuwerhewiurhewirhweiurhweiurhweiurhweiurhweiurhwuiehriuwrhwiuehruiwheurhwieuhriuwehriuewrhewiurhweiurhewiurhi"
 */
