import SwiftUI
internal import Combine
import RegexBuilder

struct SystemImage: View {
    let name: String
    var body: some View {
        Image(systemName: name)
    }
}

extension View {
    func onHoverAnimation(_ animation: Animation, hovering: Binding<Bool>) -> some View { // a shorthand for making something maybe hover over the background
        self.onHover { hover in
            withAnimation(animation) {
                hovering.wrappedValue = hover
            }
        }
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) { // converts hex to color
        let red = Double((hex >> 16) & 0xff) / 255.0
        let green = Double((hex >> 8) & 0xff) / 255.0
        let blue = Double((hex >> 0) & 0xff) / 255.0
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
}


func RGB(_ r: Double = 0, _ g: Double = 0, _ b: Double = 0, _ a: Double = 1, rand: Bool = false) -> Color {
    if rand {
        return RGB(Double.random(in: 0...255), Double.random(in: 0...255), Double.random(in: 0...255))
    } else {
        return Color(red: r/255.0, green: g/255.0, blue: b/255.0).opacity(a)
    }
}

func switchColorForScheme(_ scheme: ColorScheme, color1: Color, color2: Color) -> Color {
    return scheme == .light ? color1 : color2
}

struct SpiralBinding: View {
    let coilSpacing: CGFloat = 28
    let coilRadius: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let coils = Int(geo.size.height / coilSpacing) - 2

                for i in 1...coils {
                    let y = CGFloat(i) * coilSpacing + coilSpacing / 2
                    path.addArc(
                        center: CGPoint(x: coilRadius + 4, y: y),
                        radius: coilRadius,
                        startAngle: .degrees(90),
                        endAngle: .degrees(270),
                        clockwise: false
                    )
                    path.move(to: CGPoint(x: coilRadius + 4, y: CGFloat(i+1) * coilSpacing + coilSpacing / 2))
                }
            }
            .stroke(
                Color(hex: 0xE969EB, opacity: 0.9),
                style: StrokeStyle(lineWidth: 5, lineCap: .round)
            )
        }
        .frame(width: 20)
    }
}

struct BorderedTextEditor<Content: View>: View {
    @Binding var text: AttributedString
    @State var viewWidth: CGFloat = 0
    @State var viewHeight: CGFloat = 0
    let padding: CGFloat? = nil
    let borderSize: CGFloat
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) var colorScheme
    @State var canBeModified: Bool = true

    var body: some View {
        ZStack {
            content()
                .padding(padding ?? 0)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear() {
                                let size = geo.size
                                if size.width.isFinite && size.height.isFinite {
                                    viewWidth = size.width
                                    viewHeight = size.height
                                }
                            }
                            .onChange(of: geo.size) {
                                let size = geo.size
                                if size.width.isFinite && size.height.isFinite {
                                    viewWidth = size.width
                                    viewHeight = size.height
                                }
                            }
                    }
                )

            let safeWidth = max(0, (viewWidth.isFinite ? viewWidth : 0) - (borderSize + (padding ?? 0)) / 2)
            let safeHeight = max(0, (viewHeight.isFinite ? viewHeight : 0) - (borderSize + (padding ?? 0)) / 2)

            TextEditor(text: $text)
                .font(.system(size: 15, design: .monospaced))
                .disableAutocorrection(true)
                .scrollContentBackground(.hidden)
                .frame(width: safeWidth, height: safeHeight)
                // Trigger highlighting whenever text changes
                .onChange(of: text) { _, newValue in
                    applySyntaxHighlighting()
                }
            .padding(padding ?? 0)
        }
    }

    private func applySyntaxHighlighting() {
        let plainText = String(text.characters)
        var updated = AttributedString(plainText)
        
        // 1. Reset default style
        updated.foregroundColor = switchColorForScheme(colorScheme, color1: Color(hex: 0x545E6E), color2: Color(hex: 0x60EE3D))
        updated.font = .system(size: 15, design: .monospaced)
        
        // 2. Highlight Strings: green (Process these first so keywords inside quotes aren't pink)
        // Pattern: Matches anything between double quotes, including escaped quotes \"
        // RGB(217, 50, 50) RGB(209, 176, 59)
        let stringPattern = /"[^"\\]*(?:\\.[^"\\]*)*"/
        for match in plainText.ranges(of: stringPattern) {
            if let attributedRange = Range(match, in: updated) {
                updated[attributedRange].foregroundColor = switchColorForScheme(colorScheme, color1: RGB(217, 50, 50), color2: RGB(217, 50, 50))
                updated[attributedRange].font = .system(size: 15, weight: .semibold, design: .monospaced)
            }
        }
        
        // 2b. Highlight Numbers (not inside identifiers): cyan-ish
        // Supports optional leading sign and optional fractional part.
        let numberPattern = Regex {
            Anchor.wordBoundary
            Optionally { ChoiceOf { "+"; "-" } }
            OneOrMore(.digit)
            Optionally {
                "."
                OneOrMore(.digit)
            }
            Anchor.wordBoundary
        }
        for match in plainText.ranges(of: numberPattern) {
            if let attributedRange = Range(match, in: updated) {
                // Avoid recoloring numbers inside quoted strings (already green)
                if updated[attributedRange].foregroundColor != RGB(217, 50, 50) {
                    updated[attributedRange].foregroundColor = RGB(88, 200, 230)
                    updated[attributedRange].font = .system(size: 15, design: .monospaced)
                }
            }
        }

        // 3. Highlight Keywords: bold and pink
        let keywords = [
            "var", "if", "for", "while", "struct", "copy", "let", "else", "create", "in", "fn", "return", "id"
        ]
        let types = [
            "number", "string", "boolean", "void", "array", "optional", "type"
        ]
        let builtinFunctions = [
            "print", "length", "append", "round", "input"
        ]
        let bools = [
            "true", "false"
        ]
        for keyword in keywords {
            // use a Regex for word boundaries so "variable" doesn't highlight the "var" part
            let keywordPattern = Regex { Anchor.wordBoundary; keyword; Anchor.wordBoundary }
            
            for match in plainText.ranges(of: keywordPattern) {
                if let attributedRange = Range(match, in: updated) {
                    // only color pink if it hasn't already been colored green (as a string)
                    if updated[attributedRange].foregroundColor != RGB(217, 50, 50) {
                        updated[attributedRange].foregroundColor = RGB(219, 79, 219)
                        updated[attributedRange].font = .system(size: 15, weight: .heavy, design: .monospaced)
                    }
                }
            }
        }
        
        for type in types {
            let keywordPattern = Regex { Anchor.wordBoundary; type; Anchor.wordBoundary }
            
            for match in plainText.ranges(of: keywordPattern) {
                if let attributedRange = Range(match, in: updated) {
                    // now attribute if its a type
                    if updated[attributedRange].foregroundColor != RGB(217, 50, 50) {
                        updated[attributedRange].foregroundColor = .blue
                        updated[attributedRange].font = .system(size: 15, weight: .bold, design: .monospaced)
                    }
                }
            }
        }
        
        for builtinFunction in builtinFunctions {
            let keywordPattern = Regex { Anchor.wordBoundary; builtinFunction; Anchor.wordBoundary }
            
            for match in plainText.ranges(of: keywordPattern) {
                if let attributedRange = Range(match, in: updated) {
                    // now attribute if its a builtin
                    // 37, 168, 116
                    if updated[attributedRange].foregroundColor != RGB(217, 50, 50) {
                        updated[attributedRange].foregroundColor = switchColorForScheme(colorScheme, color1: RGB(166, 68, 227), color2: RGB(37, 168, 116))
                        updated[attributedRange].font = .system(size: 15, design: .monospaced)
                    }
                }
            }
        }
        
        for bool in bools {
            let keywordPattern = Regex { Anchor.wordBoundary; bool; Anchor.wordBoundary }
            
            for match in plainText.ranges(of: keywordPattern) {
                if let attributedRange = Range(match, in: updated) {
                    // now attribute if its a builtin
                    if updated[attributedRange].foregroundColor != RGB(217, 50, 50) {
                        updated[attributedRange].foregroundColor = RGB(232, 100, 223)
                        updated[attributedRange].font = .system(size: 15, design: .monospaced)
                    }
                }
            }
        }
        
        if text != updated {
            text = updated
        }
    }
}

struct ReadOnlyTerminal<Content: View>: View {
    let text: [String]
    @State var viewWidth: CGFloat = 0.0
    @State var viewHeight: CGFloat = 0.0
    @State var padding: Double? = nil
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(padding ?? 0)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear() {
                            let size = geo.size
                            if size.width.isFinite && size.height.isFinite {
                                viewWidth = size.width
                                viewHeight = size.height
                            }
                        }
                        .onChange(of: geo.size) {
                            let size = geo.size
                            if size.width.isFinite && size.height.isFinite {
                                viewWidth = size.width
                                viewHeight = size.height
                            }
                        }
                }
            )
        TextEditor(text: .constant(text.joined(separator: "\n")))
            .font(.system(size: 15, design: .monospaced))
            .disableAutocorrection(true)
            .scrollContentBackground(.hidden)
    }
}

extension NSTextView {
    open override var frame: CGRect {
        didSet {
            self.isAutomaticQuoteSubstitutionEnabled = false
        }
    }
}

struct Pushback<Content: View>: View {
    var maxWidth: CGFloat?
    var maxHeight: CGFloat?
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.clear)
                .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            content()
        }
    }
}

struct Combined: View {
    @ObservedObject var out: Output
    @ObservedObject var programText: ProgramText
    @ObservedObject var didRun: RunProgram
    @ObservedObject var programRunner: ProgramRunner
    @State private var terminalWidth: CGFloat = 0
    @State private var terminalHeight: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering: InlineArray<2, Bool> = [false, false] // since we never change the size, we use InlineArray
    // Local attributed editor state, initialized from ProgramText.programText (String)
    @State private var attributedText: AttributedString = ""
    @State private var inputText = ""
    @State private var terminal: AttributedString = ""

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Editor")
                            .font(.system(size: 30, weight: .semibold, design: .monospaced))
                            .padding()
                        HStack(spacing: 40) {
                            Button(action: {
                                didRun.didRun = true
                            }, label: {
                                SystemImage(name: "play.fill")
                            })
                            .scaleEffect(3 + (hovering[0] ? 0.6 : 0))
                            .shadow(color: switchColorForScheme(colorScheme, color1: .black.opacity(hovering[0] ? 1 : 0), color2: .white.opacity(hovering[0] ? 0.4 : 0)), radius: 15)
                            .onHoverAnimation(.spring(.bouncy), hovering: $hovering[0])
                            
                            Button(action: {
                                didRun.didRun = false
                                programRunner.waitingForInput = false
                                programRunner.current_statement_index = 0
                            }, label: {
                                SystemImage(name: "stop.fill")
                            })
                            .scaleEffect(3 + (hovering[1] ? 0.6 : 0))
                            .shadow(color: switchColorForScheme(colorScheme, color1: .black.opacity(hovering[1] ? 1 : 0), color2: .white.opacity(hovering[1] ? 0.4 : 0)), radius: 15)
                            .onHoverAnimation(.spring(.bouncy), hovering: $hovering[1])
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 30)
                    }
                    Divider()
                        .bold()
                    TextField(programRunner.message ?? "", text: $inputText)
                        .font(.system(size: 30, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .padding()
                        .disabled(!programRunner.waitingForInput)
                        .onSubmit {
                            do {
                                programRunner.waitingForInput = false
                                try programRunner.resumeFromInput(from: .string(inputText))
                                inputText = ""
                            } catch let error as ErrorInformation {
                                switch error.error {
                                case .astError(let errorBubbles):
                                    programRunner.output.terminaltext = ["Source Location: AST\n\(errorBubbles)at \(error.line+1)"]
                                case .statementParserError(let statementError):
                                    programRunner.output.terminaltext = ["Source Location: Statement Parser\n\(statementError)at \(error.line+1)"]
                                case .expressionParserError(let parserErrors):
                                    programRunner.output.terminaltext = ["Source Location: Expression Parser\n\(String(describing: parserErrors))at \(error.line+1)"]
                                }
                                didRun.didRun = false
                            } catch {
                                programRunner.output.terminaltext = ["\(error)"]
                            }
                        }
                    HStack(spacing: -5) {
                        if colorScheme == .light {
                            SpiralBinding()
                                .background(
                                    SpiralBinding()
                                        .opacity(0.5)
                                        .offset(y: 3)
                                )
                                .zIndex(3)
                        }
                        BorderedTextEditor(text: $attributedText, borderSize: 100, content: {
                            Rectangle()
                                .clipShape(RoundedRectangle(cornerRadius: 50))
                                .foregroundStyle(switchColorForScheme(colorScheme, color1: Color(hex: 0xF1EFDD), color2: Color(hex: 0x353535)))
                        })
                        .onAppear() {
                            attributedText = AttributedString(programText.programText)
                        }
                        .onChange(of: attributedText) { _, newText in
                            programText.programText = String(newText.characters)
                        }
                    }
                    .padding()
                }
                Divider()
                VStack(alignment: .leading) {
                    Text("Terminal")
                        .font(.system(size: 30, weight: .semibold, design: .monospaced))
                        .padding()
                    Divider()
                        .bold()
                    HStack(spacing: -5) {
                        if colorScheme == .light {
                            SpiralBinding()
                                .background(
                                    SpiralBinding()
                                        .opacity(0.5)
                                        .offset(y: 3)
                                )
                                .zIndex(3)
                        }
                        ZStack {
                            Rectangle()
                                .clipShape(RoundedRectangle(cornerRadius: 50))
                                .foregroundStyle(switchColorForScheme(colorScheme, color1: Color(hex: 0xF1EFDD), color2: Color(hex: 0x353535)))
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear() {
                                                terminalWidth = geo.size.width
                                                terminalHeight = geo.size.height
                                            }
                                    }
                                    .foregroundStyle(.clear)
                                )
                            TextEditor(text: .constant(out.terminaltext.joined(separator: "\n")))
                                .frame(width: max(terminalWidth, 50) - 50, height: max(terminalWidth, 50) - 50)
                                .scrollContentBackground(.hidden)
                                .font(.system(size: 15, design: .monospaced))
                        }
                        
                    }
                    .padding()
                }
            }
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
