import SwiftUI
internal import Combine
import RegexBuilder

func RGB(_ r: Double = 0, _ g: Double = 0, _ b: Double = 0, _ a: Double = 1, rand: Bool = false) -> Color {
    if rand {
        return RGB(Double.random(in: 0...255), Double.random(in: 0...255), Double.random(in: 0...255))
    } else {
        return Color(red: r/255.0, green: g/255.0, blue: b/255.0).opacity(a)
    }
}

extension Color {
    static func invertedScheme(for colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? .white : .black
    }
    
    static func scheme(for colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? .black : .white
    }
}

struct BorderedTextEditor<Content: View>: View {
    @Binding var text: AttributedString
    @State var viewWidth: CGFloat = 0
    @State var viewHeight: CGFloat = 0
    let padding: CGFloat?
    let borderSize: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            content()
                .padding(padding ?? 0)
                .allowsHitTesting(false)
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
                    .allowsHitTesting(false)
                )

            let safeWidth = max(0, (viewWidth.isFinite ? viewWidth : 0) - (borderSize + (padding ?? 0)) / 2)
            let safeHeight = max(0, (viewHeight.isFinite ? viewHeight : 0) - (borderSize + (padding ?? 0)) / 2)

            TextEditor(text: $text)
                .padding(padding ?? 0)
                .font(.system(size: 15, design: .monospaced))
                .disableAutocorrection(true)
                .scrollContentBackground(.hidden)
                .frame(width: safeWidth, height: safeHeight)
                // Trigger highlighting whenever text changes
                .onChange(of: text) { _, newValue in
                    applySyntaxHighlighting()
                }
        }
    }

    private func applySyntaxHighlighting() {
        let plainText = String(text.characters)
        var updated = AttributedString(plainText)
        
        // 1. Reset default style
        updated.foregroundColor = .primary
        updated.font = .system(size: 15, design: .monospaced)

        // 2. Highlight Strings: green (Process these first so keywords inside quotes aren't pink)
        // Pattern: Matches anything between double quotes, including escaped quotes \"
        let stringPattern = /"[^"\\]*(?:\\.[^"\\]*)*"/
        for match in plainText.ranges(of: stringPattern) {
            if let attributedRange = Range(match, in: updated) {
                updated[attributedRange].foregroundColor = RGB(111, 171, 113)
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
                if updated[attributedRange].foregroundColor != RGB(111, 171, 113) {
                    updated[attributedRange].foregroundColor = RGB(88, 200, 230)
                    updated[attributedRange].font = .system(size: 15, design: .monospaced)
                }
            }
        }

        // 3. Highlight Keywords: bold and pink
        let keywords = [
            "var", "if", "for", "while", "struct", "copy", "let", "else", "create", "in", "fn", "return"
        ]
        let types = [
            "number", "string", "boolean", "void", "array", "optional"
        ]
        let builtinFunctions = [
            "print", "length", "append", "round"
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
                    if updated[attributedRange].foregroundColor != RGB(111, 171, 113) {
                        updated[attributedRange].foregroundColor = .pink
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
                    if updated[attributedRange].foregroundColor != RGB(111, 171, 113) {
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
                    if updated[attributedRange].foregroundColor != RGB(111, 171, 113) {
                        updated[attributedRange].foregroundColor = RGB(166, 68, 227)
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
                    if updated[attributedRange].foregroundColor != RGB(111, 171, 113) {
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


struct Terminal<Content: View>: View {
    @ObservedObject var output: Output
    @ViewBuilder var content: () -> Content
    var body: some View {
        BorderedTextEditor(text: .constant(AttributedString(output.terminaltext.joined(separator: "\n"))), padding: 0, borderSize: 40, content: { content() })
    }
}

struct NotchHandle: View {
    @Binding var hovering: Bool
    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .foregroundStyle(.primary)
            .overlay(
                Capsule()
                    .stroke(.secondary.opacity(0.6), lineWidth: 1)
            )
    }
}

struct HoverBar<Content: View>: View {
    @State private var hovering = false
    @State var width: (CGFloat, CGFloat)
    @State var height: (CGFloat, CGFloat)
    @ViewBuilder var content: () -> Content
    @State var label: String?
    var body: some View {
        ZStack {
            NotchHandle(hovering: $hovering)
                .frame(width: hovering ? width.0 : width.1, height: hovering ? height.0 : height.1)
                
            VStack {
                content()
            }
            .offset(y: hovering ? 0 : -60)
            .opacity(hovering ? 1 : 0)
            
            Text(label ?? "")
                .font(.system(size: 15, design: .monospaced))
                .opacity(hovering ? 0 : 1)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering)
        .onHover { hovering = $0 }
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
    @Environment(\.colorScheme) var colorScheme
    @State var hovering: (Bool, Bool, Bool, Bool, Bool, Bool) = (false, false, false, false, false, false)
    // Local attributed editor state, initialized from ProgramText.programText (String)
    @State private var attributedText: AttributedString = ""

    var body: some View {
        VStack {
            Text("*STAR*: Systematic Task and Runtime")
                .font(.system(size: 20, design: .monospaced))
            HStack {
                Pushback(maxWidth: 330, maxHeight: 224) {
                    HStack(spacing: 20) {
                        HoverBar(width: (130, 130), height: (225, 40), content: {
                            VStack(spacing: 7) {
                                Button {
                                    didRun.didRun = true
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 35)
                                            .frame(width: 65, height: 35)
                                            .foregroundStyle(Color.green.opacity(0.2))
                                        Image(systemName: "play.fill")
                                            .foregroundStyle(Color.green.opacity(0.6))
                                            .scaleEffect(CGSize(width: 1.5, height: 1.5))
                                    }
                                    .scaleEffect(CGSize(width: hovering.0 ? 1.2 : 1, height: hovering.0 ? 1.2 : 1))
                                    
                                    
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.0)
                                .onHover { hovering.0 = $0 }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 35)
                                        .stroke(Color.invertedScheme(for: colorScheme).opacity(0.7), lineWidth: 1)
                                        .scaleEffect(hovering.0 ? CGSize(width: 1.2, height: 1.2) : CGSize(width: 1, height: 1))
                                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.0)
                                )
                                Text("Run Code")
                                Button {
                                    //
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 35)
                                            .frame(width: 65, height: 35)
                                            .foregroundStyle(Color.yellow.opacity(0.2))
                                        Image(systemName: "forward.frame.fill")
                                            .foregroundStyle(Color.yellow.opacity(0.6))
                                            .scaleEffect(CGSize(width: 1.5, height: 1.5))

                                    }
                                    .scaleEffect(CGSize(width: hovering.1 ? 1.2 : 1, height: hovering.1 ? 1.2 : 1))
                                    
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.1)
                                .onHover { hovering.1 = $0 }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 35)
                                        .stroke(Color.invertedScheme(for: colorScheme).opacity(0.7), lineWidth: 1)
                                        .scaleEffect(hovering.1 ? CGSize(width: 1.2, height: 1.2) : CGSize(width: 1, height: 1))
                                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.1)
                                )
                                Text("Step Code")
                                Button {
                                    //
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 35)
                                            .frame(width: 65, height: 35)
                                            .foregroundStyle(Color.red.opacity(0.2))
                                        Image(systemName: "stop.fill")
                                            .foregroundStyle(Color.red.opacity(0.6))
                                            .scaleEffect(CGSize(width: 1.5, height: 1.5))
                                    }
                                    .scaleEffect(hovering.2 ? CGSize(width: 1.2, height: 1.2) : CGSize(width: 1, height: 1))
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.2)
                                .onHover { hovering.2 = $0 }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 35)
                                        .stroke(Color.invertedScheme(for: colorScheme).opacity(0.7), lineWidth: 1)
                                        .scaleEffect(hovering.2 ? CGSize(width: 1.2, height: 1.2) : CGSize(width: 1, height: 1))
                                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.2)
                                )
                                Text("Stop Code")
                            }
                        }, label: "Execution")
                        
                        HoverBar(width: (130, 130), height: (225, 40), content: {
                            VStack(spacing: 10) {
                                VStack {
                                    Button(action: {
                                        
                                    }, label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 35)
                                                .frame(width: 65, height: 35)
                                                .foregroundStyle(Color.blue.opacity(0.2))
                                            Image(systemName: "book.fill")
                                                .foregroundStyle(Color.cyan.opacity(0.6))
                                                .scaleEffect(CGSize(width: 1.5, height: 1.5))
                                        }
                                        .scaleEffect(hovering.3 ? CGSize(width: 1.2, height: 1.2) : CGSize(width: 1, height: 1))
                                    })
                                    .buttonStyle(.plain)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.3)
                                    .onHover { hovering.3 = $0 }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 35)
                                            .stroke(Color.invertedScheme(for: colorScheme).opacity(0.7), lineWidth: 1)
                                            .scaleEffect(hovering.3 ? CGSize(width: 1.2, height: 1.2) : CGSize(width: 1, height: 1))
                                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.3)
                                    )
                                    Text("The Codex")
                                }
                                
                                VStack {
                                    Button(action: {
                                        
                                    }, label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 35)
                                                .frame(width: 65, height: 35)
                                                .foregroundStyle(Color.green.opacity(0.2))
                                            Image(systemName: "questionmark.circle")
                                                .foregroundStyle(Color.green.opacity(0.6))
                                                .scaleEffect(CGSize(width: 1.5, height: 1.5))
                                        }
                                    })
                                    .buttonStyle(.plain)
                                    .scaleEffect(hovering.4 ? CGSize(width: 1.2, height: 1.2) : CGSize(width: 1, height: 1))
                                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.4)
                                    .onHover { hovering.4 = $0 }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 35)
                                            .stroke(Color.invertedScheme(for: colorScheme).opacity(0.7), lineWidth: 1)
                                            .scaleEffect(hovering.4 ? CGSize(width: 1.2, height: 1.2) : CGSize(width: 1, height: 1))
                                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.4)
                                    )
                                    
                                    Text("Programming Languages")
                                        .font(.system(size: 9))
                                }
                                
                                VStack {
                                    Button(action: {
                                        
                                    }, label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 35)
                                                .frame(width: 65, height: 35)
                                                .foregroundStyle(Color.green.opacity(0.2))
                                            Image(systemName: "lightbulb")
                                                .foregroundStyle(Color.green.opacity(0.6))
                                                .scaleEffect(CGSize(width: 1.5, height: 1.5))
                                        }
                                        .scaleEffect(hovering.5 ? CGSize(width: 1.2, height: 1.2) : CGSize(width: 1, height: 1))
                                    })
                                    .buttonStyle(.plain)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.5)
                                    .onHover { hovering.5 = $0 }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 35)
                                            .stroke(Color.invertedScheme(for: colorScheme).opacity(0.7), lineWidth: 1)
                                            .scaleEffect(hovering.5 ? CGSize(width: 1.2, height: 1.2) : CGSize(width: 1, height: 1))
                                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.5)
                                    )
                                    Text("Learn EOM")
                                        
                                }
                            }
                        }, label: "Education")
                    }
                }
                Terminal(output: out) {
                    Rectangle()
                        .foregroundStyle(Color.scheme(for: colorScheme).opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .allowsHitTesting(false)
                }
                    .frame(height: 240)
                    .scrollContentBackground(.hidden)
                    .padding(25)
            }
            Divider()

            BorderedTextEditor(text: $attributedText, padding: 20, borderSize: 50, content: {
                Rectangle()
                    .foregroundStyle(Color.scheme(for: colorScheme).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .allowsHitTesting(false)
            })
            .onAppear {
                attributedText = AttributedString(programText.programText)
            }
            .onChange(of: attributedText) { _, newValue in
                programText.programText = String(newValue.characters)
            }
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
