internal import Combine

enum StatementError: Error {
    case temp
}

final class StatementParser: ObservableObject {
    let lexer = Lexer()
    let parser = ExpressionParser()

    func statement_parse(paintext: String, starting_index: Int) throws -> [Statement] {
        let tokens = try lexer.lexer(plaintext: paintext)
        let lines = normalize(lines: tokens)

        var statements: [Statement] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let keyword = line.first
            if keyword == Token(text: "return", type: .keyword) {
                statements.append(try parseReturn(line: line, index: index))
                index += 1
                continue
            }
            do {
                print(line.map(\.text).joined(separator: " "))
                let expression = try parser.parseExpression(expression: line.map(\.text).joined(separator: " "))
                statements.append(.expr(try parser.lower(expression, index: starting_index + index), line: starting_index + index))
                index += 1
                continue
            } catch { }
            print(keyword as Any)
            switch keyword {
                
            case nil:
                throw StatementError.temp
                
            case Token(text: "let", type: .keyword):
                statements.append(try letDeclaration(line: line, index: starting_index + index))
                index += 1

            case Token(text: "var", type: .keyword):
                statements.append(try varDeclaration(line: line, index: starting_index + index))
                index += 1

            case Token(text: "if", type: .keyword):
                let parsed = try parseIf(line: line, body: lines, index: starting_index + index)
                statements.append(parsed.statement)
                index += parsed.consumed
                
            case Token(text: "while", type: .keyword):
                let parsed = try parseWhile(line: line, body: lines, index: starting_index + index)
                statements.append(parsed.statement)
                index += parsed.consumed
                
            case Token(text: "for", type: .keyword):
                let parsed = try parseFor(line: line, body: lines, index: starting_index + index)
                statements.append(parsed.statement)
                index += parsed.consumed
                
            case Token(text: "fn", type: .keyword):
                let parsed = try functionDeclaration(line: line, body: lines, index: starting_index + index)
                statements.append(parsed.statement)
                index += parsed.consumed
                
            case _ where keyword!.type == .identifier:
                let parsed = try assignment(line: line, index: starting_index + index)
                statements.append(parsed)
                index += 1

            default:
                index += 1
            }
        }
        return statements
    }

    // MARK: - BRANCHING STATEMENTS

    func parseIf(
        line: [Token],
        body: [[Token]],
        index: Int
    ) throws -> (statement: Statement, consumed: Int) {
        // 1️⃣ Parse condition
        let inlineBrace = line.last == Token(text: "{", type: .lbrace)
        let conditionTokens =
            inlineBrace
            ? line.dropFirst().dropLast()
            : line.dropFirst()
        
        let conditionSource = conditionTokens.map(\.text).joined(separator: " ")
        let conditionExpr = try parser.lower(
            try parser.parseExpression(expression: conditionSource), index: index
        )
        
        // 2️⃣ Find IF opening brace line
        let braceLineIndex = try braceStarter(line, body, index)

        let ifEnd = try correspondingBrace(index: braceLineIndex, body: body)

        let ifBodyLines = Array(body[(braceLineIndex + 1)..<ifEnd])
        let thenStatements = try statement_parse(
            paintext: ifBodyLines
                .map { $0.map(\.text).joined(separator: " ") }
                .joined(separator: "; "), starting_index: index + 1
        )

        // 4️⃣ Check ELSE
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
                    throw StatementError.temp
                }
                elseBraceIndex = elseLine + 1
            }

            let elseEnd = try correspondingBrace(index: elseBraceIndex, body: body)
            let elseBodyLines = Array(body[(elseBraceIndex + 1)..<elseEnd])

            elseStatements = try statement_parse(
                paintext: elseBodyLines
                    .map { $0.map(\.text).joined(separator: " ") }
                    .joined(separator: "; "), starting_index: elseBraceIndex
            )

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
    
    func parseWhile(line: [Token], body: [[Token]], index: Int) throws -> (statement: Statement, consumed: Int) {
        /*
         while <cond> {
         
         or
         
         while <cond>
         {
         */
        let braceStarter: () throws -> Int = {
            if line.contains(Token(text: "{", type: .lbrace)) {
                return index
            } else if body[index+1].contains(Token(text: "{", type: .lbrace)) {
                return index + 1
            } else {
                throw StatementError.temp
            }
        }
        
        
        let expr = Array(line[1...(line.count - (try braceStarter() == index ? 2 : 1))])
        let delimiter = try correspondingBrace(index: try braceStarter(), body: body)
        let whileBody = Array(body[(try braceStarter()+1)..<delimiter])
        let parsedWhile = try statement_parse(paintext: whileBody.map { $0.map(\.text).joined(separator: " ") }.joined(separator: "; "), starting_index: index)
        print(expr.map(\.text).joined())
        let consumed = delimiter-index+1
        return (statement: .whileStatement(condition: try parser.lower(try parser.parseExpression(expression: expr.map(\.text).joined(separator: " ")), index: index), body: parsedWhile, line: index), consumed: consumed)
        
    }
    
    func parseFor(line: [Token], body: [[Token]], index: Int) throws -> (statement: Statement, consumed: Int) {
        /*
         for pattern in patterns {
         
         or
         
         for patter in patters
         {
         */
        guard let split = line.firstIndex(of: Token(text: "in", type: .keyword)) else {
            throw StatementError.temp
        }
        guard line[0] == Token(text: "for", type: .keyword) else {
            throw StatementError.temp
        }
        let bindingNames = line[1..<split].map(\.text).filter { !($0 == ",") }  // gets all the bind names, so in `for x in 1 -> 5`, its going to be ["x"]; this is going to be strictly variables
        let bindingValues = line[(split+1)...(line.count - (try braceStarter(line, body, index) == index ? 2 : 1))].map(\.text) // similar, but in the values, so `for x in 1 -> 5` is going to have ["1", "->", "5"]
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
        
        let delimiter = try correspondingBrace(index: try braceStarter(line, body, index), body: body)
        
        let forBody = Array(body[(try braceStarter(line, body, index)+1)..<delimiter])
        let parsedFor = try statement_parse(paintext: forBody.map { $0.map(\.text).joined(separator: " ") }.joined(separator: "\n"), starting_index: index)
        let parsedValues = try splitByComma().map { try parser.lower(try parser.parseExpression(expression: $0), index: index) }
        let consumed = delimiter-index+1
        return (statement: .forStatement(iterators: bindingNames, iterends: parsedValues, body: parsedFor, line: index), consumed: consumed)
    }

    // MARK: - DECLARATIONS
    
    func parseReturn(line: [Token], index: Int) throws -> Statement {
        // return <expression>
        guard line.count >= 2 else {
            throw StatementError.temp
        }
        let expression = try parser.lower(try parser.parseExpression(expression: line[1...].map(\.text).joined(separator: " ")), index: index)
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
            throw StatementError.temp
        }
        
        guard line.first == Token(text: "fn", type: .keyword) else {
            throw StatementError.temp
        }
        
        guard line[1].type == .identifier else {
            throw StatementError.temp
        }
        
        let id = line[1]
        guard let argumentStater = line.firstIndex(of: Token(text: "(", type: .lParen)), let argumentEnder = line.firstIndex(of: Token(text: ")", type: .rParen)) else {
            throw StatementError.temp
        }
        guard let returnArrow = line.firstIndex(of: Token(text: "=>", type: .doubleArrow)) else {
            throw StatementError.temp
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
        
        struct ParameterData: Hashable {
            let id: String
            let type: Type
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
                throw StatementError.temp
            }
            guard argumentConstructor[0].type == .identifier else {
                throw StatementError.temp
            }
            let id = argumentConstructor[0]
            guard argumentConstructor[1].type == .colon else {
                throw StatementError.temp
            }
            let type = parseType(typeString: argumentConstructor[2...].map(\.text).joined())
            parameters.append(ParameterData(id: id.text, type: type))
        }
        let delimiter = try correspondingBrace(index: try braceStarter(line, body, index), body: body)
        let functionBody = Array(body[(try braceStarter(line, body, index) + 1)..<delimiter])
        let parsedFunction = try statement_parse(paintext: functionBody.map { $0.map(\.text).joined(separator: " ") }.joined(separator: "; "), starting_index: index)
        let consumed = delimiter-index+1
        return (statement: .functionDeclaration(name: id.text, paramNames: parameters.map(\.id), paramTypes: parameters.map(\.type), body: parsedFunction, returnType: parseType(typeString: returnType), line: index), consumed: consumed)
    }

    func letDeclaration(line: [Token], index: Int) throws -> Statement {
        guard line.count >= 6 else {
            throw StatementError.temp
        }
        guard let colon = line.firstIndex(of: Token(text: ":", type: .colon)), colon == 2 else {
            throw StatementError.temp
        }
        guard let equal = line.firstIndex(of: Token(text: "=", type: .op)) else {
            throw StatementError.temp
        }

        let name = line[1].text
        let typeString = line[(colon+1)..<equal].map(\.text).joined()
        let expr = line[(equal+1)...].map(\.text).joined()

        return .createVariable(
            name: name,
            value: try parser.lower(try parser.parseExpression(expression: expr), index: index),
            bindingType: .let,
            type: parseType(typeString: typeString), line: index
        )
    }

    func varDeclaration(line: [Token], index: Int) throws -> Statement {
        guard line.count >= 6 else { throw StatementError.temp }
        guard let colon = line.firstIndex(of: Token(text: ":", type: .colon)), colon == 2 else {
            throw StatementError.temp
        }
        guard let equal = line.firstIndex(of: Token(text: "=", type: .op)) else {
            throw StatementError.temp
        }

        let name = line[1].text
        let typeString = line[(colon+1)..<equal].map(\.text).joined()
        let expr = line[(equal+1)...].map(\.text).joined()

        return .createVariable(
            name: name,
            value: try parser.lower(try parser.parseExpression(expression: expr), index: index),
            bindingType: .var,
            type: parseType(typeString: typeString), line: index
        )
    }
    
    func assignment(line: [Token], index: Int) throws -> Statement {
        guard line.count >= 3 else {
            throw StatementError.temp
        }
        guard let split = line.firstIndex(of: Token(text: "=", type: .op)) else {
            throw StatementError.temp
        }
        let id = try parser.lower(try parser.parseExpression(expression: line[..<split].map(\.text).joined(separator: " ")), index: index)
        guard case .variable(let string, _) = id else {
            throw StatementError.temp
        }
        
        let expr = try parser.lower(try parser.parseExpression(expression: line[(split+1)...].map(\.text).joined()), index: index)
        return .modifyVariable(name: string, newValue: expr, line: index)
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

    func parseType(typeString: String) -> Type {
        switch typeString {
        case "number": return .number
        case "string": return .string
        case "boolean": return .boolean
        case "void": return .void
        default:
            if typeString.hasPrefix("array(") {
                return .array(parseType(typeString: String(typeString.dropFirst(6).dropLast())))
            }
            if typeString.hasPrefix("optional(") {
                return .optional(parseType(typeString: String(typeString.dropFirst(9).dropLast())))
            }
            return .structure(typeString)
        }
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
            i += 1
        }
        guard depth == 0 else {
            throw StatementError.temp
        }
        return i - 1
    }
    
    func braceStarter(_ line: [Token], _ body: [[Token]], _ index: Int) throws -> Int {
        if line.contains(Token(text: "{", type: .lbrace)) {
            return index
        }
        guard body.indices.contains(index + 1) else {
            throw StatementError.temp
        }
        if body[index+1].contains(Token(text: "{", type: .lbrace)) {
            return index + 1
        } else {
            throw StatementError.temp
        }
    }
}
