import Foundation
internal import Combine

func debugPrint(_ this: Any?...) {
    print(this as Any)
}

func printID(tag: String = "") {
    print("tag: ", tag, ", ", UUID(), separator: "")
}

var executionStepCount = 0
let MAX_EXECUTION_STEPS = 100_000

func stepCheck() throws {
    executionStepCount += 1
    if executionStepCount > MAX_EXECUTION_STEPS {
        throw ErrorInformation(
            error: .astError(.generalError("Execution limit exceeded (possible infinite loop)")),
            line: -1
        )
    }
}

indirect enum Expression {
    case operation(op: Operators, val1: Expression, val2: Expression? = nil, line: Int) // useful for unary operations; combining binary operations and unary operations
	case emparr(T: ParserTimeType)
    case variable(String, line: Int)
    case number(Double)
    case string(String)
    case boolean(Bool)
    case type(Type)
    case null(ParserTimeType)
    case array([Expression])
    case structure(name: String)
    case call_function(name: Expression, arguments: [Expression], line: Int)
    case dot(structName: Expression, member: String, args: [Expression]? = nil, line: Int)
    case accessElement(arr: Expression, elementIndex: Expression)
    case convertToType(expr: Expression, toType: Type)
}

indirect enum Reference {
    case variable(String)
    case dot(Reference, String)
}

enum FunctionValue {
    case user(FunctionData)
    case builtinPrint
    case builtinInput
    case builtinCount
    case builtinRound
    case builtinAppend
    case builtinConvert
}

enum Statement {
    case printTest
    // creation shenanigans
    case createVariable(name: String, value: Expression, bindingType: BindingType, type: ParserTimeType, line: Int)
    case modifyVariable(name: Reference, newValue: Expression, line: Int)
    case createStruct(name: String, fields: [String: StructMemberBinding], line: Int)
    case copyStruct(copiedName: String, from: String, add: [String: StructMemberBinding], delete: [String], modify: [String: StructMemberBinding], line: Int) // the new COP stuff
    case functionDeclaration(name: String, paramNames: [String], paramTypes: [ParserTimeType], body: [Statement], returnType: ParserTimeType, line: Int)
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
    case add, subtract, multiply, divide, and, or, mod
    case equal, notEqual, greaterThan, lessThan, greaterThanOrEqual, lessThanOrEqual
    case not, uMinus
    // miscellaneuos stuff
    case arrow // -> is synonymous to range(a, b) in Python
    // TODO: doubleArrow // => is special operator
}

enum Value {
	case number(Double)
	case string(String)
	case bool(Bool)
	case array([Value], elementType: Type)
	case null(Type)
	case type(Type)
	case structure(StructData)
	case function(FunctionValue)
	case void
}

extension Value {
	func type(line: Int) throws -> Type {
		switch self {
		case .number:
			return .number
		case .string:
			return .string
		case .bool:
			return .boolean
		case .void:
			return .void
		case .type:
			return .type
		case .function:
			return .function
		case .structure(let s):
			return .structure(s.name)
		case .null(let t):
			return .optional(t)
		case .array(_, let elementType):
			return .array(elementType)
		}
	}
}

extension Value {
    
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
            return "null(\(type.desc()))"
        case .bool(let bool):
            return String(bool)
        case .void:
            return "void"
		case .type(let T):
			return T.desc()
        default:
            return "block"
        }
    }
}

indirect enum `Type`: Equatable, Hashable {
	case type
    case number
    case string
    case array(Type)
    case optional(Type)
    case boolean
    case structure(String)
    case function
    case void
}

indirect enum ParserTimeType {
	case number
	case string
	case function
	case array(ParserTimeType)
	case optional(ParserTimeType)
	case boolean
	case void
	case type
	case unresolved(Expression)
	
	func toType(scope: Scope, line: Int, output: Output) throws -> Type {
		switch self {
			
		case .number:
			return .number
			
		case .string:
			return .string
			
		case .boolean:
			return .boolean
			
		case .void:
			return .void
			
		case .type:
			return .type
			
		case .function:
			return .function
			
		case .array(let inner):
			return .array(try inner.toType(scope: scope, line: line, output: output))
			
		case .optional(let inner):
			return .optional(try inner.toType(scope: scope, line: line, output: output))
			
		case .unresolved(let expr):
			let value = try evaluate(expression: expr, scope: scope, output: output)
			switch value {
			case .type(let t):
				return t
			case .structure(let s):
				return .structure(s.name)
			default:
				throw ErrorInformation(
					error: .astError(.generalError("Cannot resolve type")),
					line: line
				)
			}
		}
	}
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
		case .type:
			return "type"
		}
    }
}

enum TemplateCase {
    case template // you can't change anything
    case rebindable // foo.x = 5 works
}

enum ValueType {
    case uninitialized(Type)
    case initialized(Value)
	case reference(Expression)
}

enum BindingType {
    case `let`
    case `var`
}

struct VariableBinding {
	var value: ValueType
	let bindType: BindingType
	let type: Type
}

struct StructMemberVariable {
    let bindType: BindingType
}

struct FunctionData {
    let body: [Statement]
    let argName: [String]
    let argType: [ParserTimeType]
    let returnType: ParserTimeType
	
}

struct StructData {
    var name: String
    var fieldMembers: [String: VariableBinding]
    var historyTree: [String]
    var templateCase: TemplateCase
}

enum ErrorBubbles: Error {
    case returned(Value)
    case requestInput(message: String)
    case divideByZero
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

enum Errors: Error {
    case astError(ErrorBubbles)
    case statementParserError(StatementError)
    case expressionParserError(ParserErrors)
}

struct ErrorInformation: Error {
    let error: Errors
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
    
	func modifyVariable(
		name: String,
		withNewValue: Value,
		index: Int,
		output: Output
	) throws {
		let (scope, variable) = try getVariable(name: name)
		
		guard variable.bindType == .var else {
			throw ErrorInformation(error: .astError(.mutatedLet), line: index)
		}
		
		let lhs = variable.type
		let rhs = try withNewValue.type(line: index)
		
		guard canAssign(lhsType: lhs, rhsType: rhs) else {
			throw ErrorInformation(error: .astError(.typeMismatch), line: index)
		}
		
		scope.variables[name] = VariableBinding(
			value: .initialized(withNewValue),
			bindType: variable.bindType,
			type: variable.type
		)
	}
    
	func addVariable(name: String, value: VariableBinding, index: Int, scope: Scope, output: Output) throws {
        if case ValueType.initialized(let v) = value.value {
			guard canAssign(lhsType: value.type, rhsType: try v.type(line: index)) else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: index)
            }
        }
        variables[name] = value
    }
    
    func deleteVariable(name: String) {
        if variables[name] != nil {
            variables.removeValue(forKey: name)
        }
        if let parent = parent {
            parent.deleteVariable(name: name)
        }
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
    case .type(let t):
        return .type(t)
    case .operation(let op, let val1, let val2, let line): // very long, yes, but needed for all core operations
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
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
        case .subtract:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
            return .number(v1 - v2)
        case .multiply:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
            return .number(v1 * v2)
        case .divide:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
            guard v2 != 0.0 else {
                throw ErrorInformation(error: .astError(.divideByZero), line: line)
            }
            return .number(v1 / v2)
        case .and:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            guard case .bool(let v1) = lhs, case .bool(let v2) = rhs else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
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
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
            if v1 {
                return .bool(true)
            } else {
                return .bool(v2)
            }
        case .not:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            guard case .bool(let bool) = lhs else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
            return .bool(!bool)
        case .uMinus:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            guard case .number(let double) = lhs else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
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
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
            return .bool(v1 > v2)
        case .lessThan:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
            return .bool(v1 < v2)
        case .greaterThanOrEqual:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
            return .bool(v1 >= v2)
        case .lessThanOrEqual:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            
            guard case .number(let v1) = lhs, case .number(let v2) = rhs else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
            return .bool(v1 <= v2)
            case .arrow:
                let lhs = try evaluate(expression: val1, scope: scope, output: output)
                let rhs = try evaluate(expression: val2!, scope: scope, output: output)
                guard case .number(let d1) = lhs, case .number(let d2) = rhs else {
                    throw ErrorInformation(error: .astError(.typeMismatch), line: line)
                }
            guard d1 <= d2 else {
                throw ErrorInformation(error: .astError( .generalError("start index is bigger than end index")), line: line)
            }
                return .array((Int(d1)...Int(d2)).map { .number(Double($0)) }, elementType: .number)
        case .mod:
            let lhs = try evaluate(expression: val1, scope: scope, output: output)
            let rhs = try evaluate(expression: val2!, scope: scope, output: output)
            guard case .number(let d1) = lhs, case .number(let d2) = rhs else {
                throw ErrorBubbles.typeMismatch
            }
            guard d2 != 0.0 else {
                throw ErrorInformation(error: .astError(.divideByZero), line: line)
            }
            return .number(d1 - trunc(d1 / d2) * d2)
        }
    case .variable(let name, line: let line):
        guard case ValueType.initialized(let v) = try scope.getVariable(name: name).1.value else {
            throw ErrorInformation(error: .astError(.uninitializedValue), line: line)
        }
        return v
    case .number(let num):
        return .number(num)
    case .string(let string):
        return .string(string)
    case .boolean(let b):
        return .bool(b)
    case .null(let n):
		return .null(try n.toType(scope: scope, line: 999, output: output))
    case .array(let array):
        var types: [Type] = []
        for elem in array {
            let result = try evaluate(expression: elem, scope: scope, output: output)
			types.append(try result.type(line: 999))
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
					value: VariableBinding(value: .initialized(ans), bindType: .let, type: type.toType(scope: scope, line: line, output: output)), index: line, scope: scope, output: output
                )
            }
            for ln in name.body {
                do {
                    try execute(statement: ln, scope: functionScope, output: output)
                } catch ErrorBubbles.returned(let value) {
					if try value.type(line: line) == name.returnType.toType(scope: scope, line: line, output: output) {
                        return value
                    } else {
                        throw ErrorInformation(error: .astError(.typeMismatch), line: line)
                    }
                }
            }

            if try name.returnType.toType(scope: scope, line: line, output: output) == .void {
                return .void
            } else {
                throw ErrorInformation(error: .astError(.generalError("Never returned on a non-void returning function")), line: line)
            }
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
            guard try elem.type(line: line) == elementType else {
                throw ErrorBubbles.typeMismatch
            }
            var temp = array
            temp.append(elem)
			try (info.0).modifyVariable(name: string, withNewValue: .array(temp, elementType: elementType), index: line, output: output)
            return .void
        case .builtinInput:
            // input(message)
            guard arguments.count == 1 else {
                throw ErrorInformation(error: .astError(.argumentCountMismatch), line: line)
            }
            do {
                let input = try scope.getVariable(name: "_input")
                guard case .initialized(let val) = input.1.value else {
                    throw ErrorBubbles.uninitializedValue
                }
                defer {
                    scope.deleteVariable(name: "_input")
                }
                return val
            } catch ErrorBubbles.notDefined {
                let message = try evaluate(expression: arguments[0], scope: scope, output: output)
                guard case .string(let string) = message else {
                    throw ErrorInformation(error: .astError(.typeMismatch), line: line)
                }
                throw ErrorBubbles.requestInput(message: string)
            }
        case .builtinConvert:
            // convert(type, value)
            guard arguments.count == 2 else {
                throw ErrorInformation(error: .astError(.argumentCountMismatch), line: line)
            }
            
            func getType(_ type: Expression, line: Int) throws -> Type {
                guard case .variable(let string, _) = type else {
                    throw ErrorInformation(error: .astError(.typeMismatch), line: line)
                }
				return try parseType(typeString: string, line: line).toType(scope: scope, line: line, output: output)
            }
            let typeToConvert = try getType(arguments[0], line: line)
            return try evaluate(expression: .convertToType(expr: arguments[1], toType: typeToConvert), scope: scope, output: output)
        }
    case .dot(structName: let structName, member: let member, args: let args, line: let line):
        let targetVal = try evaluate(expression: structName, scope: scope, output: output)
        guard case .structure(let structData) = targetVal else {
            throw ErrorInformation(error: .astError(.typeMismatch), line: line)
        }
        guard let binding = structData.fieldMembers[member] else {
            throw ErrorBubbles.notDefined
        }
        
        switch binding.value {
        case .uninitialized(_):
            throw ErrorInformation(error: .astError(.uninitializedValue), line: line)
        case .initialized(let val):
            let structFuncScope = Scope(parent: scope)
            for member in structData.fieldMembers.keys {
				try structFuncScope.addVariable(name: member, value: structData.fieldMembers[member]!, index: line, scope: scope, output: output)
            }
			var structSelf = 
			structSelf.value = .reference(.variable(string, line: <#T##Int#>))
			try structFuncScope.addVariable(name: "self", value: structSelf, index: line, scope: scope, output: output)

            print(structData.fieldMembers)
            if args == nil {
                return val
            } else {
                let expr: Expression = .call_function(name: .variable(member, line: line), arguments: args!, line: line)
                return try evaluate(expression: expr, scope: structFuncScope, output: output)
            }
		case .reference(let ref):
			let tmp = try evaluate(expression: .dot(structName: ref, member: member, args: args, line: line), scope: scope, output: output)
			return tmp
		}
    case .accessElement(arr: let collection, elementIndex: let i):
        let ans = try evaluate(expression: i, scope: scope, output: output)
        guard case .number(let elementIndex) = ans else {
            throw ErrorBubbles.typeMismatch
        }
        let val = try evaluate(expression: collection, scope: scope, output: output)
        switch val {
        case .array(let arr, elementType: _):
            guard (try arr.first?.type(line: 999)) != nil else {
                throw ErrorBubbles.typeMismatch
            }
            return arr[Int(elementIndex)]
        case .string(let str):
            return .string(String(str[str.index(str.startIndex, offsetBy: Int(elementIndex))]))
        default:
            throw ErrorBubbles.typeMismatch
        }
    case .convertToType(expr: let expr, toType: let toType):
		if convertible(typeA: (try evaluate(expression: expr, scope: scope, output: output).type(line: 999)), typeB: toType) {
            return try convertToType(val: try evaluate(expression: expr, scope: scope, output: output), toType: toType)
        }
        throw ErrorBubbles.typeMismatch
	case .emparr(T: let T):
		return .array([], elementType: try T.toType(scope: scope, line: 999, output: output))
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
	switch (try val.type(line: -1), toType) {
		
	case (_, .string):
		return .string(val.desc())
		
	case (.string, .number):
		if let n = Double(val.desc()) {
			return .number(n)
		}
		return .null(.number)
		
	case (.array(_), .array(let t2)):
		guard case .array(let arr, _) = val else {
			throw ErrorBubbles.typeMismatch
		}
		let converted = try arr.map { try convertToType(val: $0, toType: t2) }
		return .array(converted, elementType: t2)
		
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
		try scope.addVariable(name: name, value: VariableBinding(value: ValueType.initialized(result), bindType: bindingType, type: type.toType(scope: scope, line: line, output: output)), index: line, scope: scope, output: output)
        
    // TODO: refactor code from me
    case .modifyVariable(name: let name, newValue: let newExpression, line: let line):
        func referenceChain(_ ref: Reference) throws -> [String] {
            switch ref {
            case .variable(let s):
                return [s]
            case .dot(let inner, let member):
                return try referenceChain(inner) + [member]
            }
        }

        func setMember(_ rootName: String, chain: [String], newValue: Value) throws {
            // chain example: ["a","b","c"] means set a.b.c = newValue
            guard chain.count >= 2 else { throw ErrorBubbles.generalError("bad chain") }

            // 1) Get root binding (a)
            var rootBinding = try scope.getVariable(name: rootName).1
            guard case .initialized(let rootVal) = rootBinding.value,
                  case .structure(var rootStruct) = rootVal else {
                throw ErrorBubbles.typeMismatch
            }

            // 2) Recursive mutation of nested structs (value-type safe)
            func mutate(structData: inout StructData, index: Int) throws {
                let memberName = chain[index]

                if index == chain.count - 1 {
                    // last hop: assign here
                    guard let old = structData.fieldMembers[memberName] else {
                        throw ErrorInformation(error: .astError(.notDefined), line: line)
                    }
					guard canAssign(lhsType: old.type, rhsType: try newValue.type(line: line)) else {
                        throw ErrorInformation(error: .astError(.typeMismatch), line: line)
                    }
                    guard old.bindType == .var else {
                        throw ErrorInformation(error: .astError(.mutatedLet), line: line)
                    }
                    structData.fieldMembers[memberName] =
                        VariableBinding(value: .initialized(newValue), bindType: old.bindType, type: old.type)
                    return
                }

                // otherwise: go deeper
                guard var nextBinding = structData.fieldMembers[memberName],
                      case .initialized(let nextVal) = nextBinding.value,
                      case .structure(var nextStruct) = nextVal else {
                    throw ErrorBubbles.typeMismatch
                }

                try mutate(structData: &nextStruct, index: index + 1)

                // write mutated child back into this struct
                nextBinding.value = .initialized(.structure(nextStruct))
                structData.fieldMembers[memberName] = nextBinding
            }

            // chain[0] is rootName, so start at index 1
            try mutate(structData: &rootStruct, index: 1)

            // 3) write mutated root struct back to scope variable
            rootBinding.value = .initialized(.structure(rootStruct))
			try scope.modifyVariable(name: rootName, withNewValue: .structure(rootStruct), index: line, output: output)
        }
        let ans = try evaluate(expression: newExpression, scope: scope, output: output)

        switch name {
        case .variable(let s):
			try scope.modifyVariable(name: s, withNewValue: ans, index: line, output: output)

        default:
            let chain = try referenceChain(name)
			print(chain)
            let root = chain[0]
            try setMember(root, chain: chain, newValue: ans)
        }
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
                    value: .uninitialized(try evaluatedIterends[index].type(line: line)),
                    bindType: .var,
					type: innerType(type: try evaluatedIterends[index].type(line: line))
                ),
                index: line,
				scope: scope,
				output: output
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
							index: line, output: output)
                    }

                case .string(let str):
                    if idx >= str.count {
                        reachedEnd = true
                    } else {
                        let ch = String(str[str.index(str.startIndex, offsetBy: idx)])
                        try forScope.modifyVariable(
                            name: iterName,
                            withNewValue: .string(ch),
							index: line, output: output
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
        var bindings: [String: VariableBinding] = [:]
        for name in fields.keys {
            if let field = fields[name] {
                switch field.expr {
                case .expr(let expr):
                    let ans = try evaluate(expression: expr, scope: scope, output: output)
					bindings[name] = VariableBinding(value: .initialized(ans), bindType: field.bindingType, type: try ans.type(line: line))
                case .function(let fn):
                    guard case .function(_) = fn else {
                        throw ErrorInformation(error: .astError(.typeMismatch), line: line)
                    }
                    bindings[name] = VariableBinding(value: .initialized(fn), bindType: .let, type: .function)
                }
            }
        }
        try scope.addVariable(name: name, value: VariableBinding(value: .initialized(.structure(StructData(name: name, fieldMembers: bindings, historyTree: [], templateCase: .rebindable))), bindType: .let, type: .structure(name)), index: line, scope: scope, output: output)
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
        for key in add.keys {
            if let bind = add[key] {
                switch bind.expr {
                case .expr(let expr):
                    let ans = try evaluate(expression: expr, scope: scope, output: output)
					temporaryStruct.fieldMembers[key] = VariableBinding(value: .initialized(ans), bindType: .let, type: try ans.type(line: line))
                case .function(let fn):
                    temporaryStruct.fieldMembers[key] = VariableBinding(value: .initialized(fn), bindType: .let, type: .function)
                }
            } else {
                throw ErrorInformation(error: .astError(.notDefined), line: line)
            }
        }
        for name in delete {
            if temporaryStruct.fieldMembers.removeValue(forKey: name) == nil {
                throw ErrorBubbles.notDefined
            }
        }
        for key in modify.keys {
            if let bind = modify[key] {
                switch bind.expr {
                case .expr(let expr):
                    let ans = try evaluate(expression: expr, scope: scope, output: output)
					temporaryStruct.fieldMembers[key] = VariableBinding(value: .initialized(ans), bindType: .let, type: try ans.type(line: line))
                case .function(let fn):
                    temporaryStruct.fieldMembers[key] = VariableBinding(value: .initialized(fn), bindType: .let, type: .function)
                }
            } else {
                throw ErrorInformation(error: .astError(.notDefined), line: line)
            }
        }
		try scope.addVariable(name: copiedName, value: VariableBinding(value: .initialized(.structure(temporaryStruct)), bindType: .var, type: .structure(copiedName)), index: line, scope: scope, output: output)
    case .functionDeclaration(name: let name, paramNames: let paramNames, paramTypes: let paramTypes, body: let body, returnType: let returnType, line: let line):
		try scope.addVariable(name: name, value: VariableBinding(value: .initialized(.function(.user(FunctionData(body: body, argName: paramNames, argType: paramTypes, returnType: returnType)))), bindType: .let, type: .function), index: line, scope: scope, output: output)
    case .return_val(let expr):
        throw ErrorBubbles.returned(try evaluate(expression: expr, scope: scope, output: output))
    case .expr(let expr, line: _):
        try evaluate(expression: expr, scope: scope, output: output)
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
            if canAssign(lhsType: type, rhsType: try arr[Int(index)].type(line: line)) {
                tmp = arr
                guard Int(index) < tmp.count && index >= 0 else {
                    throw ErrorBubbles.generalError("index out of range")
                }
                tmp[Int(index)] = try evaluate(expression: withNewValue, scope: scope, output: output)
            } else {
                throw ErrorBubbles.typeMismatch
            }
            guard let first = tmp.first else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
			try scope.modifyVariable(name: string, withNewValue: .array(tmp, elementType: try first.type(line: line)), index: line, output: output)
        case .string(let str):
            guard case .string(let string) = try evaluate(expression: withNewValue, scope: scope, output: output) else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
            guard string.count == 1 else {
                throw ErrorInformation(error: .astError(.argumentCountMismatch), line: line)
            }
            guard Int(index) < str.count && index >= 0 else {
                throw ErrorInformation(error: .astError(.generalError("index out of range")), line: line)
            }

            var tmp = Array(str)
            tmp[Int(index)] = string.first!
            let toValue = tmp.map { Value.string(String($0)) }
            guard let first = toValue.first else {
                throw ErrorInformation(error: .astError(.typeMismatch), line: line)
            }
			try scope.modifyVariable(name: string, withNewValue: .array(toValue, elementType: try first.type(line: line)), index: line, output: output)
        default:
            throw ErrorInformation(error: .astError(.mutatedNonBindable), line: line)
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
	case .optional(let optType):
		return optType
    default:
        return type
    }
}

class ProgramRunner: ObservableObject {
    let scope = Scope()
    let output = Output()
    var program: [Statement] = []
    @Published var waitingForInput = false
    @Published var message: String? = nil
    var current_statement_index = 0
    
    
    func setupBuiltins() throws {
        if scope.variables["print"] == nil {
            try scope.addVariable(
                name: "print",
                value: VariableBinding(
                    value: .initialized(.function(.builtinPrint)),
                    bindType: .let,
                    type: .function
                ),
                index: 0,
				scope: scope,
				output: output
            )
        }
        
        if scope.variables["length"] == nil {
            try scope.addVariable(
                name: "length",
                value: VariableBinding(
                    value: .initialized(.function(.builtinCount)),
                    bindType: .let,
                    type: .function
                ),
				index: 0,
				scope: scope,
				output: output
            )
        }
        
        if scope.variables["round"] == nil {
            try scope.addVariable(
                name: "round",
                value: VariableBinding(
                    value: .initialized(.function(.builtinRound)),
                    bindType: .let,
                    type: .function
                ),
				index: 0,
				scope: scope,
				output: output
            )
        }
        
        if scope.variables["append"] == nil {
            try scope.addVariable(
                name: "append",
                value: VariableBinding(
                    value: .initialized(.function(.builtinAppend)),
                    bindType: .let,
                    type: .function
                ),
				index: 0,
				scope: scope,
				output: output
            )
        }
        
        if scope.variables["append"] == nil {
            try scope.addVariable(
                name: "append",
                value: VariableBinding(
                    value: .initialized(.function(.builtinAppend)),
                    bindType: .let,
                    type: .function
                ),
				index: 0,
				scope: scope,
				output: output
            )
        }
        
        if scope.variables["input"] == nil {
            try scope.addVariable(
                name: "input",
                value: VariableBinding(
                    value: .initialized(.function(.builtinInput)),
                    bindType: .let,
                    type: .function
                ),
				index: 0,
				scope: scope,
				output: output
            )
        }
        
        if scope.variables["convert"] == nil {
            try scope.addVariable(
                name: "convert",
                value: VariableBinding(
                    value: .initialized(.function(.builtinConvert)),
                    bindType: .let,
                    type: .function),
				index: 0,
				scope: scope,
				output: output)
        }
    }
    @MainActor
    func run(injectIndex index: Int = 0) throws {
        let time = Date()
        try setupBuiltins()
        executionStepCount = 0
        current_statement_index = index

        do {
            for stmt in program[current_statement_index...] {
                try execute(statement: stmt, scope: scope, output: output)
                current_statement_index += 1
                guard current_statement_index < program.count else {
                    let temp = Date()
                    print(temp.timeIntervalSince(time))
                    return
                }
            }
        } catch ErrorBubbles.requestInput(message: let prompt) {
            waitingForInput = true
            message = prompt
        }
    }
    
    func resumeFromInput(from input: Value) throws {
        guard case .string(_) = input else {
            throw ErrorBubbles.typeMismatch
        }
		try scope.addVariable(name: "_input", value: VariableBinding(value: .initialized(input), bindType: .let, type: .string), index: current_statement_index + 1,
							  scope: scope,
							  output: output)
        waitingForInput = false
        try run(injectIndex: current_statement_index)
    }
}

extension Array {
    var range: Range<Int> {
        return 0..<self.count
    }
}
