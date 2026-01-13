import Foundation
internal import Combine

var executionStepCount = 0
let MAX_EXECUTION_STEPS = 100_000

func stepCheck() throws {
    executionStepCount += 1
    if executionStepCount > MAX_EXECUTION_STEPS {
        throw ErrorInformation(
            error: .generalError("Execution limit exceeded (possible infinite loop)"),
            line: -1
        )
    }
}

indirect enum Expression {
    case operation(op: Operators, val1: Expression, val2: Expression? = nil) // useful for unary operations; combining binary operations and unary operations
    case variable(String, line: Int)
    case number(Double)
    case string(String)
    case boolean(Bool)
    case null(`Type`)
    case array([Expression])
    case structure(name: String)
    case call_function(name: Expression, arguments: [Expression], line: Int)
    case dot(structName: Expression, member: String, line: Int)
    case accessElement(arr: Expression, elementIndex: Expression)
    case convertToType(expr: Expression, toType: Type)
}

enum FunctionValue {
    case user(FunctionData)
    case builtinPrint
    case builtinCount
    case builtinRound
    case builtinAppend
}

enum Statement {
    case printTest
    // creation shenanigans
    case createVariable(name: String, value: Expression, bindingType: BindingType, type: `Type`, line: Int)
    case modifyVariable(name: String, newValue: Expression, line: Int)
    case createStruct(name: String, fields: [String: VariableBinding], line: Int)
    case copyStruct(copiedName: String, from: String, add: [String: VariableBinding], delete: [String], modify: [String: VariableBinding], line: Int) // the new COP stuff
    case modifyMember(name: String, from: Expression, withNewValue: Expression, line: Int)
    case functionDeclaration(name: String, paramNames: [String], paramTypes: [Type], body: [Statement], returnType: Type, line: Int)
    case modifyElement(array: Expression, index: Expression, withNewValue: Expression, line: Int)
    
    // control flow
    case ifStatement(condition: Expression, then: [Statement], else: [Statement]?, line: Int)
    case whileStatement(condition: Expression, body: [Statement], line: Int)
    case forStatement(iterators: [String], iterends: [Expression], body: [Statement], line: Int)
    case return_val(Expression)
    
    // miscellaneous
    case expr(Expression, line: Int)
}

enum Operators {
    case add, subtract, multiply, divide, and, or
    case equal, notEqual, greaterThan, lessThan, greaterThanOrEqual, lessThanOrEqual
    case not, uMinus
    // miscellaneuos stuff
    case arrow // -> is synonymous to range(a, b) in Python
    // TODO: doubleArrow // => is special operator
}

enum Value {
    case number(Double)
    case string(String)
    case array([Value], elementType: `Type`) // elementType needed for explicit types, so [2, 3, "hi"] doesn't any excuse why it has "hi"
    case null(`Type`) /* explicit nulls, so something like
                       var x: optional(number) = number.null
                       can be used
                       */
    case bool(Bool)
    case structure(StructData)
    case function(FunctionValue)
    case void
}

extension Value {
    func type() throws -> `Type` {
        switch self {
        case .number(_):
            return .number
        case .string(_):
            return .string
        case .array(let a, let e):
            if try a.allSatisfy({ try $0.type() == e }) || a.count == 0 {
                return .array(e)
            } else {
                throw ErrorBubbles.typeMismatch
            }
        case .bool(_):
            return .boolean
        case .null(let t):
            // you can infer that when you're doing .null(T), you're specifying optional(T)
            return .optional(t)
        case .structure(let `struct`):
            return .structure(`struct`.name)
        case .function(_):
            return .function
        case .void:
            return .void
        }
    }
    
    func desc() -> String {
        switch self {
        case .number(let num):
            return fancy(number: num)
        case .string(let str):
            return String(str)
        case .array(let arr, elementType: _):
            let description = arr.map { $0.desc() }
            return description.joined(separator: ", ")
        case .null(let type):
            return type.desc()
        case .bool(let bool):
            return String(bool)
        case .void:
            return "void"
        default:
            return "block"
        }
    }
}

indirect enum `Type`: Equatable, Hashable {
    case number
    case string
    case array(Type)
    case optional(Type)
    case boolean
    case structure(String)
    case function
    case void
}

extension `Type` {
    func desc() -> String {
        switch self {
        case .number:
            return "number"
        case .string:
            return "string"
        case .array(let type):
            return "array(\(type.desc())"
        case .optional(let type):
            return "optional(\(type.desc())"
        case .boolean:
            return "boolean"
        case .structure(let str):
            return "struct(\(str)"
        case .function:
            return "function"
        case .void:
            return "void"
        }
    }
}

enum TemplateCase {
    case template // you can't change anything
    case rebindable // foo.x = 5 works
}

enum ValueType {
    case uninitialized
    case initialized(Value)
}

enum BindingType {
    case `let`
    case `var`
}

struct VariableBinding {
    var value: ValueType
    let bindType: BindingType
    let type: `Type`
}

struct FunctionData {
    let body: [Statement]
    let argName: [String]
    let argType: [`Type`]
    let returnType: `Type`
}

struct StructData {
    var name: String
    var fieldMembers: [String: VariableBinding]
    var historyTree: [String]
    var templateCase: TemplateCase
}

enum ErrorBubbles: Error {
    case returned(Value)
    case typeMismatch
    case argumentCountMismatch
    case uninitializedValue
    case outOfScope
    case mutatedLet
    case mutatedNonBindable
    case notDefined
    case breakOutAll
    case generalError(String)
    case uninitializedError
}

struct ErrorInformation: Error {
    let error: ErrorBubbles
    let line: Int
}

final class Scope {
    let parent: Scope?
    var variables: [String: VariableBinding] = [:]
    
    init(parent: Scope? = nil) {
        self.parent = parent
    }
    
    func getVariable(name: String) throws -> (Scope, VariableBinding) {
        if let binding = variables[name] {
            return (self, binding)
        }
        if let parent = parent {
            return try parent.getVariable(name: name)
        }
        throw ErrorBubbles.notDefined
    }
    
    func modifyVariable(name: String, withNewValue: Value, index: Int) throws {
        let (scope, variable) = try getVariable(name: name)
        guard canAssign(lhsType: variable.type, rhsType: try withNewValue.type()) else {
            throw ErrorInformation(error: .typeMismatch, line: index)
        }
        scope.variables[name] = VariableBinding(value: .initialized(withNewValue), bindType: variable.bindType, type: variable.type)
    }
    
    func addVariable(name: String, value: VariableBinding, index: Int) throws {
        if case ValueType.initialized(let v) = value.value {
            if value.type != (try v.type()) {
                guard case .optional(let t) = value.type, t == (try v.type()) else {
                    throw ErrorInformation(error: .typeMismatch, line: index)
                }
            }
        }
        variables[name] = value
    }
    
    func resetScope() {
        variables.removeAll()
    }
    
    deinit {
        print("out of scope!")
    }
}

@discardableResult
func evaluate(expression: Expression, scope: Scope, output: Output) throws -> Value {
    try stepCheck()
    switch expression {
    case .operation(let op, let val1, let val2): // very long, yes, but needed for all core operations
        switch op {
            
        case .add:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            switch (lhs, rhs) {
            case (.number(let v1), .number(let v2)):
                return .number(v1 + v2)
            case (.string(let v1), .string(let v2)):
                return .string(v1 + v2)
            default:
                throw ErrorBubbles.typeMismatch
            }
        case .subtract:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorBubbles.typeMismatch
            }
            return .number(v1 - v2)
        case .multiply:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorBubbles.typeMismatch
            }
            return .number(v1 * v2)
        case .divide:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorBubbles.typeMismatch
            }
            return .number(v1 / v2)
        case .and:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            guard case .bool(let v1) = lhs, case .bool(let v2) = rhs else {
                throw ErrorBubbles.typeMismatch
            }
            if v1 {
                return .bool(v2)
            } else {
                return .bool(false)
            }
        case .or:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            guard case .bool(let v1) = lhs, case .bool(let v2) = rhs else {
                throw ErrorBubbles.typeMismatch
            }
            if v1 {
                return .bool(true)
            } else {
                return .bool(v2)
            }
        case .not:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            guard case .bool(let bool) = lhs else {
                throw ErrorBubbles.typeMismatch
            }
            return .bool(!bool)
        case .uMinus:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            guard case .number(let double) = lhs else {
                throw ErrorBubbles.typeMismatch
            }
            return .number(-double)
        case .equal:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            return .bool(try equal(lhs: lhs, rhs: rhs))
        case .notEqual:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            return .bool(try !equal(lhs: lhs, rhs: rhs))
        case .greaterThan:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorBubbles.typeMismatch
            }
            return .bool(v1 > v2)
        case .lessThan:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorBubbles.typeMismatch
            }
            return .bool(v1 < v2)
        case .greaterThanOrEqual:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorBubbles.typeMismatch
            }
            return .bool(v1 >= v2)
        case .lessThanOrEqual:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorBubbles.typeMismatch
            }
            return .bool(v1 <= v2)
            case .arrow:
                let lhs = try evaluate(expression: val1, scope: scope, output: output)
                let rhs = try evaluate(expression: val2!, scope: scope, output: output)
                guard case .number(let d1) = lhs, case .number(let d2) = rhs else {
                    throw ErrorBubbles.typeMismatch
                }
            guard d1 <= d2 else {
                throw ErrorBubbles.generalError("start index is bigger than end index")
            }
                return .array((Int(d1)...Int(d2)).map { .number(Double($0)) }, elementType: .number)
        }
    case .variable(let name, line: let line):
        guard case ValueType.initialized(let v) = try scope.getVariable(name: name).1.value else {
            throw ErrorInformation(error: .uninitializedValue, line: line)
        }
        print("afafsfasfsa: ", v)
        return v
    case .number(let num):
        return .number(num)
    case .string(let string):
        return .string(string)
    case .boolean(let b):
        return .bool(b)
    case .null(let n):
        return .null(n)
    case .array(let array):
        var types: [Type] = []
        for elem in array {
            let result = try evaluate(expression: elem, scope: scope, output: output)
            types.append(try result.type())
        }
        guard let tmp = types.first else {
            throw ErrorBubbles.argumentCountMismatch
        }
        if types.allSatisfy({ $0 == tmp }) {
            return .array(try array.map { try evaluate(expression: $0, scope: scope, output: output) }, elementType: tmp)
        } else {
            throw ErrorBubbles.typeMismatch
        }
    case .structure(name: let name):
        guard case .initialized(let value) = try scope.getVariable(name: name).1.value, case .structure(let structure) = value else {
            throw ErrorBubbles.typeMismatch
        }
        return .structure(structure)
    case .call_function(name: let callee, arguments: let arguments, line: let line):
        let calleeValue = try evaluate(expression: callee, scope: scope, output: output)
        guard case .function(let fn) = calleeValue else {
            throw ErrorBubbles.typeMismatch
        }
        switch fn {
        case .builtinPrint:
            var joined = ""
            for argument in arguments {
                let argValue = try evaluate(expression: argument, scope: scope, output: output)
                print("ans: ", argValue)
                joined += argValue.desc()
            }
            output.terminaltext.append(joined)
            return .void
            
        case .builtinCount:
            guard arguments.count == 1 else {
                throw ErrorBubbles.argumentCountMismatch
            }
            let answer = try evaluate(expression: arguments.first!, scope: scope, output: output)
            switch answer {
            case .string(let str):
                return .number(Double(str.count))
            case .array(let arr, elementType: _):
                return .number(Double(arr.count))
            default:
                throw ErrorBubbles.typeMismatch
            }

        case .user(let name):
            guard name.argName.count == arguments.count else { 
                throw ErrorBubbles.argumentCountMismatch
            }

            let functionScope = Scope(parent: scope)

            for (key, (value, type)) in zip(name.argName, zip(arguments, name.argType)) {
                let ans = try evaluate(expression: value, scope: scope, output: output)
                try functionScope.addVariable(
                    name: key,
                    value: VariableBinding(value: .initialized(ans), bindType: .let, type: type), index: line
                )
            }
            for ln in name.body {
                do {
                    try execute(statement: ln, scope: functionScope, output: output)
                } catch ErrorBubbles.returned(let value) {
                    return value
                }
            }

            return .void
        case .builtinRound:
            guard arguments.count == 1 else {
                throw ErrorBubbles.argumentCountMismatch
            }
            let answer = try evaluate(expression: arguments.first!, scope: scope, output: output)
            guard case .number(let double) = answer else {
                throw ErrorBubbles.typeMismatch
            }
            return .number(round(double))

        case .builtinAppend:
            // append(arr, elem)
            guard arguments.count == 2 else {
                throw ErrorBubbles.argumentCountMismatch
            }
            guard case .variable(let string, _) = arguments[0] else {
                throw ErrorBubbles.typeMismatch
            }
            let info = try scope.getVariable(name: string)
            guard info.1.bindType == .var else {
                throw ErrorBubbles.mutatedLet
            }
            guard case .initialized(let val) = info.1.value, case .array(let array, let elementType) = val else {
                throw ErrorBubbles.typeMismatch
            }
            let elem = try evaluate(expression: arguments[1], scope: scope, output: output)
            guard try elem.type() == elementType else {
                throw ErrorBubbles.typeMismatch
            }
            var temp = array
            temp.append(elem)
            try (info.0).modifyVariable(name: string, withNewValue: .array(temp, elementType: elementType), index: line)
            return .void
        }
    case .dot(structName: let structName, member: let member, line: let line):
        let targetVal = try evaluate(expression: structName, scope: scope, output: output)
        guard case .structure(let structData) = targetVal else {
            throw ErrorInformation(error: .typeMismatch, line: line)
        }
        guard let binding = structData.fieldMembers[member],
              case .initialized(let value) = binding.value else {
            throw ErrorBubbles.notDefined
        }

        return value
    case .accessElement(arr: let collection, elementIndex: let i):
        let ans = try evaluate(expression: i, scope: scope, output: output)
        guard case .number(let elementIndex) = ans else {
            throw ErrorBubbles.typeMismatch
        }
        let val = try evaluate(expression: collection, scope: scope, output: output)
        switch val {
        case .array(let arr, elementType: _):
            guard (try arr.first?.type()) != nil else {
                throw ErrorBubbles.typeMismatch
            }
            return arr[Int(elementIndex)]
        case .string(let str):
            return .string(String(str[str.index(str.startIndex, offsetBy: Int(elementIndex))]))
        default:
            throw ErrorBubbles.typeMismatch
        }
    case .convertToType(expr: let expr, toType: let toType):
        if convertible(typeA: (try evaluate(expression: expr, scope: scope, output: output).type()), typeB: toType) {
            return try convertToType(val: try evaluate(expression: expr, scope: scope, output: output), toType: toType)
        }
        throw ErrorBubbles.typeMismatch
    }
}

func convertible(typeA: Type, typeB: Type) -> Bool {
    switch (typeA, typeB) {
    case let types where types.0 == types.1: // you can convert number to number
        return true
    case (.string, .number), (.number, .string): // you can convert string to number and vice versa
        return true
    case (.boolean, .string):
        return true
    case (.array(let typeA), .array(let typeB)): // you can convert array(number) to array(string)
        return convertible(typeA: typeA, typeB: typeB)
    default:
        return false
    }
}

func convertToType(val: Value, toType: Type) throws -> Value {
    switch (try val.type(), toType) {
    case (_, .string):
        switch val {
        case .number(let double):
            return .string(String(double))
        case .string(let string):
            return .string(string)
        case .bool(let bool):
            return .string(String(bool))
        default:
            return .null(.string)
        }
    case (.string, .number):
        guard case .string(let string) = val else {
            throw ErrorBubbles.typeMismatch
        }
        if let num = Double(string) {
            return .number(num)
        } else {
            return .null(.number)
        }
    case (.array(_), .array(_)):
        guard case .array(let array, _) = val else {
            throw ErrorBubbles.typeMismatch
        }
        
        return .array(try array.map { try convertToType(val: $0, toType: innerType(type: toType)) }, elementType: innerType(type: toType))
    default:
        throw ErrorBubbles.typeMismatch
    }
}

// V checks if lhs can accept rhs | note: lets say ~ means lhs can accept rhs. then optional(t) ~ t, but t !~ optional(t)
// rule of thumb: if foo has the chance to be optional(T), generally, put foo at lhs
func canAssign(lhsType: Type, rhsType: Type) -> Bool {
    if lhsType == rhsType {
        return true
    }
    
    if case Type.optional(let t) = lhsType, t == rhsType {
        return true
    }
    
    return false
}

func fancy(number: Double) -> String {
    return Double(Int(number)) == number ? "\(Int(number))" : "\(number)"
}

func execute(statement: Statement, scope: Scope, output: Output) throws {
    try stepCheck()
    switch statement {
    case .createVariable(name: let name, value: let value, bindingType: let bindingType, type: let type, line: let line):
        let result = try evaluate(expression: value, scope: scope, output: output)
        switch type {
        case .structure(let structName):
            guard case .initialized(let value) = try scope.getVariable(name: structName).1.value, case .structure(let structure) = value else {
                throw ErrorInformation(error: .typeMismatch, line: line)
            }
            try scope.addVariable(name: name, value: VariableBinding(value: .initialized(.structure(StructData(name: name, fieldMembers: structure.fieldMembers, historyTree: structure.historyTree, templateCase: .rebindable))), bindType: bindingType, type: .structure(name)), index: line)
        default:
            try scope.addVariable(name: name, value: VariableBinding(value: ValueType.initialized(result), bindType: bindingType, type: type), index: line)
        }
    case .modifyVariable(name: let name, newValue: let newExpression, line: let line):
        let newValue = try evaluate(expression: newExpression, scope: scope, output: output)
        let info = try scope.getVariable(name: name)
        guard info.1.bindType == .var else {
            throw ErrorInformation(error: .mutatedLet, line: line)
        }
        try scope.modifyVariable(name: name, withNewValue: newValue, index: line)
    case .ifStatement(condition: let condition, then: let then, else: let `else`, _):
        let result = try evaluate(expression: condition, scope: scope, output: output)
        guard case .bool(let bool) = result else {
            throw ErrorBubbles.typeMismatch
        }
        if bool {
            let ifScope = Scope(parent: scope)
            for ln in then {
                try execute(statement: ln, scope: ifScope, output: output)
            }
        } else if let elseLines = `else`, !bool {
            let ifScope = Scope(parent: scope)
            for ln in elseLines {
                try execute(statement: ln, scope: ifScope, output: output)
            }
        }
    case .printTest: // testing node
        print("EXECUTED NODE: ", statement)
    case .whileStatement(condition: let condition, body: let body, line: _):
        let whileScope = Scope(parent: scope)
        while true {
            let bool = try evaluate(expression: condition, scope: whileScope, output: output)
            guard case .bool(let bool) = bool else {
                throw ErrorBubbles.typeMismatch
            }
            if !bool {
                break
            }
            for ln in body {
                try execute(statement: ln, scope: whileScope, output: output)
            }
        }
    case .forStatement(iterators: let iterators, iterends: let iterends, body: let body, line: let line):

        guard iterators.count == iterends.count else {
            throw ErrorBubbles.argumentCountMismatch
        }

        // 1️⃣ Evaluate iterends ONCE
        let evaluatedIterends: [Value] = try iterends.map {
            try evaluate(expression: $0, scope: scope, output: output)
        }
        print(evaluatedIterends)
        let forScope = Scope(parent: scope)
        // 2️⃣ Create iterator variables
        for index in 0..<iterators.count {
            try forScope.addVariable(
                name: iterators[index],
                value: VariableBinding(
                    value: .uninitialized,
                    bindType: .var,
                    type: innerType(type: try evaluatedIterends[index].type())
                ),
                index: line
            )
        }

        
        var idx = 0

        while true {
            var reachedEnd = false
            print(idx)
            // 3️⃣ Bind iterator values
            for index in 0..<iterators.count {
                let iterName = iterators[index]
                let iterValue = evaluatedIterends[index]

                switch iterValue {
                case .array(let arr, _):
                    if idx >= arr.count {
                        reachedEnd = true
                    } else {
                        print(arr[idx])
                        try forScope.modifyVariable(
                            name: iterName,
                            withNewValue: arr[idx],
                            index: line)
                    }

                case .string(let str):
                    if idx >= str.count {
                        reachedEnd = true
                    } else {
                        let ch = String(str[str.index(str.startIndex, offsetBy: idx)])
                        try forScope.modifyVariable(
                            name: iterName,
                            withNewValue: .string(ch),
                            index: line
                        )
                    }

                default:
                    throw ErrorBubbles.typeMismatch
                }

                if reachedEnd { break }
            }

            if reachedEnd { break }
            print("scope: ", forScope.variables)
            for stmt in body {
                try execute(statement: stmt, scope: forScope, output: output)
            }

            idx += 1
        }
    case .createStruct(name: let name, fields: let fields, line: let line):
        try scope.addVariable(name: name, value: VariableBinding(value: .initialized(.structure(StructData(name: name, fieldMembers: fields, historyTree: [], templateCase: .template))), bindType: .var, type: .structure(name)), index: line)
    case .copyStruct(copiedName: let copiedName, from: let from, add: let add, delete: let delete, modify: let modify, line: let line):
        let result = try scope.getVariable(name: from).1
        guard case .initialized(let value) = result.value, case .structure(let s) = value else {
            throw ErrorBubbles.typeMismatch
        }
        var temporaryStruct = s
        
        temporaryStruct.name = copiedName
        guard temporaryStruct.templateCase == .template else { // it doesn't make sense if you can do copy fooVariable => Bstruct {
            throw ErrorBubbles.typeMismatch
        }
        var tmp = s.historyTree
        tmp.append(s.name)
        temporaryStruct.historyTree = tmp
        for (key, value) in add {
            temporaryStruct.fieldMembers[key] = value
        }
        for name in delete {
            if temporaryStruct.fieldMembers.removeValue(forKey: name) == nil {
                throw ErrorBubbles.notDefined
            }
        }
        for (key, value) in modify {
            if temporaryStruct.fieldMembers[key] != nil {
                temporaryStruct.fieldMembers[key] = value
            } else {
                throw ErrorBubbles.notDefined
            }
        }
        try scope.addVariable(name: copiedName, value: VariableBinding(value: .initialized(.structure(temporaryStruct)), bindType: .var, type: .structure(copiedName)), index: line)
    case .functionDeclaration(name: let name, paramNames: let paramNames, paramTypes: let paramTypes, body: let body, returnType: let returnType, line: let line):
        try scope.addVariable(name: name, value: VariableBinding(value: .initialized(.function(.user(FunctionData(body: body, argName: paramNames, argType: paramTypes, returnType: returnType)))), bindType: .let, type: .function), index: line)
    case .return_val(let expr):
        throw ErrorBubbles.returned(try evaluate(expression: expr, scope: scope, output: output))
    case .expr(let expr, line: _):
        try evaluate(expression: expr, scope: scope, output: output)
    case .modifyMember(name: let memberName, from: let from, withNewValue: let newVal, line: let line):
        guard case .variable(let string, _) = from else {
            throw ErrorBubbles.notDefined
        }
        let (structScope, binding) = try scope.getVariable(name: string)
        guard case .initialized(let val) = binding.value, case .structure(let `struct`) = val else {
            throw ErrorBubbles.typeMismatch
        }
        guard `struct`.templateCase == .rebindable else {
            throw ErrorBubbles.mutatedNonBindable
        }
        guard let _ = `struct`.fieldMembers[memberName]?.bindType else {
            throw ErrorBubbles.notDefined
        }
        guard `struct`.fieldMembers[memberName]!.bindType == .var else {
            throw ErrorBubbles.typeMismatch
        }
        var modifiedField = `struct`.fieldMembers
        let ans = try evaluate(expression: newVal, scope: scope, output: output)
        guard (try ans.type()) == `struct`.fieldMembers[memberName]!.type else {
            throw ErrorBubbles.typeMismatch
        }
        modifiedField[memberName] = VariableBinding(value: .initialized(try evaluate(expression: newVal, scope: scope, output: output)), bindType: .var, type: `struct`.fieldMembers[memberName]!.type)
        try structScope.modifyVariable(name: string, withNewValue: .structure(StructData(name: string, fieldMembers: modifiedField, historyTree: `struct`.historyTree, templateCase: .rebindable)), index: line)
    case .modifyElement(array: let array, index: let i, withNewValue: let withNewValue, line: let line):
        guard case .variable(let string, _) = array else {
            throw ErrorBubbles.typeMismatch
        }
        let ans = try evaluate(expression: i, scope: scope, output: output)
        guard case .number(let index) = ans else {
            throw ErrorBubbles.typeMismatch
        }

        let val = try evaluate(expression: array, scope: scope, output: output)
        switch val {
        case .array(let arr, elementType: let type):
            var tmp: [Value] = []
            if canAssign(lhsType: type, rhsType: try arr[Int(index)].type()) {
                tmp = arr
                guard Int(index) < tmp.count && index >= 0 else {
                    throw ErrorBubbles.generalError("index out of range")
                }
                tmp[Int(index)] = try evaluate(expression: withNewValue, scope: scope, output: output)
            } else {
                throw ErrorBubbles.typeMismatch
            }
            guard let first = tmp.first else {
                throw ErrorBubbles.typeMismatch
            }
            try scope.modifyVariable(name: string, withNewValue: .array(tmp, elementType: try first.type()), index: line)
        case .string(let str):
            guard case .string(let string) = try evaluate(expression: withNewValue, scope: scope, output: output) else {
                throw ErrorBubbles.typeMismatch
            }
            guard string.count == 1 else {
                throw ErrorBubbles.argumentCountMismatch
            }
            guard Int(index) < str.count && index >= 0 else {
                throw ErrorBubbles.generalError("index out of range")
            }

            var tmp = Array(str)
            tmp[Int(index)] = string.first!
            let toValue = tmp.map { Value.string(String($0)) }
            guard let first = toValue.first else {
                throw ErrorBubbles.typeMismatch
            }
            try scope.modifyVariable(name: string, withNewValue: .array(toValue, elementType: try first.type()), index: line)
        default:
            throw ErrorInformation(error: .mutatedNonBindable, line: -999)
        }
    }
}

func equal(lhs: Value, rhs: Value) throws -> Bool {
    switch (lhs, rhs) {
    case (.number(let l), .number(let r)):
        return l == r
    case (.string(let l), .string(let r)):
        return l == r
    case (.array(let l, _), .array(let r, _)):
        guard l.count == r.count else {
            throw ErrorBubbles.argumentCountMismatch
        }
        return try zip(l, r).allSatisfy { try equal(lhs: $0.0, rhs: $0.1) }
    case (.null(let l), .null(let r)):
        return l == r
    default:
        throw ErrorBubbles.typeMismatch
    }
}

func innerType(type: Type) -> Type {
    switch type {
    case .array(let arrType):
        return arrType
    default:
        return type
    }
}

class ProgramRunner: ObservableObject {
    let scope = Scope()
    let output = Output()
    var program: [Statement]

    init(program: [Statement]) {
        self.program = program
    }

    @MainActor
    func run() throws {
        executionStepCount = 0

        try scope.addVariable(
            name: "print",
            value: VariableBinding(
                value: .initialized(.function(.builtinPrint)),
                bindType: .let,
                type: .function
            ),
            index: 0
        )

        try scope.addVariable(
            name: "length",
            value: VariableBinding(
                value: .initialized(.function(.builtinCount)),
                bindType: .let,
                type: .function
            ),
            index: 0
        )

        try scope.addVariable(
            name: "round",
            value: VariableBinding(
                value: .initialized(.function(.builtinRound)),
                bindType: .let,
                type: .function
            ),
            index: 0
        )

        try scope.addVariable(
            name: "append",
            value: VariableBinding(
                value: .initialized(.function(.builtinAppend)),
                bindType: .let,
                type: .function
            ),
            index: 0
        )

        for stmt in program {
            try execute(statement: stmt, scope: scope, output: output)
        }
    }
}
