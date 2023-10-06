/*
 * Copyright © 2023 Dustin Collins (Strega's Gate)
 * All Rights Reserved.
 *
 * http://stregasgate.com
 */

public final class Operation: ShaderElement {
    var operation: Operation? {
        return self
    }
    let valueRepresentation: ValueRepresentation = .operation
    let valueType: ValueType = .operation
    
    public enum Operator {
        case add
        case subtract
        case multiply
        case divide
        
        public enum Comparison {
            case equal
            case notEqual
            case greater
            case greaterEqual
            case less
            case lessEqual
            case and
            case or
            
            var identifer: Int {
                switch self {
                case .equal:
                    return 4_101
                case .notEqual:
                    return 4_102
                case .greater:
                    return 4_103
                case .greaterEqual:
                    return 4_104
                case .less:
                    return 4_105
                case .lessEqual:
                    return 4_106
                case .and:
                    return 4_107
                case .or:
                    return 4_108
                }
            }
        }
        case compare(_ comparison: Comparison)
        
        case branch(comparing: Scalar)
        case discard(comparing: Scalar)
        case sampler2D(filter: Sampler2D.Filter)
        case lerp(factor: Scalar)
        
        var identifier: [Int] {
            switch self {
            case .add:
                return [5_101]
            case .subtract:
                return [5_102]
            case .multiply:
                return [5_103]
            case .divide:
                return [5_104]
            case .compare(let operatorValue):
                return [5_105, operatorValue.identifer]
            case .branch(comparing: let comparing):
                var values: [Int] = [5_106]
                values.append(contentsOf: comparing.documentIdentifierInputData())
                return values
            case .sampler2D(filter: let filter):
                return [5_107, filter.identifier]
            case .lerp(factor: let factor):
                var values: [Int] = [5_108]
                values.append(contentsOf: factor.documentIdentifierInputData())
                return values
            case .discard(comparing: let comparing):
                var values: [Int] = [5_109]
                values.append(contentsOf: comparing.documentIdentifierInputData())
                return values
            }
        }
    }
    
    let `operator`: Operator
    let value1: any ShaderValue
    let value2: any ShaderValue
    
    public func documentIdentifierInputData() -> [Int] {
        var values: [Int] = []
        values.append(contentsOf: self.valueRepresentation.identifier)
        values.append(contentsOf: self.valueType.identifier)
        values.append(contentsOf: self.value1.documentIdentifierInputData())
        values.append(contentsOf: self.value2.documentIdentifierInputData())
        values.append(contentsOf: self.operator.identifier)
        return values
    }
        
    public init(lhs: Scalar, operator: Operator, rhs: Scalar) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    public init(lhs: Vec2, operator: Operator, rhs: Scalar) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    public init(lhs: Vec3, operator: Operator, rhs: Scalar) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    public init(lhs: Vec4, operator: Operator, rhs: Scalar) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    public init(lhs: UVec4, operator: Operator, rhs: Scalar) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    public init(lhs: Vec2, operator: Operator, rhs: Vec2) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    public init(lhs: Vec3, operator: Operator, rhs: Vec3) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    public init(lhs: Vec4, operator: Operator, rhs: Vec4) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    public init(lhs: UVec4, operator: Operator, rhs: UVec4) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    public init(lhs: Mat3, operator: Operator, rhs: Vec3) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    public init(lhs: Mat3, operator: Operator, rhs: Mat3) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    public init(lhs: Mat4, operator: Operator, rhs: Vec4) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    public init(lhs: Mat4, operator: Operator, rhs: Mat4) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    internal init(lhs: Sampler2D, rhs: Vec2, operator: Operator) {
        self.operator = `operator`
        self.value1 = lhs
        self.value2 = rhs
    }
    
    internal init<T: ShaderValue>(comparison: Operator.Comparison, success: T,  failure: T) {
        self.operator = .compare(comparison)
        self.value1 = success
        self.value2 = failure
    }
    
    internal init<T: ShaderValue>(compare: Scalar, success: T, failure: T) {
        self.operator = .branch(comparing: compare)
        self.value1 = success
        self.value2 = failure
    }
    
    internal init<T: ShaderValue>(discardIf compare: Scalar, success: T) {
        self.operator = .discard(comparing: compare)
        self.value1 = success
        self.value2 = Void()
    }
}
