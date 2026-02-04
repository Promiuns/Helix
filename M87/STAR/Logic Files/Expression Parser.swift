import Darwin
internal import Combine

indirect enum Node {
	case null(ParserTimeType)
    case intermediateType(String)
    case type(Type)
    case infix(op: Node, num1: Node, num2: Node?)
    case number(Double)
    case id(String)
    case add
    case subtract(minusDisambiguation)
    case multiply
    case divide
    case equals
    case notEquals
    case greater
    case less
    case greaterEqual
    case lessEqual
    case not
    case and
    case or
    case dot(dotDisambiguation)
    case leftParenthesis(parenthesisDisambiguation)
    case rightParenthesis
    case leftSquare
    case rightSquare
    case arrow
    case comma
    case string(String)
    case boolean(Bool)
    case array([Node])
    case fallback(String)
    case function(String, [Node])
    case filler
    case `struct`(String, [Node])
    case create
    case emparr
    case mod
    
    var text: String {
        switch self {
		case .null:
			return "null"
        case .intermediateType(let str):
            return str
        case .number(let num):
            return "\(num)"
        case .id(let id):
            return "\(id)"
        case .add:
            return "+"
        case .subtract(let type):
            switch type {
            case .notKnown:
                return "NK"
            case .unaryMinus:
                return "-u"
            case .binaryMinus:
                return "-b"
            }
        case .multiply:
            return "*"
        case .divide:
            return "/"
        case .equals:
            return "=="
        case .notEquals:
            return "!="
        case .greater:
            return ">"
        case .less:
            return "<"
        case .greaterEqual:
            return ">="
        case .lessEqual:
            return "<="
        case .not:
            return "!"
        case .dot(let dot):
            switch dot {
            case .notKnown:
                return "NK"
            case .memberDot:
                return ".m"
            case .numberDot:
                return ".n"
            }
        case .create:
            return "create"
        case .leftParenthesis(let paren):
            switch paren {
            case .notKnown:
                return "NK"
            case .callParen:
                return "(c"
            case .groupParen:
                return "(g"
            }
        case .rightParenthesis:
            return ")"
        case .comma:
            return ","
        case .string(let str):
            return str
        case .boolean(let bool):
            return bool.description
        case .array(let arr):
            return (arr.map { $0.text }).joined(separator: ", ")
        case .and:
            return "&&"
        case .or:
            return "||"
        case .fallback(let str):
            return str
        case .function(let name, let args):
            return name + ": \((args.map { $0.text }).joined(separator: ", "))"
        case .infix(op: let op, num1: let num1, num2: let num2):
            return "\(num1) \(op) \(num2, default: "")"
        case .filler:
            return "NUD"
        case .leftSquare:
            return "["
        case .rightSquare:
            return "]"
        case .struct(let name, let args):
            return name + ": \((args.map { $0.text }).joined(separator: ", "))"
        case .arrow:
            return "->"
        case .mod:
            return "%"
        case .emparr:
            return "emparr"
        case .type(let type):
            return type.desc()
        }
    }
}

extension Node {
    static func ==(left: Node, right: Node) -> Bool {
        return left.text == right.text
    }
}

enum ParserErrors: Error, CustomStringConvertible {
    case parserTypeMismatch
    case parserNotKnown
    
    var description: String {
        switch self {
        case .parserNotKnown:
            return "Parser cannot determine "
        case .parserTypeMismatch:
            return "Parser used incorrect type "
        }
    }
}

enum minusDisambiguation: CustomStringConvertible {
    case binaryMinus
    case unaryMinus
    case notKnown
    
    var description: String {
        switch self {
        case .binaryMinus:
            return "-b"
        case .unaryMinus:
            return "-u"
        case .notKnown:
            return "NK"
        }
    }
}

enum dotDisambiguation: CustomStringConvertible {
    case numberDot
    case memberDot
    case notKnown
    
    var description: String {
        switch self {
        case .numberDot:
            return ".n"
        case .memberDot:
            return ".m"
        case .notKnown:
            return "NK"
        }
    }
}

enum parenthesisDisambiguation: CustomStringConvertible {
    case callParen
    case groupParen
    case notKnown
    
    var description: String {
        switch self {
        case .callParen:
            return "(c"
        case .groupParen:
            return "(g"
        case .notKnown:
            return "NK"
        }
    }
}

final class ExpressionParser: ObservableObject {
    let tokens: [Token]
    let lexer = Lexer()
    init(tokens: [Token] = []) {
        self.tokens = tokens
    }
    
    @discardableResult
    func parseExpression(expression: String, index: Int) throws -> Node {
        let t = try lexer.lexer(plaintext: expression)
        func binary_or_unary(lastTerm: Token?) -> minusDisambiguation {
            /*
             -u is when you use it after a token thats used to normally delimit tokens (operators and left parenthesis)
             for example 5 - 3 is -b because 5 does not delimit a token
             4 + (-5) is -u because ( delimits the 4
             rule of thumb: if the last token delimits, its unary
             */
            guard let lastTerm = lastTerm else {
                return .unaryMinus
            }
            
            switch lastTerm.type {
            case .op, .lParen, .lSquare:
                switch lastTerm.text {
                case "&&", "||", "!":
                    return .notKnown
                default:
                    return .unaryMinus
                }
            case .numLiteral, .identifier, .rParen:
                return .binaryMinus
            default:
                return .notKnown
            }
        }
        
        func number_or_member(lastTerm: Token, nextTerm: Token, dotUsage: inout Int) -> dotDisambiguation {
            defer {
                dotUsage += 1
            }
            if lastTerm.type == .identifier && nextTerm.type == .identifier {
                return .memberDot
            }
            
            if lastTerm.type == .numLiteral && nextTerm.type == .numLiteral && dotUsage == 0 {
                return .numberDot
            }
            return .notKnown
        }
        
        func call_or_group(lastTerm: Token?) -> parenthesisDisambiguation {
            guard let lastTerm = lastTerm else {
                return .groupParen
            }
            
            switch lastTerm.type {
			case .identifier, .type, .keyword:
                return .callParen
            case .op, .lParen:
                return .groupParen
            default:
                return .notKnown
            }
        }
        
        var temp: [Node] = []
        var dotUsage = 0
        // MARK: normalization part
        for index in t.indices {
            let current = t[index]
            let last: Token? = index - 1 >= 0 ? t[index - 1] : nil
            let next: Token? = index + 1 < t.count ? t[index + 1] : nil
            switch (current.text, current.type) {
			case ("null", .keyword):
				temp.append(.id("null"))
            case ("create", .keyword):
                temp.append(.create)
            case (let num, .numLiteral):
                temp.append(.number(Double(num)!))
            case (let str, .strLiteral):
                temp.append(.string(str))
            case (let bool, .boolLiteral):
                temp.append(.boolean(bool == "true" ? true : (bool == "false" ? false : false)))
            case (_, .comma):
                temp.append(.comma)
            case (_, .dot):
                if let next = next, let last = last, number_or_member(lastTerm: last, nextTerm: next, dotUsage: &dotUsage) != .notKnown {
                    dotUsage -= 1
                    temp.append(.dot(number_or_member(lastTerm: last, nextTerm: next, dotUsage: &dotUsage)))
                    if number_or_member(lastTerm: last, nextTerm: next, dotUsage: &dotUsage) != .numberDot {
                        dotUsage = 0
                    }
                }
            case (let op, .op):
                switch op {
                case "+":
                    temp.append(.add)
                case "-":
                    temp.append(.subtract(binary_or_unary(lastTerm: last)))
                case "*":
                    temp.append(.multiply)
                case "/":
                    temp.append(.divide)
                case "!":
                    temp.append(.not)
                case "==":
                    temp.append(.equals)
                case "!=":
                    temp.append(.notEquals)
                case ">=":
                    temp.append(.greaterEqual)
                case "<=":
                    temp.append(.lessEqual)
                case ">":
                    temp.append(.greater)
                case "<":
                    temp.append(.less)
                case "&&":
                    temp.append(.and)
                case "||":
                    temp.append(.or)
                case "->":
                    temp.append(.arrow)
                case "%":
                    temp.append(.mod)
                default:
                    temp.append(.fallback(op))
                }
            case (let str, .type):
                temp.append(.intermediateType(str))
            case (_, .lParen):
                temp.append(.leftParenthesis(call_or_group(lastTerm: last)))
            case (_, .rParen):
                temp.append(.rightParenthesis)
            case (let id, .identifier):
                temp.append(.id(id))
            case (_, .lSquare):
                temp.append(.leftSquare)
            case (_, .rSquare):
                temp.append(.rightSquare)
            case (let text, _):
                temp.append(.fallback(text))
            }
        }
        var numberStack: [Node] = []
        var operatorStack: [Node] = []
        
        for element in try resolveCallOrCreateParentheses(try resolveTypes(temp)) {
            switch element {
			case .null(_):
				numberStack.append(element)
            case .create:
                break
            case .number(_):
                numberStack.append(element)
            case .id(_):
                numberStack.append(element)
            case .add:
                operatorStack.append(element)
            case .subtract(let minusDisambiguation):
                switch minusDisambiguation {
                case .binaryMinus:
                    operatorStack.append(element)
                case .unaryMinus:
                    numberStack.append(element)
                case .notKnown:
                    return .filler
                }
            case .multiply:
                operatorStack.append(element)
            case .divide:
                operatorStack.append(element)
            case .mod:
                operatorStack.append(element)
            case .equals:
                operatorStack.append(element)
            case .notEquals:
                operatorStack.append(element)
            case .greater:
                operatorStack.append(element)
            case .less:
                operatorStack.append(element)
            case .greaterEqual:
                operatorStack.append(element)
            case .lessEqual:
                operatorStack.append(element)
            case .not:
                operatorStack.append(element)
            case .and:
                operatorStack.append(element)
            case .or:
                operatorStack.append(element)
            case .arrow:
                operatorStack.append(element)
            case .dot(_):
                operatorStack.append(element)
            case .leftParenthesis(let parenthesisDisambiguation):
                switch parenthesisDisambiguation {
                case .callParen:
                    return .filler
                case .groupParen:
                    operatorStack.append(element)
                    numberStack.append(element)
                case .notKnown:
                    return .filler
                }
            case .rightParenthesis:
                operatorStack.append(element)
                numberStack.append(element)
            case .comma:
                operatorStack.append(element)
            case .string(_):
                numberStack.append(element)
            case .boolean(_):
                numberStack.append(element)
            case .array(_):
                numberStack.append(element)
            case .fallback(_):
                return .filler
            case .function(_, _):
                numberStack.append(element)
            case .filler:
                return .filler
            case .infix(op: _, num1: _, num2: _):
                return .filler
            case .leftSquare:
                operatorStack.append(element)
                numberStack.append(element)
            case .rightSquare:
                operatorStack.append(element)
                numberStack.append(element)
            case .struct(let strName, let strArg):
                numberStack.append(.struct(strName, strArg))
            case .emparr:
                numberStack.append(.emparr)
            case .type(let T):
                numberStack.append(.type(T))
            case .intermediateType(_):
                break
            }
        }
        // MARK: - PASS 1: Resolve types
        
        func resolveTypes(_ nodes: [Node]) throws -> [Node] {
            
			func resolveOneType(_ nodes: [Node]) throws -> Type {
				/// assume the parameter `nodes` is the type as `[Node]` form
				/// if we had something like `array(optional(number))`, we should get `[array, optional, string]`
				var types: [String] = []
				for node in nodes {
					switch node {
					case .intermediateType(let strType):
						types.append(strType)
					default:
						()
					}
				}
				
				func constructType(currentlyConstructed: inout Type?, idx: Int) throws {
					guard types.indices.contains(idx) else {
						throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
					}
					if idx == 0 {
						switch types[0] {
						case "number":
							currentlyConstructed = .number
						case "string":
							currentlyConstructed = .string
						case "boolean":
							currentlyConstructed = .boolean
						case "void":
							currentlyConstructed = .void
						case "array":
							guard let c = currentlyConstructed else {
								throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
							}
							currentlyConstructed = .array(c)
						case "optional":
							guard let c = currentlyConstructed else {
								throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
							}
							currentlyConstructed = .optional(c)
							
						default:
							throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
						}
						return
					}
					let currentType = types[idx]
					switch currentType {
					case "number":
						currentlyConstructed = .number
					case "string":
						currentlyConstructed = .string
					case "boolean":
						currentlyConstructed = .boolean
					case "void":
						currentlyConstructed = .void
					case "array":
						guard let c = currentlyConstructed else {
							throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
						}
						currentlyConstructed = .array(c)
					case "optional":
						guard let c = currentlyConstructed else {
							throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
						}
						currentlyConstructed = .optional(c)
					default:
						throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
					}
					try constructType(currentlyConstructed: &currentlyConstructed, idx: idx - 1)
				}
				
				var constructingType: Type? = nil
				try constructType(currentlyConstructed: &constructingType, idx: types.count - 1)
				guard let constructedType = constructingType else {
					throw ErrorInformation(error: .expressionParserError(.parserTypeMismatch), line: index)
				}
				return constructedType
			}
			
			var runthrough = 0
			var stack: [Node] = []
			while runthrough < nodes.count {
				if case .intermediateType(let type) = nodes[runthrough] {
					switch type {
					case "number", "string", "boolean", "void":
						stack.append(.type(try resolveOneType([nodes[runthrough]])))
					case "array":
						guard let rightParenthesis = try searchCorresponding(starter: [.leftParenthesis(.callParen), .leftParenthesis(.groupParen)], end: [.rightParenthesis], tokens: nodes, startingIndex: runthrough+1) else {
							throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
						}
						stack.append(.type(try resolveOneType(Array(nodes[runthrough...rightParenthesis]))))
						runthrough = rightParenthesis + 1
						continue
					case "optional":
						guard let rightParenthesis = try searchCorresponding(starter: [.leftParenthesis(.callParen), .leftParenthesis(.groupParen)], end: [.rightParenthesis], tokens: nodes, startingIndex: runthrough+1) else {
							throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
						}
						stack.append(.type(try resolveOneType(Array(nodes[runthrough...rightParenthesis]))))
						runthrough = rightParenthesis + 1
						continue
					default:
						throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
					}
				} else {
					stack.append(nodes[runthrough])
				}
				runthrough += 1
			}
			print(stack)
			return stack
        }
        
        
        // MARK: - PASS 2: Resolve function calls:  foo(c ... )
        // Turns:  [.id("foo"), .leftParenthesis(.callParen), ...args..., .rightParenthesis]
        // Into:   [.function("foo", [arg1Node, arg2Node, ...])]
        func resolveCallOrCreateParentheses(_ nodes: [Node]) throws -> [Node] {
			print(nodes)
            var result: [Node] = []
            var i = 0
            var creatingStruct = false

            while i < nodes.count {
                if case .create = nodes[i] {
                    creatingStruct.toggle()
                    i += 1
                    continue
                }
                if i + 1 < nodes.count,
                   case .id(let name) = nodes[i],
                   case .leftParenthesis(.callParen) = nodes[i + 1] {
                    guard let end = try searchCorresponding(
                        starter: [.leftParenthesis(.callParen), .leftParenthesis(.groupParen)],
                        end: [.rightParenthesis],
                        tokens: nodes,
                        startingIndex: i + 1
                    ) else {
                        throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
                    }

                    let argNodes = Array(nodes[(i + 2)..<end])

                    let argSlices = splitByComma(argNodes)
                    let parsedArgs = try argSlices.map { try parseNodePipeline($0) }
                    if creatingStruct {
                        result.append(.struct(name, parsedArgs))
                        creatingStruct.toggle()
                    } else {
						print("weweweweweweweweewewewewewewewewewewewewewewewew")
						if name == "null" {
							guard parsedArgs.count == 1 else {
								throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
							}
							result.append(.null(parseType(typeString: parsedArgs.first!.text, line: index)))
						} else if name == "id" {
							guard parsedArgs.count == 1 else {
								throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
							}
							result.append(.id(parsedArgs.first!.text))
						} else {
							result.append(.function(name, parsedArgs))
						}
						
                    }
                    i = end + 1
                } else {
                    result.append(nodes[i])
                    i += 1
                }
            }
            return result
        }
        func splitByComma(_ nodes: [Node]) -> [[Node]] {
            var res: [[Node]] = []
            var current: [Node] = []

            var parenDepth = 0
            var squareDepth = 0

            for node in nodes {
                switch node {
                case .leftParenthesis: parenDepth += 1
                case .rightParenthesis: parenDepth -= 1
                case .leftSquare: squareDepth += 1
                case .rightSquare: squareDepth -= 1
                default: break
                }

                if parenDepth == 0, squareDepth == 0, case .comma = node {
                    res.append(current)
                    current = []
                } else {
                    current.append(node)
                }
            }

            if !current.isEmpty { res.append(current) }
            return res
        }

        // MARK: - PASS 3: Resolve grouping parentheses: (g ... )
        // Turns:  [.leftParenthesis(.groupParen), ...expr..., .rightParenthesis]
        // Into:   [subtreeNode]
        func resolveGroupParentheses(_ nodes: [Node]) throws -> [Node] {
            var result: [Node] = []
            var i = 0

            while i < nodes.count {
                let cur = nodes[i]

                if case .leftParenthesis(.groupParen) = cur {
                    guard let end = try searchCorresponding(
                        starter: [.leftParenthesis(.groupParen), .leftParenthesis(.callParen)],
                        end: [.rightParenthesis],
                        tokens: nodes,
                        startingIndex: i
                    ) else {
                        throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
                    }

                    let inner = Array(nodes[(i + 1)..<end])
                    print(inner)
                    let subtree = try parseNodePipeline(inner)

                    result.append(subtree)
                    i = end + 1
                    continue
                }

                // If any raw parens remain here, it's an error
                if case .rightParenthesis = cur {
                    throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
                }

                result.append(cur)
                i += 1
            }

            return result
        }

        // MARK: - PASS 4: Resolve arrays ([a, b, c, [d, e, f]])
        func resolveArrayLiterals(_ nodes: [Node]) throws -> [Node] {
            var result: [Node] = []
            var index = 0

            while index < nodes.count {
                let current = nodes[index]

                if case .leftSquare = current {
                    guard let end = try searchCorresponding(
                        starter: [.leftSquare],
                        end: [.rightSquare],
                        tokens: nodes,
                        startingIndex: index
                    ) else {
                        throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
                    }
                    let inner = Array(nodes[(index + 1)..<end])

                    // Empty array: []
                    if inner.isEmpty {
                        result.append(.array([]))
                        index = end + 1
                        continue
                    }

                    // split by commas at depth 0, then parse each element via full pipeline
                    let parts = splitByComma(inner)
                    let elements = try parts.map { part -> Node in
                        if part.isEmpty { throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index) } // trailing comma / ,, etc
                        return try parseNodePipeline(part)
                    }

                    result.append(.array(elements))
                    index = end + 1
                } else {
                    result.append(current)
                    index += 1
                }
            }

            return result
        }
        
        // MARK: - Full pipeline on already-normalized [Node]
        // (Call-parens first, then group-parens, then precedence)
        func parseNodePipeline(_ nodes: [Node]) throws -> Node {
			let typesResolved = try resolveTypes(nodes)
            let callsResolved  = try resolveCallOrCreateParentheses(typesResolved)
            let groupsResolved = try resolveGroupParentheses(callsResolved)
            let arraysResolved = try resolveArrayLiterals(groupsResolved)
            return try parseNodeList(arraysResolved)
        }

        // MARK: - Split by commas at top-level, ignoring commas inside parentheses
        // Works because nodes still contain (g/(c and ) before we collapse them.
        func splitTopLevel(_ nodes: [Node], separator: Node) -> [[Node]] {
            var parts: [[Node]] = []
            var current: [Node] = []
            var depth = 0

            func isLeftParen(_ n: Node) -> Bool {
                if case .leftParenthesis = n { return true }
                return false
            }

            func isRightParen(_ n: Node) -> Bool {
                if case .rightParenthesis = n { return true }
                return false
            }

            for n in nodes {
                if isLeftParen(n) { depth += 1 }
                if isRightParen(n) { depth -= 1 }

                if depth == 0 {
                    if case .comma = n {
                        parts.append(current)
                        current = []
                        continue
                    }
                }

                current.append(n)
            }

            parts.append(current)
            return parts
        }

        // MARK: - Precedence merge (works on a flat list with NO parens)
        func parseNodeList(_ nodes: [Node]) throws -> Node {
            // No parentheses should exist here
            for n in nodes {
                if case .leftParenthesis = n { throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index) }
                if case .rightParenthesis = n { throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index) }
                if case .comma = n { throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index) }
            }

            var numberStack: [Node] = []
            var operatorStack: [Node] = []

            for element in nodes {
                switch element {
				case .number, .id, .string, .boolean, .array, .function, .struct, .type, .null:
                    numberStack.append(element)

                // unary operators live in numberStack in your design
                case .subtract(.unaryMinus), .not:
                    numberStack.append(element)

                case .add, .subtract(.binaryMinus), .multiply, .divide,
                     .equals, .notEquals, .greater, .greaterEqual,
                     .less, .lessEqual, .and, .or, .dot, .arrow, .mod:
                    operatorStack.append(element)
                    
                case .infix(op: _, num1: _, num2: _):
                    numberStack.append(element)

                default:
                    throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
                }
            }
            print(numberStack)
            if numberStack.count == 1 {
                print("ENTERED")
                return numberStack.first!
            } else {
                let precedence: [String: Int] = [
                    ".m": 6, ".n": 6,
                    "-u": 5, "!": 5,
                    "*": 4, "/": 4, "%": 4,
                    "+": 3, "-b": 3,
                    "->": 1,
                    "==": 1, "!=": 1, ">": 1, "<": 1, ">=": 1, "<=": 1,
                    "&&": 0, "||": 0
                ]
                // Merge highest -> lowest
                for level in stride(from: 6, through: 0, by: -1) {
                    var i = 0
                    while i < operatorStack.count {
                        let op = operatorStack[i]
                        if precedence[op.text] == level {

                            // Unary operators should never be in operatorStack in architecture
                            if op.text == "-u" || op.text == "!" {
                                throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
                            }

                            // Binary merge
                            guard i < numberStack.count - 1 else { throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index) }

                            let node = Node.infix(op: op, num1: (numberStack.filter { precedence[$0.text] != 4 })[i], num2: numberStack[i + 1])
                            numberStack.remove(at: i + 1)
                            numberStack[i] = node
                            operatorStack.remove(at: i)

                            continue // do not do i += 1, because we removed at i
                        }

                        i += 1
                    }

                    // handle unary at this precedence level (4) by scanning numberStack
                    if level == 4 {
                        var j = 0
                        while j < numberStack.count {
                            let n = numberStack[j]
                            if n.text == "-u" || n.text == "!" {
                                guard j + 1 < numberStack.count else { throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index) }
                                let prefix = Node.infix(op: n, num1: numberStack[j + 1], num2: nil)
                                numberStack.remove(at: j + 1)
                                numberStack[j] = prefix
                                continue
                            }
                            j += 1
                        }
                    }
                }
                guard numberStack.count == 1 else {
                    throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
                }
                
                return numberStack.first ?? .filler
            }
        }
        return try parseNodePipeline(temp)
    }
    
    func searchCorresponding(starter: [Node], end: [Node], tokens: [Node], startingIndex: Int = 0) throws -> Int? {
        var depth = 0
        var index = startingIndex
        let starterString = starter.map { $0.text }
        let endString = end.map { $0.text }
        for token in tokens[startingIndex...] {
            let text = token.text
            if starterString.contains(text) {
                depth += 1
            } else if endString.contains(text) {
                depth -= 1
            }
            guard depth > 0 else {
                return index
            }
            guard tokens.count > index else {
                throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
            }
            index += 1
        }
        
        return nil
    }
    
    func mapOperator(_ node: Node, index: Int) throws -> Operators {
        switch node {
        case .add:
            return .add
        case .subtract(.binaryMinus):
            return .subtract
        case .subtract(.unaryMinus):
            return .uMinus
        case .multiply:
            return .multiply
        case .divide:
            return .divide
        case .equals:
            return .equal
        case .notEquals:
            return .notEqual
        case .greater:
            return .greaterThan
        case .greaterEqual:
            return .greaterThanOrEqual
        case .less:
            return .lessThan
        case .lessEqual:
            return .lessThanOrEqual
        case .and:
            return .and
        case .or:
            return .or
        case .not:
            return .not
        case .arrow:
            return .arrow
        case .mod:
            return .mod
        default:
            throw ErrorInformation(error: .expressionParserError(.parserNotKnown), line: index)
        }
    }
    
    func lower(_ node: Node, index: Int) throws -> Expression {
		print("FNewfhewuwhrwueihruewhruehwreuwirhueiwrehwiruewh", node)
        switch node {
        case .type(let T):
            return .type(T)
        case .number(let n):
            return .number(n)

        case .string(let s):
            return .string(String(s.dropFirst().dropLast()))

        case .boolean(let b):
            return .boolean(b)
			
		case .null(let nullType):
			return .null(nullType)
			
        case .id(let name):
            return .variable(name, line: index)
        case .array(let nodes):
            return .array(try nodes.map { try lower($0, index: index) })
        case .function(let name, let args):
            return .call_function(
                name: .variable(name, line: index),
                arguments: try args.map { try lower($0, index: index) }, line: index
            )
        case .struct(let id, _):
            return .structure(name: id)
        case .infix(op: .dot(.memberDot), num1: let base, num2: let member?):
            if case .id(let memberName) = member {
                return .dot(
                    structName: try lower(base, index: index),
                    member: memberName, args: nil, line: index
                )
            } else if case .function(let memberName, let args) = member {
                return .dot(
                    structName: try lower(base, index: index),
                    member: memberName, args: try args.map { try lower($0, index: index) }, line: index
                )
            } else {
                throw ParserErrors.parserTypeMismatch
            }

            
        case .infix(op: .dot(.numberDot), num1: let integer, num2: let decimal):
            guard let decimal = decimal, case .number(let int) = integer, case .number(let dec) = decimal else {
                throw ParserErrors.parserTypeMismatch
            }
            
            return .number(int + pow(10.0, Double(String(Int(dec)).count * -1)) * dec)
        case .infix(op: let op, num1: let expr, num2: nil):
            let mapped = try mapOperator(op, index: index)
            return .operation(
                op: mapped,
                val1: try lower(expr, index: index),
                val2: nil, line: index
            )
        case .infix(op: let op, num1: let lhs, num2: let rhs?):
            let mapped = try mapOperator(op, index: index)
            return .operation(
                op: mapped,
                val1: try lower(lhs, index: index),
                val2: try lower(rhs, index: index), line: index
            )
        default:
            throw ParserErrors.parserNotKnown
        }
    }
}
