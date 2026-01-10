enum HistoryAchievement: Hashable, CaseIterable {
    // Foundations
    case firstProgram
    case firstQuizCompleted

    // Early languages
    case understandsFortran
    case understandsBasic

    // Systems & paradigms
    case understandsC
    case understandsCpp
    case understandsProlog
    case understandsObjectiveC

    // Concepts
    case recognizesPatterns
    case usesTimeline

    // Modern languages
    case understandsPython
    case understandsJava
    case understandsPHP
    case understandsCSharp

    // Modern era
    case understandsSwift
    case understandsGo
    case understandsZig

    // Completion
    case finalChallengeCompleted
}

struct Achievement: CustomStringConvertible {
    let string: String
    let achievement: HistoryAchievement
    var description: String {
        switch achievement {
        case .firstProgram:
            "Made their first program"
        case .firstQuizCompleted:
            "Finished their first quiz"
        case .understandsFortran:
            "Understands FORTRAN"
        case .understandsBasic:
            "Understands BASIC"
        case .understandsC:
            "Understands C"
        case .understandsCpp:
            "Understands C++"
        case .understandsProlog:
            "Understands Prolog"
        case .understandsObjectiveC:
            "Understands Obj-C"
        case .recognizesPatterns:
            "---"
        case .usesTimeline:
            "Can use timelines"
        case .understandsPython:
            "Understands Python"
        case .understandsJava:
            "Understands Java"
        case .understandsPHP:
            "Understands PHP"
        case .understandsCSharp:
            "Understands C#"
        case .understandsSwift:
            "Understands Swift"
        case .understandsGo:
            "Understands Go"
        case .understandsZig:
            "Understands Zig"
        case .finalChallengeCompleted:
            "Completed the final challenge"
        }
    }
}
