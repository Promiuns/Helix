internal import Combine

enum ExpressionOrFunction {
    case expr(Expression)
    case function(Value)
}
struct StructMemberBinding {
    let bindingType: BindingType
    let expr: ExpressionOrFunction
    let type: ParserTimeType
}

struct ParserStructData {
    let name: String
    var values: [String: StructMemberBinding] = [:]
}

enum StatementError: Error, CustomStringConvertible {
    case didNotSpecifyType
    case noTermination
    case unknownStatement
    case noBraceStarter
    case noBodyToExecute
    case doesntHave(String)
    case incompleteStatement
    case incorrectExpression
    case general(String)
    
    var description: String {
        switch self {
        case .didNotSpecifyType:
            return "Did not specify type "
        case .noTermination:
            return "Did not terminate "
        case .unknownStatement:
            return "Does not exist "
        case .noBraceStarter:
            return "Did not start block "
        case .noBodyToExecute:
            return "There is nothing to execute"
        case .doesntHave(let str):
            return "Does not have keyword \(str) "
        case .incompleteStatement:
            return "Is incomplete "
        case .incorrectExpression:
            return "Has an incorrect expression "
        case .general(let str):
            return " \(str) "
        }
    }
}

final class StatementParser: ObservableObject {
    let lexer = Lexer()
    let parser = ExpressionParser()

    func statement_parse(paintext: String) throws -> [Statement] {
        let tokens = try lexer.lexer(plaintext: paintext)
        let lines = normalize(lines: tokens)

        var statements: [Statement] = []
        var index = 0
        print(lines)
        while index < lines.count {
            let line = lines[index]
            guard let keyword = line.first else {
                index += 1
                continue
            }

            switch keyword {

            case Token(text: "return", type: .keyword):
                statements.append(try parseReturn(line: line, index: index))
                index += 1

            case Token(text: "let", type: .keyword):
                statements.append(try letDeclaration(line: line, index: index))
                index += 1

            case Token(text: "var", type: .keyword):
                statements.append(try varDeclaration(line: line, index: index))
                index += 1

            case Token(text: "if", type: .keyword):
                let parsed = try parseIf(line: line, body: lines, index: index)
                statements.append(parsed.statement)
                index += parsed.consumed

            case Token(text: "while", type: .keyword):
                let parsed = try parseWhile(line: line, body: lines, index: index)
                statements.append(parsed.statement)
                index += parsed.consumed

            case Token(text: "for", type: .keyword):
                let parsed = try parseFor(line: line, body: lines, index: index)
                statements.append(parsed.statement)
                index += parsed.consumed

            case Token(text: "fn", type: .keyword):
                let parsed = try functionDeclaration(line: line, body: lines, index: index)
                statements.append(parsed.statement)
                index += parsed.consumed
                
            case Token(text: "struct", type: .keyword):
                let parsed = try parseStructs(line: line, body: lines, index: index)
                statements.append(parsed.statement)
                index += parsed.consumed

            case let tok where tok.type == .identifier:
                if line.contains(Token(text: "=", type: .op)) {
                    let parsed = try assignment(line: line, index: index)
                    statements.append(parsed)
                    index += 1
                    continue
                }
                let exprSource = line.map(\.text).joined(separator: " ")
                let expr = try parser.lower(
                    try parser.parseExpression(expression: exprSource, index: index),
                    index: index
                )
                statements.append(.expr(expr, line: index))
                index += 1
            case Token(text: "{", type: .lbrace), Token(text: "}", type: .rbrace):
                index += 1
                continue
            default:
                throw ErrorInformation(error: .statementParserError(.unknownStatement), line: index)
            }
        }
        return statements
    }

    // MARK: - BRANCHING STATEMENTS

    func parseIf(line: [Token], body: [[Token]], index: Int) throws -> (statement: Statement, consumed: Int) {
        // 1️⃣ Parse condition
        let inlineBrace = line.last == Token(text: "{", type: .lbrace)
        let conditionTokens =
            inlineBrace
            ? line.dropFirst().dropLast()
            : line.dropFirst()
        
        let conditionSource = conditionTokens.map(\.text).joined(separator: " ")
        let conditionExpr = try parser.lower(
            try parser.parseExpression(expression: conditionSource, index: index), index: index
        )
        
        // Find IF opening brace line
        print("if body: ", body, index)
        let braceLineIndex = try braceStarter(body, index)

        let ifEnd = try correspondingBrace(index: braceLineIndex, body: body)

        let ifBodyLines = Array(body[(braceLineIndex + 1)..<ifEnd])
        let thenStatements = try index_extender(lines: ifBodyLines, index: index)

        // Check ELSE
        var elseStatements: [Statement]? = nil
        var consumed = ifEnd - index + 1
        if ifEnd + 1 < body.count,
           body[ifEnd + 1].first == Token(text: "else", type: .keyword) {

            let elseLine = ifEnd + 1
            let elseInlineBrace = body[elseLine].contains(Token(text: "{", type: .lbrace))
            let elseBraceIndex: Int

            if elseInlineBrace {
                elseBraceIndex = elseLine
            } else {
                guard elseLine + 1 < body.count,
                      body[elseLine + 1].contains(Token(text: "{", type: .lbrace)) else {
                    throw ErrorInformation(error: .statementParserError(.noBraceStarter), line: index)
                }
                elseBraceIndex = elseLine + 1
            }

            let elseEnd = try correspondingBrace(index: elseBraceIndex, body: body)
            let elseBodyLines = Array(body[(elseBraceIndex + 1)..<elseEnd])
            elseStatements = try index_extender(lines: elseBodyLines, index: index)

            consumed = elseEnd - index + 1
        }

        return (
            statement: .ifStatement(
                condition: conditionExpr,
                then: thenStatements,
                else: elseStatements, line: index
            ),
            consumed: consumed
        )
    }
    
    func parseWhile(
        line: [Token],
        body: [[Token]],
        index: Int
    ) throws -> (statement: Statement, consumed: Int) {

        let braceIndex = try braceStarter(body, index)
        let endBrace = try correspondingBrace(index: braceIndex, body: body)
        print(endBrace)

        let conditionTokens: [Token]
        if braceIndex == index {
            // while cond {
            conditionTokens = Array(line.dropFirst().dropLast())
        } else {
            // while cond \n {
            conditionTokens = Array(line.dropFirst())
        }

        let conditionSource = conditionTokens.map(\.text).joined(separator: " ")
        let conditionExpr = try parser.lower(
            try parser.parseExpression(expression: conditionSource, index: index),
            index: index
        )

        let bodyLines = Array(body[(braceIndex + 1)..<endBrace])
        let parsedBody = try index_extender(lines: bodyLines, index: index)
        
        return (
            statement: .whileStatement(
                condition: conditionExpr,
                body: parsedBody,
                line: index
            ),
            consumed: endBrace - index + 1
        )
    }
    
    func parseFor(line: [Token], body: [[Token]], index: Int) throws -> (statement: Statement, consumed: Int) {
        /*
         for pattern in patterns {
         
         or
         
         for pattern in patterns
         {
         */
        guard let split = line.firstIndex(of: Token(text: "in", type: .keyword)) else {
            throw ErrorInformation(error: .statementParserError(.doesntHave("in")), line: index)
        }
        guard line[0] == Token(text: "for", type: .keyword) else {
            throw ErrorInformation(error: .statementParserError(.doesntHave("for")), line: index)
        }
        let bindingNames = line[1..<split].map(\.text).filter { !($0 == ",") }  // gets all the bind names, so in `for x in 1 -> 5`, its going to be ["x"]; this is going to be strictly variables
        let bindingValues = line[(split+1)...(line.count - (try braceStarter(body, index) == index ? 2 : 1))].map(\.text) // similar, but in the values, so `for x in 1 -> 5` is going to have ["1", "->", "5"]
        // in next step, we're going to make it into separate expressions
        let splitByComma: () -> [String] = {
            var result: [String] = []
            var token: String = ""
            for elem in bindingValues {
                if elem == "," {
                    result.append(token)
                    token = ""
                } else {
                    token += elem
                }
            }
            if !token.isEmpty {
                result.append(token)
            }
            return result
        }
        
        let delimiter = try correspondingBrace(index: try braceStarter(body, index), body: body)
        
        let forBody = Array(body[(try braceStarter(body, index)+1)..<delimiter])
        let parsedFor = try index_extender(lines: forBody, index: index)
        let parsedValues = try splitByComma().map { try parser.lower(try parser.parseExpression(expression: $0, index: index), index: index) }
        let consumed = delimiter-index+1
        return (statement: .forStatement(iterators: bindingNames, iterends: parsedValues, body: parsedFor, line: index), consumed: consumed)
    }

    // MARK: - DECLARATIONS
    
    func parseReturn(line: [Token], index: Int) throws -> Statement {
        // return <expression>
        guard line.count >= 2 else {
            throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
        }
        let expression = try parser.lower(try parser.parseExpression(expression: line[1...].map(\.text).joined(separator: " "), index: index), index: index)
        return .return_val(expression)
    }
    
    func functionDeclaration(line: [Token], body: [[Token]], index: Int) throws -> (statement: Statement, consumed: Int) {
        /*
         fn name(args) {
         
         or
         
         fn name(args)
         {
         */
        guard line.count >= 6 else {
            throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
        }
        
        guard line.first == Token(text: "fn", type: .keyword) else {
            throw ErrorInformation(error: .statementParserError(.doesntHave("fn")), line: index)
        }
        
        guard line[1].type == .identifier else {
            throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
        }
        let id = line[1]
        guard let argumentStater = line.firstIndex(of: Token(text: "(", type: .lParen)), let argumentEnder = line.firstIndex(of: Token(text: ")", type: .rParen)) else {
            throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
        }
        guard let returnArrow = line.firstIndex(of: Token(text: "=>", type: .doubleArrow)) else {
            throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
        }
        
        let returnType = line[(returnArrow+1)...].map(\.text).joined()
        
        let argumentDefiners: () -> [[Token]] = { // lambda because its the only case where you need to do a line -> [line]
            var result: [[Token]] = [[]]
            var currentToken: [Token] = []
            guard argumentStater+1 < argumentEnder-1 else {
                return []
            }
            for possible_value in line[(argumentStater+1)..<argumentEnder] {
                if possible_value == Token(text: ",", type: .comma) {
                    result.append(currentToken)
                    currentToken = []
                } else {
                    currentToken.append(possible_value)
                }
            }
            if !currentToken.isEmpty {
                result.append(currentToken)
            }
            return result.filter { !$0.isEmpty }
        }
        let argumentConstructors = argumentDefiners()
        
		struct ParameterData {
			
            let id: String
			let type: ParserTimeType
        }
        
        // we now have all the information we have in argumentValues(). for example, in `fn foo(x: number)`, argumentValues() returns:
        // [[Token(text: "x", type: .identifier), Token(text: ":", type: .colon), Token(text: "number", type: .identifier)]]
        // each array should have:
        // a) an identifier at the start
        // b) a colon at the second element
        // c) a valid type after and including the third element
        var parameters: [ParameterData] = []
        for argumentConstructor in argumentConstructors {
            guard argumentConstructor.count >= 3 else {
                throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
            }
            guard argumentConstructor[0].type == .identifier else {
                throw ErrorInformation(error: .statementParserError(.incorrectExpression), line: index)
            }
            let id = argumentConstructor[0]
            guard argumentConstructor[1].type == .colon else {
                throw ErrorInformation(error: .statementParserError(.incorrectExpression), line: index)
            }
			let type = parseType(typeString: argumentConstructor[2...].map(\.text).joined(), line: index)
            parameters.append(ParameterData(id: id.text, type: type))
        }
        let delimiter = try correspondingBrace(index: try braceStarter(body, index), body: body)
        let functionBody = Array(body[(try braceStarter(body, index) + 1)..<delimiter])
        let parsedFunction = try statement_parse(paintext: functionBody.map { $0.map(\.text).joined(separator: " ") }.joined(separator: "; "))
        let consumed = delimiter-index+1
		return (statement: .functionDeclaration(name: id.text, paramNames: parameters.map(\.id), paramTypes: parameters.map(\.type), body: parsedFunction, returnType: parseType(typeString: returnType, line: index), line: index), consumed: consumed)
    }

    func letDeclaration(line: [Token], index: Int) throws -> Statement {
        guard line.count >= 6 else {
            throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
        }
        guard let colon = line.firstIndex(of: Token(text: ":", type: .colon)), colon == 2 else {
            throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
        }
        guard let equal = line.firstIndex(of: Token(text: "=", type: .op)) else {
            throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
        }

        let name = line[1].text
        let typeString = line[(colon+1)..<equal].map(\.text).joined()
        let expr = line[(equal+1)...].map(\.text).joined(separator: " ")

        return .createVariable(
            name: name,
            value: try parser.lower(try parser.parseExpression(expression: expr, index: index), index: index),
            bindingType: .let,
			type: parseType(typeString: typeString, line: index), line: index
        )
    }

    func varDeclaration(line: [Token], index: Int) throws -> Statement {
        // var name : type = val
        guard line.count >= 6 else { throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index) }
        guard let colon = line.firstIndex(of: Token(text: ":", type: .colon)), colon == 2 else {
            throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
        }
        guard let equal = line.firstIndex(of: Token(text: "=", type: .op)) else {
            throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
        }

        let name = line[1].text
        let typeString = line[(colon+1)..<equal].map(\.text).joined()
        let expr = line[(equal+1)...].map(\.text).joined(separator: " ")

        return .createVariable(
            name: name,
            value: try parser.lower(try parser.parseExpression(expression: expr, index: index), index: index),
            bindingType: .var,
			type: parseType(typeString: typeString, line: index), line: index
        )
    }
    
    func assignment(line: [Token], index: Int) throws -> Statement {
        guard line.count >= 3 else {
            throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
        }
        guard let split = line.firstIndex(of: Token(text: "=", type: .op)) else {
            throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
        }
        let id = try parser.lower(try parser.parseExpression(expression: line[..<split].map(\.text).joined(separator: " "), index: index), index: index)
        
        let expr = try parser.lower(try parser.parseExpression(expression: line[(split+1)...].map(\.text).joined(), index: index), index: index)
        func toReference(reference: Expression) throws -> Reference {
            switch reference {
            case .variable(let id, line: _):
                return .variable(id)
            case .dot(structName: let expr, member: let member, args: _, line: _):
                return .dot(try toReference(reference: expr), member)
            default:
                throw ErrorInformation(error: .statementParserError(.incorrectExpression), line: index)
            }
        }
        return .modifyVariable(name: try toReference(reference: id), newValue: expr, line: index)
    }
    
    func parseStructs(line: [Token], body: [[Token]], index: Int) throws -> (statement: Statement, consumed: Int) {
        
        
        guard line.count >= 2 else {
            throw ErrorInformation(error: .statementParserError(.doesntHave("`struct`")), line: index)
        }
        let name = line[1].text
        var parsedStruct = ParserStructData(name: name)
        let delimiter = try correspondingBrace(index: try braceStarter(body, index), body: body)
        let structBody = Array(body[(try braceStarter(body, index) + 1)..<delimiter])
        
        
        // now we need to grab the values
        func structParsing(body: [[Token]]) throws -> [String: StructMemberBinding] {
            // line can only start with var, let, or fn
            typealias StructNamePair = (String, StructMemberBinding, consumed: Int)
            
            func parseVar(line: [Token], index: Int) throws -> StructNamePair {
                guard line.count >= 6 else { throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index) }
                guard let colon = line.firstIndex(of: Token(text: ":", type: .colon)), colon == 2 else {
                    throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
                }
                guard let equal = line.firstIndex(of: Token(text: "=", type: .op)) else {
                    throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
                }

                let name = line[1].text
                let typeString = line[(colon+1)..<equal].map(\.text).joined()
                let expr = line[(equal+1)...].map(\.text).joined(separator: " ")

                return (name, StructMemberBinding(bindingType: .var, expr: .expr(try parser.lower(try parser.parseExpression(expression: expr, index: index), index: index)), type: parseType(typeString: typeString, line: index)), consumed: 0)
            }
            
            func parseLet(line: [Token], index: Int) throws -> StructNamePair {
                guard line.count >= 6 else { throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index) }
                guard let colon = line.firstIndex(of: Token(text: ":", type: .colon)), colon == 2 else {
                    throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
                }
                guard let equal = line.firstIndex(of: Token(text: "=", type: .op)) else {
                    throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
                }

                let name = line[1].text
                let typeString = line[(colon+1)..<equal].map(\.text).joined()
                let expr = line[(equal+1)...].map(\.text).joined(separator: " ")

				return (name, StructMemberBinding(bindingType: .let, expr: .expr(try parser.lower(try parser.parseExpression(expression: expr, index: index), index: index)), type: parseType(typeString: typeString, line: index)), consumed: 0)
            }
            
            func parseFn(line: [Token], body: [[Token]], index: Int) throws -> StructNamePair {
                guard line.count >= 6 else {
                    throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
                }
                
                guard line.first == Token(text: "fn", type: .keyword) else {
                    throw ErrorInformation(error: .statementParserError(.doesntHave("fn")), line: index)
                }
                
                guard line[1].type == .identifier else {
                    throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
                }
                let id = line[1]
                guard let argumentStater = line.firstIndex(of: Token(text: "(", type: .lParen)), let argumentEnder = line.firstIndex(of: Token(text: ")", type: .rParen)) else {
                    throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
                }
                guard let returnArrow = line.firstIndex(of: Token(text: "=>", type: .doubleArrow)) else {
                    throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
                }
                
                let returnType = line[(returnArrow+1)...].map(\.text).joined()
                
                let argumentDefiners: () -> [[Token]] = { // lambda because its the only case where you need to do a line -> [line]
                    var result: [[Token]] = [[]]
                    var currentToken: [Token] = []
                    guard argumentStater+1 < argumentEnder-1 else {
                        return []
                    }
                    for possible_value in line[(argumentStater+1)..<argumentEnder] {
                        if possible_value == Token(text: ",", type: .comma) {
                            result.append(currentToken)
                            currentToken = []
                        } else {
                            currentToken.append(possible_value)
                        }
                    }
                    if !currentToken.isEmpty {
                        result.append(currentToken)
                    }
                    return result.filter { !$0.isEmpty }
                }
                let argumentConstructors = argumentDefiners()
                
                struct ParameterData {
                    let id: String
                    let type: ParserTimeType
                }
                
                // we now have all the information we have in argumentValues(). for example, in `fn foo(x: number)`, argumentValues() returns:
                // [[Token(text: "x", type: .identifier), Token(text: ":", type: .colon), Token(text: "number", type: .identifier)]]
                // each array should have:
                // a) an identifier at the start
                // b) a colon at the second element
                // c) a valid type after and including the third element
                var parameters: [ParameterData] = []
                for argumentConstructor in argumentConstructors {
                    guard argumentConstructor.count >= 3 else {
                        throw ErrorInformation(error: .statementParserError(.incompleteStatement), line: index)
                    }
                    guard argumentConstructor[0].type == .identifier else {
                        throw ErrorInformation(error: .statementParserError(.incorrectExpression), line: index)
                    }
                    let id = argumentConstructor[0]
                    guard argumentConstructor[1].type == .colon else {
                        throw ErrorInformation(error: .statementParserError(.incorrectExpression), line: index)
                    }
					let type = parseType(typeString: argumentConstructor[2...].map(\.text).joined(), line: index)
					parameters.append(ParameterData(id: id.text, type: type))
                }
                let delimiter = try correspondingBrace(index: try braceStarter(body, index), body: body)
                let functionBody = Array(body[(try braceStarter(body, index) + 1)..<delimiter])
                let parsedFunction = try statement_parse(paintext: functionBody.map { $0.map(\.text).joined(separator: " ") }.joined(separator: "\n"))
                let consumed = delimiter-index+1
				return (id.text, StructMemberBinding(bindingType: .var, expr: .function(.function(.user(FunctionData(body: parsedFunction, argName: parameters.map(\.id), argType: parameters.map { $0.type }, returnType: parseType(typeString: returnType, line: index))))), type: .function), consumed: consumed)
            }
            
            var structIndex = 0
            var values: [String: StructMemberBinding] = [:]
            while structIndex < body.count {
                let line = body[structIndex]
                let keyword = line.first
                
                if let keyword = keyword {
                    switch keyword {
                    case Token(text: "var", type: .keyword):
                        let pair = try parseVar(line: line, index: structIndex)
                        values[pair.0] = pair.1
                        structIndex += 1
                        continue
                    case Token(text: "let", type: .keyword):
                        let pair = try parseVar(line: line, index: structIndex)
                        values[pair.0] = pair.1
                        structIndex += 1
                        continue
                    case Token(text: "fn", type: .keyword):
                        let pair = try parseFn(line: line, body: body, index: structIndex)
                        print("gayayyayayayayayayayay", pair.1)
                        values[pair.0] = pair.1
                        structIndex += pair.consumed
                        continue
                    default:
                        throw ErrorInformation(error: .statementParserError(.unknownStatement), line: 999)
                    }
                } else {
                    structIndex += 1
                }
            }
            return values
        }
        
        let consumed = delimiter-index+1
        parsedStruct.values = try structParsing(body: structBody)
        return (.createStruct(name: parsedStruct.name, fields: parsedStruct.values, line: index), consumed)
    }

    // MARK: - UTILITIES

    func normalize(lines: [Token]) -> [[Token]] {
        var result: [[Token]] = []
        var current: [Token] = []

        for token in lines {
            if token.type == .semicolon || token.type == .newline {
                if !current.isEmpty {
                    result.append(current)
                    current = []
                }
            } else if token.type == .lbrace || token.type == .rbrace {
                if !current.isEmpty {
                    result.append(current)
                    current = []
                }
                result.append([token])
            } else {
                current.append(token)
            }
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result
    }
    
    func correspondingBrace(index: Int, body: [[Token]]) throws -> Int {// reuse code
        var depth = 1
        var i = index + 1
        while depth > 0 && i < body.count {
            if body[i].contains(Token(text: "{", type: .lbrace)) {
                depth += 1
            }
            if body[i].contains(Token(text: "}", type: .rbrace)) {
                depth -= 1
            }
            if depth == 0 { return i }
            i += 1
        }
        throw ErrorInformation(error: .statementParserError(.general("did not start or finish brace(s)")), line: index-1)
    }
    
    func braceStarter(_ body: [[Token]], _ index: Int, tag: String = "") throws -> Int {
        // ONLY if next line is exactly "{"
        if body.indices.contains(index + 1),
           body[index + 1].count == 1,
           body[index + 1][0] == Token(text: "{", type: .lbrace) {
            return index + 1
        }
        throw ErrorInformation(
            error: .statementParserError(.incompleteStatement),
            line: index
        )
    }
    
    // the index extender extends the error from relative to its scope to where the line (approximately) is
    func index_extender(lines: [[Token]], index: Int) throws -> [Statement] {
        do {
            return try self.statement_parse(
                paintext: lines.map { $0.map(\.text).joined(separator: " ") }.joined(separator: "\n")
            )
        } catch let err as ErrorInformation {
            let tmp = ErrorInformation(error: err.error, line: err.line + index + 1)
            throw tmp
        } catch let err {
            throw err
        }
    }
}

func parseType(typeString: String, line: Int) -> ParserTimeType {
    switch typeString {
	case "number": return .number
	case "string": return .string
	case "boolean": return .boolean
	case "void": return .void
	case "type": return .type
    default:
        if typeString.hasPrefix("array(") {
			return .array(parseType(typeString: String(typeString.dropFirst(6).dropLast()), line: line))
        }
        if typeString.hasPrefix("optional(") {
			return .optional(parseType(typeString: String(typeString.dropFirst(9).dropLast()), line: line))
        }
		print("THIS IS A FUCKING TEST", typeString)
		return .unresolved(.variable(typeString, line: line))
    }
}
