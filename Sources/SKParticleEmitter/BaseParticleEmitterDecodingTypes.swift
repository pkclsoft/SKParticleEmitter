//
//  BaseParticleEmitterDecodingTypes.swift
//  ParticleEmitterDemo-SK
//
//  These types are used by the BaseParticleEmitter class to facilitate the "simpler" parsing of the
//  emitter configuration file.  Unfortunately, the fields within the file all have their values as
//  attributes, so that necessitate the creation of these wrapper types.  I was originally concerned
//  that they would cause problems with performance for the emitter, however tests show it to be OK.
//
//  Created by Peter Easdown on 30/3/21.
//  Copyright © 2021 71Squared Ltd. All rights reserved.
//

import Foundation
import CoreGraphics
import SpriteKit
import Gzip
import XMLCoder

/// Extension to allow parsing of the ParticleType.
///
extension ParticleTypes : Codable, DynamicNodeDecoding {
    
    static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
    
    enum CodingKeys: String, CodingKey {
        case value
    }
    
    enum DecodeError : Error {
        case ParticleTypeError
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        if let value = try? values.decode(Int.self, forKey: .value) {
            self = ParticleTypes(rawValue: value)!
            return
        }
        
        if let value = try? values.decode(String.self, forKey: .value) {
            self = ParticleTypes(rawValue: Int(value)!)!
            return
        }
        
        throw DecodeError.ParticleTypeError
    }
    
}

/// This struct provides us with a parsable equivalent of the GLKVector2 type.  Ultimately, it would be good to remove all of the GLK references.
///
public struct Vector2 : Codable, DynamicNodeDecoding {
    
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
    
    var x : Float
    var y : Float
    
    enum CodingKeys : String, CodingKey {
        case x
        case y
    }
    
    public static var zero : Vector2 {
        get {
            return .init(0.0, 0.0)
        }
    }
    
    func asGLVector2() -> GLKVector2 {
        return GLKVector2Make(x, y)
    }
    
    public init(_ x: PEFloat, _ y: PEFloat) {
        self.x = x.float
        self.y = y.float
    }
    
    public init(_ x: Double, _ y: Double) {
        self.x = .init(x)
        self.y = .init(y)
    }
    
    public init(_ x: Float, _ y: Float) {
        self.x = .init(x)
        self.y = .init(y)
    }
    
    public init(_ point: CGPoint) {
        self.x = .init(point.x)
        self.y = .init(point.y)
    }
    
    public init(_ glVec: GLKVector2) {
        self.x = .init(glVec.x)
        self.y = .init(glVec.y)
    }
    
    static func -(left : Vector2, right: Vector2) -> Vector2 {
        return Vector2(left.x - right.x, left.y - right.y)
    }
    
    static func +(left : Vector2, right: Vector2) -> Vector2 {
        return Vector2(left.x + right.x, left.y + right.y)
    }
}

/// This struct provides us with a parsable equivalent of the GLKVector4 type, used just for colours.  Ultimately, it would be good to remove all of the GLK references.
///
struct PEColor : Codable, DynamicNodeDecoding {
    
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
    
    var r : Float
    var g : Float
    var b : Float
    var a : Float
    
    enum CodingKeys : String, CodingKey {
        case r = "red"
        case g = "green"
        case b = "blue"
        case a = "alpha"
    }
    
    init(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
    
    static var zero : PEColor {
        get {
            return .init(0.0, 0.0, 0.0, 0.0)
        }
    }
    
    #if os(macOS)
    func asUIColor() -> NSColor {
        return NSColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
    #else
    func asUIColor() -> UIColor {
        return UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
    #endif
    
    // MARK :- Mathematical operators.
    
    static func +=(left : inout PEColor, right: PEColor) {
        left.r += right.r
        left.g += right.g
        left.b += right.b
        left.a += right.a
    }
    
    static func +(left : PEColor, right: PEColor) -> PEColor {
        return PEColor(left.r + right.r,
                       left.g + right.g,
                       left.b + right.b,
                       left.a + right.a)
    }

    static func -(left : PEColor, right: PEColor) -> PEColor {
        return PEColor(left.r - right.r,
                       left.g - right.g,
                       left.b - right.b,
                       left.a - right.a)
    }

    static func *(left : PEColor, right: PEFloat) -> PEColor {
        return left * right.float
    }

    static func *(left : PEColor, right: Float) -> PEColor {
        return PEColor(left.r * right,
                       left.g * right,
                       left.b * right,
                       left.a * right)
    }

    static func /(left : PEColor, right: PEFloat) -> PEColor {
        return left / right.float
    }

    static func /(left : PEColor, right: Float) -> PEColor {
        return PEColor(left.r / right,
                       left.g / right,
                       left.b / right,
                       left.a / right)
    }
}

/// This struct provides us with a parsable equivalent of the Int type as an attribute.
///
public struct PEInt : Codable, DynamicNodeDecoding {
    
    var value : Int
    
    enum CodingKeys : String, CodingKey {
        case value
    }
    
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
    
    public init(_ val: Int) {
        self.value = val
    }
    
    var int : Int {
        get {
            return value
        }
        
        set {
            value = newValue
        }
    }
    
}

/// This struct provides us with a parsable equivalent of the Float type as an attribute.
///
public struct PEFloat : Codable, DynamicNodeDecoding {
    
    var value : Float
    
    enum CodingKeys : String, CodingKey {
        case value
    }
    
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
    
    var float : Float {
        get {
            return value
        }
        
        set {
            value = newValue
        }
    }
    
    public init(_ val: Float) {
        value = val
    }
    
    public init(_ val: Double) {
        value = Float(val)
    }
    
    public static var zero : PEFloat {
        get {
            return PEFloat(0.0)
        }
    }
    
    // MARK :- Mathematical operators.
    
    static func +(left : PEFloat, right: PEFloat) -> PEFloat {
        return PEFloat(left.value + right.value)
    }
    
    static func +(left : Float, right: PEFloat) -> PEFloat {
        return PEFloat(left + right.value)
    }
    
    static func +(left : PEFloat, right: Float) -> PEFloat {
        return PEFloat(left.value + right)
    }
    
    static func +=( left : inout PEFloat, right: PEFloat) {
        left.value += right.value
    }
    
    static func -(left : PEFloat, right: PEFloat) -> PEFloat {
        return PEFloat(left.value - right.value)
    }
    
    static func -(left : Float, right: PEFloat) -> PEFloat {
        return PEFloat(left - right.value)
    }
    
    static func -(left : PEFloat, right: Float) -> PEFloat {
        return PEFloat(left.value - right)
    }
    
    static func -=( left : inout PEFloat, right: PEFloat) {
        left.value -= right.value
    }
    
    static func *(left : PEFloat, right: PEFloat) -> PEFloat {
        return PEFloat(left.value * right.value)
    }
    
    static func *(left : Float, right: PEFloat) -> PEFloat {
        return PEFloat(left * right.value)
    }
    
    static func *(left : PEFloat, right: Float) -> PEFloat {
        return PEFloat(left.value * right)
    }
    
    static func /(left : PEFloat, right: PEFloat) -> PEFloat {
        return PEFloat(left.value / right.value)
    }
    
    static func /(left : Float, right: PEFloat) -> PEFloat {
        return PEFloat(left / right.value)
    }
    
    static func /(left : PEFloat, right: Float) -> PEFloat {
        return PEFloat(left.value / right)
    }
    
    static func >(left : PEFloat, right: PEFloat) -> Bool {
        return left.value > right.value
    }
    
    static func >(left : PEFloat, right: Float) -> Bool {
        return left.value > right
    }
    
    static func <(left : PEFloat, right: PEFloat) -> Bool {
        return left.value < right.value
    }
    
    static func >=(left : PEFloat, right: PEFloat) -> Bool {
        return left.value >= right.value
    }
    
    static func <=(left : PEFloat, right: PEFloat) -> Bool {
        return left.value <= right.value
    }
    
    static func ==(left : PEFloat, right: PEFloat) -> Bool {
        return left.value == right.value
    }
    
    static func !=(left : PEFloat, right: PEFloat) -> Bool {
        return left.value != right.value
    }
    
    static func !=(left : Float, right: PEFloat) -> Bool {
        return left != right.value
    }
    
    static func !=(left : PEFloat, right: Float) -> Bool {
        return left.value != right
    }
    
}

/// This struct provides us with a parsable equivalent of the texture property of an emitter.
///
struct PETexture : Codable, DynamicNodeDecoding {
    
    var name : String
    var data : String
    
    enum CodingKeys : String, CodingKey {
        case name
        case data
    }
    
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .attribute
    }
    
    /// Unzip the string obtained from the configuration file.  Uses Gzip package from https://github.com/1024jp/GzipSwift
    /// - Parameter data: The gzipped data as obtained from the configuration file.
    /// - Returns: A Data object containing the inflated output of the gunzip operation, or nil of that operation failed.
    private func inflated(data: Data) -> Data? {
        if data.count == 0 {
            return data
        }
        
        do {
            return try data.gunzipped()
        } catch {
            print(error.localizedDescription)
            
            return Data()
        }
    }
    
    /// Attempts to locate a named image asset if a name is provided by the emitter configuration file, and no compressed image data is present,
    /// or returns an image formed from the decompressed image data.
    /// - Returns: A UIImage object representing the texture to use for the emitter.
    #if os(macOS)
    func image() -> NSImage? {
        if name.count > 0 && data.count == 0 {
            return NSImage(named: name)
        } else if data.count > 0 {
            if let tiffData = self.inflated(data: Data(base64Encoded: data)!) {
                return NSImage(data: tiffData)
            }
        }
        
        return nil
    }
    #else
    func image() -> UIImage? {
        if name.count > 0 && data.count == 0 {
            return UIImage(named: name)
        } else if data.count > 0 {
            if let tiffData = self.inflated(data: Data(base64Encoded: data)!) {
                return UIImage(data: tiffData)
            }
        }
        
        return nil
    }
    #endif
    
    /// Returns a SKTexture object containing the texture specified by the emitter configuration.
    /// - Returns: A SKTexture object, or nil if no image could be determined.
    func texture() -> SKTexture? {
        if let image = self.image() {
            return SKTexture(image: image)
        }
        
        return nil
    }
}
