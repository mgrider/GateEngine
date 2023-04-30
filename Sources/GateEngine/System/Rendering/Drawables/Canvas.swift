/*
 * Copyright © 2023 Dustin Collins (Strega's Gate)
 * All Rights Reserved.
 *
 * http://stregasgate.com
 */

import Foundation
import GameMath

/**
 A Canvas is a drawing space with no depth and an orthographic camera.
 */
@MainActor public struct Canvas {
    @usableFromInline let interfaceScale: Float
    @usableFromInline internal var viewport: Rect? = nil
    
    @usableFromInline internal var size: Size2? = nil
    @usableFromInline internal var camera: Camera? = nil
    
    internal var drawCommands: [DrawCommand] = []
    
    @inlinable
    public mutating func setCamera(_ camera: Camera, size: Size2) {
        self.camera = camera
        self.size = size
    }
    
    @inlinable
    public mutating func setViewport(_ viewport: Rect?) {
        self.viewport = viewport
    }
    
    @inline(__always)
    public mutating func insert(_ points: Points, pointSize: Float, at position: Position2, rotation: any Angle = Radians.zero, scale: Size2 = .one, depth: Float = 0, opacity: Float = 1, flags: CanvasElementPrimitiveFlags = .default) {
        guard points.state == .ready else {return}
        guard let geometryBackend = Game.shared.resourceManager.geometryCache(for: points.cacheKey)?.geometryBackend else {return}

        let position = Position3(position.x, position.y, depth * -1)
        let scale = Size3(scale.x, scale.y, 1)
        let rotation = Quaternion(rotation, axis: .forward)
        let transform = Transform3(position: position, rotation: rotation, scale: scale)
        
        let material = Material { material in
            material.vertexShader = SystemShaders.pointSizeAndColorVertexShader
            material.fragmentShader = SystemShaders.vertexColorFragmentShader
            material.setCustomUniformValue(pointSize, forUniform: "pointSize")
        }
        let flags = DrawFlags(cull: .back, depthTest: .lessThan, depthWrite: .enabled, primitive: .point, winding: .clockwise, blendMode: .normal)
        let command = DrawCommand(geometries: [geometryBackend], transforms: [transform], material: material, flags: flags)
        drawCommands.append(command)
    }

    @inline(__always)
    public mutating func insert(_ lines: Lines, at position: Position2, rotation: any Angle = Radians.zero, scale: Size2 = .one, depth: Float = 0, opacity: Float = 1, flags: CanvasElementPrimitiveFlags = .default) {
        guard lines.state == .ready else {return}
        guard let geometryBackend = Game.shared.resourceManager.geometryCache(for: lines.cacheKey)?.geometryBackend else {return}

        let position = Position3(position.x, position.y, depth * -1)
        let scale = Size3(scale.x, scale.y, 1)
        let rotation = Quaternion(rotation, axis: .forward)
        let transform = Transform3(position: position, rotation: rotation, scale: scale)
        
        let material = Material { material in
            material.vertexShader = SystemShaders.colorsVertexShader
            material.fragmentShader = SystemShaders.vertexColorFragmentShader
        }
        let flags = DrawFlags(cull: .back, depthTest: .lessThan, depthWrite: .enabled, primitive: .line, winding: .clockwise, blendMode: .normal)
        let command = DrawCommand(geometries: [geometryBackend], transforms: [transform], material: material, flags: flags)
        drawCommands.append(command)
    }
    
    @inline(__always)
    public mutating func insert(_ rect: Rect, color: Color, at position: Position2, rotation: any Angle = Radians.zero, scale: Size2 = .one, depth: Float = 0, opacity: Float = 1, flags: CanvasElementPrimitiveFlags = .default) {
        guard Game.shared.renderer.rectOriginTopLeft.state == .ready else {return}
        guard let geometryBackend = Game.shared.resourceManager.geometryCache(for: Game.shared.renderer.rectOriginTopLeft.cacheKey)?.geometryBackend else {return}
        
        let position = Position3(position.x + rect.position.x, position.y + rect.position.y, depth * -1)
        let scale = Size3(scale.x, scale.y, 1) * Size3(rect.size.width, rect.size.height, 1)
        let rotation = Quaternion(rotation, axis: .forward)
        let transform = Transform3(position: position, rotation: rotation, scale: scale)
        
        let material = Material(color: color)
        let flags = DrawFlags(cull: .disabled, depthTest: .always, depthWrite: .disabled, primitive: .triangle, winding: .clockwise, blendMode: .normal)
        let command = DrawCommand(geometries: [geometryBackend], transforms: [transform], material: material, flags: flags)
        drawCommands.append(command)
    }
    
    @inline(__always)
    public mutating func insert(_ sprite: Sprite, at position: Position2, rotation: any Angle = Radians.zero, scale: Size2 = .one, depth: Float = 0, opacity: Float = 1, flags: CanvasElementSpriteFlags = .default) {
        guard sprite.isReady && Game.shared.renderer.rectOriginCentered.state == .ready else {return}
        guard let geometryBackend = Game.shared.resourceManager.geometryCache(for: Game.shared.renderer.rectOriginCentered.cacheKey)?.geometryBackend else {return}

        let position = Position3(position.x, position.y, depth * -1)
        let scale = Size3(scale.x, scale.y, 1) * sprite.geometryScale
        let rotation = Quaternion(rotation, axis: .forward)
        let transform = Transform3(position: position, rotation: rotation, scale: scale)
        
        let material = Material { material in
            material.channel(0) { channel in
                channel.texture = sprite.texture
                channel.scale = sprite.uvScale
                channel.offset = sprite.uvOffset
            }
        }

        let flags = DrawFlags(cull: .disabled, depthTest: .always, depthWrite: .disabled, primitive: .triangle, winding: .clockwise, blendMode: .normal)
        let command = DrawCommand(geometries: [geometryBackend], transforms: [transform], material: material, flags: flags)
        drawCommands.append(command)
    }
    
    @inline(__always)
    public mutating func insert(_ text: Text, at position: Position2, rotation: any Angle = Radians.zero, scale: Size2 = .one, depth: Float = 0, opacity: Float = 1, flags: CanvasElementTextFlags = .default) {
        guard text.string.isEmpty == false else {return}
        text.interfaceScale = self.interfaceScale
        guard text.isReady else {return}
        guard let geometryBackend = Game.shared.resourceManager.geometryCache(for: text.geometry.cacheKey)?.geometryBackend else {return}
        
        let position = Position3(position.x, position.y, depth * -1)
        let scale = Size3(scale.x, scale.y, 1)
        let rotation = Quaternion(rotation, axis: .forward)
        let transform = Transform3(position: position, rotation: rotation, scale: scale)
        
        let material = Material(texture: text.texture)
        
        let flags = DrawFlags(cull: .disabled, depthTest: .always, depthWrite: .disabled, primitive: .triangle, winding: .clockwise, blendMode: .normal)
        let command = DrawCommand(geometries: [geometryBackend], transforms: [transform], material: material, flags: flags)
        drawCommands.append(command)
    }
    
    @inline(__always)
    public mutating func insert(_ geometry: Geometry, withMaterial material: Material, at position: Position2, rotation: any Angle = Radians.zero, scale: Size2 = .one, depth: Float = 0, flags: SceneElementFlags = .default) {
        guard geometry.state == .ready else {return}
        guard material.isReady else {return}
        guard let geometryBackend = Game.shared.resourceManager.geometryCache(for: geometry.cacheKey)?.geometryBackend else {return}

        let position = Position3(position.x, position.y, depth * -1)
        let scale = Size3(scale.x, scale.y, 1)
        let rotation = Quaternion(rotation, axis: .forward)
        let transform = Transform3(position: position, rotation: rotation, scale: scale)

        let command = DrawCommand(geometries: [geometryBackend], transforms: [transform], material: material, flags: flags.drawFlags)
        drawCommands.append(command)
    }
    
    /**
     Get a canvas position for a scene position.
     
     This function requires you to first call `setCamera(_:size:)`.
     - returns: A 2D position representing the location of a 3D object.
     */
    @inlinable
    public func convertFrom3DSpace(_ position: Position3) -> Position2 {
        guard let camera = camera else {preconditionFailure("Must set camera during `Canvas.init` to use \(#function).")}
        guard let size = size else {preconditionFailure("Must set size during `Canvas.init` to use \(#function).")}

        let matricies = camera.matricies(withAspectRatio: size.aspectRatio)
        var position = position * matricies.viewProjection()
        position.x /= position.z
        position.y /= position.z

        position.x = size.width * (position.x + 1) / 2
        position.y = size.height * (1.0 - ((position.y + 1) / 2))
        
        position.x /= self.interfaceScale
        position.y /= self.interfaceScale

        return Position2(position.x, position.y)
    }
    
    /**
     Create a canvas.
     
     - parameter camera: An optional Scene camera, which is required for 3D space convertions.
     - parameter size: The exact size of the canvas, this should be the saizxe of your renderTarget.
     - parameter interfaceScale: The userInterface scale. Sometimes called HiDPI. This setting changes how some drawable items are layed out. Use `1` for traditional gaming style drawing.
     */
    public init(camera: Camera? = nil, size: Size2? = nil, interfaceScale: Float = 1) {
        self.interfaceScale = interfaceScale
        self.drawCommands.reserveCapacity(10)
        self.size = size
        self.camera = camera
    }
    
    @_transparent
    internal var hasContent: Bool {
        return drawCommands.isEmpty == false
    }
    
    @_transparent
    internal func matrices(withSize size: Size2) -> Matrices {
        let ortho = Matrix4x4(orthographicWithTop: 0, left: 0, bottom: size.height, right: size.width, near: 0, far: Float(Int32.max))
        let view = Matrix4x4(position: Position3(x: -(viewport?.position.x ?? 0), y: -(viewport?.position.y ?? 0), z: 1000000)) * Matrix4x4(scale: Size3(interfaceScale, interfaceScale, 1))
        return Matrices(projection: ortho, view: view)
    }
    
    @_transparent
    internal var renderTargets: Set<RenderTarget> {
        var renderTargets: Set<RenderTarget> = []
        for command in drawCommands {
            renderTargets.formUnion(command.renderTargets)
        }
        return renderTargets
    }
}

public struct CanvasElementSpriteFlags: OptionSet {
    public typealias RawValue = UInt32
    public let rawValue: RawValue
        
    public static let flipHorizontal = CanvasElementSpriteFlags(rawValue: 1 << 1)
    public static let flipVertical = CanvasElementSpriteFlags(rawValue: 1 << 2)
    public static let flipDiagonal = CanvasElementSpriteFlags(rawValue: 1 << 3)

    public static let `default`: CanvasElementSpriteFlags = []
    
    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

public struct CanvasElementTextFlags: OptionSet {
    public typealias RawValue = UInt32
    public let rawValue: RawValue
    
    public static let flipHorizontal = CanvasElementTextFlags(rawValue: 1 << 1)
    public static let flipVertical = CanvasElementTextFlags(rawValue: 1 << 2)
    public static let flipDiagonal = CanvasElementTextFlags(rawValue: 1 << 3)
        
    public static let `default`: CanvasElementTextFlags = []
    
    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

public struct CanvasElementPrimitiveFlags: OptionSet {
    public typealias RawValue = UInt32
    public let rawValue: RawValue

    public static let `default`: CanvasElementPrimitiveFlags = []

    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}
