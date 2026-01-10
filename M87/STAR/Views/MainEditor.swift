import SwiftUI

func RGB(_ r: Double = 0, _ g: Double = 0, _ b: Double = 0, _ a: Double = 1, rand: Bool = false) -> Color {
    if rand {
        return RGB(Double.random(in: 0...255), Double.random(in: 0...255), Double.random(in: 0...255))
    } else {
        return Color(red: r/255.0, green: g/255.0, blue: b/255.0).opacity(a)
    }
}

struct CodeEditor: View {
    @ObservedObject var text: ProgramText
    var body: some View {
        TextEditor(text: $text.programText)
            .font(.system(size: 15, design: .monospaced))
            .disableAutocorrection(true)
    }
}

struct Terminal: View {
    @ObservedObject var output: Output
    var body: some View {
        TextEditor(text: .constant(output.terminaltext.joined(separator: "\n")))
            .font(.system(size: 15, design: .monospaced))
            .disableAutocorrection(true)
            .disabled(true)
    }
}

struct NotchHandle: View {
    @Binding var hovering: Bool
    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .fill(hovering
                  ? RGB(80, 115, 133).opacity(0.25)
                  : Color.clear)
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.35), lineWidth: 1)
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
    @State var hovering: (Bool, Bool, Bool, Bool, Bool, Bool) = (false, false, false, false, false, false)

    var body: some View {
        VStack {
            Text("*STAR*: Systematic Task and Runtime")
                .font(.system(size: 20, design: .monospaced))
            HStack {
                Pushback(maxWidth: 330, maxHeight: 224) {
                    HStack(spacing: 20) {
                        HoverBar(width: (130, 130), height: (180, 40), content: {
                            VStack(spacing: 20) {
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
                                    .scaleEffect(hovering.4 ? CGSize(width: 1.2, height: 1.2) : CGSize(width: 1, height: 1))
                                    .buttonStyle(.plain)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.4)
                                    .onHover { hovering.4 = $0 }
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
                                    Text("Learn EOM")
                                        
                                }
                            }
                        }, label: "Education")
                    }
                }
                Terminal(output: out)
                    .frame(height: 224)
                    .scrollContentBackground(.hidden)
                    .background(RGB(32, 38, 44))
            }
            Divider()

            CodeEditor(text: programText)
                .scrollContentBackground(.hidden)
                .background(RGB(28, 32, 36))
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
