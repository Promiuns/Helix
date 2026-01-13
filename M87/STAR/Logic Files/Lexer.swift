import Foundation

enum TokenType {
    case keyword
    case identifier
    case lParen
    case rParen
    case lSquare
    case rSquare
    case lbrace
    case rbrace
    case strLiteral
    case numLiteral
    case boolLiteral
    case op
    case dot
    case comma
    case semicolon
    case colon
    case newline
    case doubleArrow
}

struct Token: Hashable {
    let text: String
    let type: TokenType
}

enum LexerError: Error {
    case unterminatedString
    case invalidCharacter
}

final class Lexer {
        func lexer(plaintext: String) throws -> [Token] {
            var i = 0
            var line = 1
            var currentToken = ""
            var inQuotes = false
            var currentTokens: [Token] = []
            let opSet: Set<String> = [
                "+", "-", "*", "=", "/", ".", "!", "==", "&", "|", "!=", ">", "<", ">=", "<=", ",", "[", "]", "{", "}", "(", ")", "->", "&&", "||", ";", ":", "\n", "=>"
            ]
            let keywords: Set<String> = [
                "var", "if", "for", "while", "struct", "copy", "let", "else", "create", "in", "fn", "return"
            ]
            func tokenType(string: String) -> Token {
                switch string {
                case "+", "-", "*", "=", "/", "!", "==", "!=", ">", "<", ">=", "<=", "&&", "||", "->":
                    return Token(text: string, type: .op)
                case "\n":
                    line += 1
                    return Token(text: string, type: .newline)
                case ",":
                    return Token(text: string, type: .comma)
                case ".":
                    return Token(text: string, type: .dot)
                case "[":
                    return Token(text: string, type: .lSquare)
                case "]":
                    return Token(text: string, type: .rSquare)
                case "(":
                    return Token(text: string, type: .lParen)
                case ")":
                    return Token(text: string, type: .rParen)
                case "{":
                    return Token(text: string, type: .lbrace)
                case "}":
                    return Token(text: string, type: .rbrace)
                case ";":
                    return Token(text: string, type: .semicolon)
                case ":":
                    return Token(text: string, type: .colon)
                case "=>":
                    return Token(text: string, type: .doubleArrow)
                case _ where Int(string) != nil:
                    return Token(text: string, type: .numLiteral)
                case "true", "false":
                    return Token(text: string, type: .boolLiteral)
                case _ where keywords.contains(string):
                    return Token(text: string, type: .keyword)
                default:
                    return Token(text: string, type: .identifier)
                }
            }
            while i < plaintext.count {
                let elem = String(plaintext[plaintext.index(plaintext.startIndex, offsetBy: i)])
                switch elem {
                case "\"":
                    if inQuotes {
                        currentTokens.append(Token(text: "\"" + currentToken + "\"", type: .strLiteral))
                        currentToken = ""
                    }
                    inQuotes.toggle()
                    i += 1
                    continue
                case _ where inQuotes:
                    currentToken += elem
                    i += 1
                    continue
                case _ where elem.trimmingCharacters(in: .whitespaces).isEmpty:
                    currentTokens.append(tokenType(string: currentToken))
                    currentToken = ""
                    i += 1
                    continue
                case let char where opSet.firstIndex(of: char) != nil: // a character thats in the op set
                    if opSet.contains(char) {
                        if i+1 < plaintext.count {
                            let peek = String(plaintext[plaintext.index(plaintext.startIndex, offsetBy: i+1)])
                            if opSet.contains(char + peek) {
                                currentTokens.append(tokenType(string: currentToken))
                                currentTokens.append(tokenType(string: char + peek))
                                currentToken = ""
                                i += 2
                                continue
                            }
                        }
                        currentTokens.append(tokenType(string: currentToken))
                        currentTokens.append(tokenType(string: char))
                        currentToken = ""
                        i += 1
                        continue
                    }
                    
                    
                default:
                    currentToken += elem
                    i += 1
                }
            }
            if !currentToken.isEmpty {
                currentTokens.append(tokenType(string: currentToken))
            }
            guard !inQuotes else {
                throw LexerError.unterminatedString
            }
            return currentTokens.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        }
}
