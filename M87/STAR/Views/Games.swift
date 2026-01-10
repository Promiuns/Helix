// these games are for the documentary and tutorials to help with engagement

import SwiftUI

struct ProgramGame: View {
    @State var text = ""
    @State var hovering: (Bool, Bool) = (false, false)
    let checkingText: String
    @State var success: Bool = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerSize: CGSize(width: 15, height: 15))
                .frame(width: 275, height: 300)
                .foregroundStyle(.black.opacity(0.4))
            
            Group {
                VStack {
                    Button {
                        if text.lowercased() == checkingText.lowercased() {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                success.toggle()
                            }
                            
                        }
                        
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 35)
                                .frame(width: 50, height: 30)
                                .foregroundStyle(Color.green.opacity(0.2))
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.green.opacity(0.6))
                                .scaleEffect(CGSize(width: 1.5, height: 1.5))
                        }
                        .scaleEffect(CGSize(width: hovering.0 ? 1.2 : 1, height: hovering.0 ? 1.2 : 1))
                        
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hovering.0)
                    .onHover { hovering.0 = $0 }
                    .padding()
                    Divider()
                        .frame(width: 250)
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .frame(width: 250, height: 200)
                        .font(.system(size: 15, design: .monospaced))
                    Divider()
                        .frame(width: 250)
                }
                .onAppear() {
                    
                }
            }
            
            Rectangle()
                .foregroundStyle(.black)
                .opacity(success ? 0.3 : 0)
                .animation(.easeOut(duration: 0.1), value: success)
                .frame(width: 275, height: 300)
            
            if success {
                ZStack {
                    ConfettiView(width: 275, height: 300)
                    Text("Great Job!")
                        .font(.system(size: 20))
                        .bold()
                }
            }
        }
    }
}

#Preview {
    ProgramGame(checkingText: "")
}
