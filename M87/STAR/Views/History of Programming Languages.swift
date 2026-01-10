import SwiftUI

enum EOMText: Hashable {
    case mono(text: String, terminator: String = "")
    case text(text: String, terminator: String = "")
    case title(text: String)
    case game(Games)
    case div
}

enum Games: Hashable {
    case program(String)
}

struct HistoryOfPL: View {
    let text: [EOMText] = [
        .text(text: "This is NOT a tutorial", terminator: "\n"),
        .text(text: "If you were expected a tutorial, then click the 'Learn EOM' button."),
        .text(text: "Otherwise, enjoy!"),
        .div,
        .title(text: "The Fundamental Pillar behind Programming Languages"),
        .text(text: ""),
        .text(text: "We've all used something that uses a language, whether that be smart light switch, an Alexa, an iPad, or any device that runs something important. Programming languages are at the heart of technology of all to come.\n\nBut how did languages like Python, Swift, or Java came to be?\n\nWell... go back to the 1950s. World War II has ended for nearly a decade, and on this year, 1954, the first popular and high-level language was made- FORTRAN. It was small, it was cute, but it packed a punch.\n\nOriginally used to code IBM computers (very popular at that time), it was able to loop through data, branch (a fancy word for if this then that), and was able to be ran VERY effeciently. Even though it was a small programming language, it took over as the default for the tech industry. It was praised for its simplicity, and became the go-to for a lot of computation, even if it was not that much at the time. Now, nearly 70 years after its creation, FORTRAN is still used for its original purpose."),
        .div,
        .title(text: "How a Language Lowered the Bar"),
        .text(text: ""),
        .text(text: "After people had comfortably gotten used to FORTRAN, everything quietly settled down; except for one college.\n\nDartmouth College was a lot smaller in 1964; an all-men school with around 3450 members. However, two men- John G. Kemeny and Thomas E. Kurtz- had a belief in mind. They believed that everyone- even beginners- can make programs, no matter how experienced or unexperienced you are. After tinkering and testing, they created BASIC (Beginner's All-purpose Symbolic Instruction Code). BASIC had a very comfortable syntax. In fact, even more readable than FORTRAN. It used english words like 'PRINT' and didn't need a 24-hour delay like most programmers needed to do at the time. "),
        .div,
        .text(text: "Code a 'Hello, World!' program in BASIC!", terminator: ""),
        .game(.program("""
            10 PRINT "Hello, World!"
            20 END
            """)),
        .div,
        .title(text: "The Race on High-Level Languages Begins"),
        .text(text: ""),
        .text(text: " It's a bright sunny day in the 1970s. A developer at Bell Labs, Dennis Ritchie, makes one of the most influential programming languages: C."),
        .text(text: "It started small- a few dozen people who used it, then hundreds tinkered with it, then thousands. Then it blew up."),
        .text(text: "C's main purpose was to build Unix. In short, Unix was designed for managing hardware and programs. But as it started to blow up, it was used everywhere. One of the most useful part of C was that it was high-level (at its time), but it allowed you to interact with the bare metal of computers. It was lightweight, yet powerful. With these abilities, it was used for a LOT of operating system. In fact, Apple OSs (iOS, macOS, iPadOS, etc) and Windows mostly uses C.")
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(text, id: \.self) { t in
                    switch t {
                    case .mono(text: let text, terminator: let terminator):
                        Text(text + terminator)
                            .font(.system(size: 15, design: .monospaced))
                            .padding(.leading)
                    case .text(text: let text, terminator: let terminator):
                        Text(text + terminator)
                            .font(.system(size: 15))
                            .padding(.leading)
                    case .title(text: let text):
                        Text(text)
                            .bold()
                            .font(.system(size: 30))
                            .padding(.leading)
                    case .game(let game):
                        switch game {
                        case .program(let string):
                            ProgramGame(checkingText: string)
                                .clipShape(RoundedRectangle(cornerSize: CGSize(width: 15, height: 15)))
                                .padding()
                        }
                    case .div:
                        Divider()
                    }
                }
            }
        }
    }
}

#Preview {
    HistoryOfPL()
}
