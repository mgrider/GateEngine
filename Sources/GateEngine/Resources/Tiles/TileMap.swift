/*
 * Copyright © 2023 Dustin Collins (Strega's Gate)
 * All Rights Reserved.
 *
 * http://stregasgate.com
 */

#if GATEENGINE_PLATFORM_FOUNDATION_FILEMANAGER
import Foundation
#endif
import GameMath

@MainActor public class TileMap: Resource {
    internal let cacheKey: ResourceManager.Cache.TileMapKey
    
    public var cacheHint: CacheHint {
        get { Game.shared.resourceManager.tileMapCache(for: cacheKey)!.cacheHint }
        set { Game.shared.resourceManager.changeCacheHint(newValue, for: cacheKey) }
    }

    public var state: ResourceState {
        return Game.shared.resourceManager.tileMapCache(for: cacheKey)!.state
    }
    
    @usableFromInline
    internal var backend: TileMapBackend {
        return Game.shared.resourceManager.tileMapCache(for: cacheKey)!.tileMapBackend!
    }
    
    public var layers: [Layer] {
        return self.backend.layers
    }

    public var size: Size2 {
        return layers.first?.size ?? .zero
    }

    public init(
        path: String,
        options: TileMapImporterOptions = .none
    ) {
        let resourceManager = Game.shared.resourceManager
        self.cacheKey = resourceManager.tileMapCacheKey(
            path: path,
            options: options
        )
        self.cacheHint = .until(minutes: 5)
        resourceManager.incrementReference(self.cacheKey)
    }
    
    public init(layers: [Layer]) {
        let resourceManager = Game.shared.resourceManager
        self.cacheKey = resourceManager.tileMapCacheKey(layers: layers)
        self.cacheHint = .until(minutes: 5)
        resourceManager.incrementReference(self.cacheKey)
    }
    
    public struct Tile {
        public let id: Int
        public let options: Options
        public struct Options: OptionSet {
            public let rawValue: UInt
            public init(rawValue: UInt) {
                self.rawValue = rawValue
            }
            
            public static let flippedHorizontal    = Options(rawValue: 0x80000000)
            public static let flippedVertical      = Options(rawValue: 0x40000000)
            public static let flippedDiagonal      = Options(rawValue: 0x20000000)
            public static let rotatedHexagonal120  = Options(rawValue: 0x10000000)
        }
    }
    

    public struct Layer {
        public let name: String?
        public let size: Size2
        public let tileSize: Size2
        public let tiles: [[Tile]]
        
        public var rows: Int {
            return tiles.count
        }
        public var columns: Int {
            return tiles.first?.count ?? 0
        }

        public func tileIndexAtCoordinate(column: Int, row: Int) -> Int {
            return tiles[row][column].id
        }

        public func tileIndexAtPosition(_ position: Position2) -> Int {
            let column = position.x / tileSize.width
            let row = position.y / tileSize.height
            return tileIndexAtCoordinate(column: Int(column), row: Int(row))
        }

        public func pixelCenterForTileAt(column: Int, row: Int) -> Position2 {
            return (Position2(Float(column), Float(row)) * tileSize)
        }

        init(name: String?, size: Size2, tileSize: Size2, tiles: [[Tile]]) {
            self.name = name
            self.size = size
            self.tileSize = tileSize
            self.tiles = tiles
        }
    }
    
    deinit {
        let cacheKey = self.cacheKey
        Task.detached(priority: .low) { @MainActor in
            Game.shared.resourceManager.decrementReference(cacheKey)
        }
    }
}

extension TileMap: Equatable, Hashable {
    nonisolated public static func == (lhs: TileMap, rhs: TileMap) -> Bool {
        return lhs.cacheKey == rhs.cacheKey
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(cacheKey)
    }
}

@MainActor public class TileMapBackend {
    public let layers: [TileMap.Layer]
    
    init(layers: [TileMap.Layer]) {
        self.layers = layers
    }
}

// MARK: - Resource Manager

public struct TileMapImporterOptions: Equatable, Hashable {
    public var subobjectName: String? = nil

    public static func named(_ name: String) -> Self {
        return TileMapImporterOptions(subobjectName: name)
    }

    public static var none: TileMapImporterOptions {
        return TileMapImporterOptions()
    }
}

public protocol TileMapImporter: AnyObject {
    init()

    func process(data: Data, baseURL: URL, options: TileMapImporterOptions) async throws -> TileMapBackend

    static func supportedFileExtensions() -> [String]
}

extension ResourceManager {
    public func addTileMapImporter(_ type: any TileMapImporter.Type) {
        guard importers.tileMapImporters.contains(where: { $0 == type }) == false else { return }
        importers.tileMapImporters.insert(type, at: 0)
    }

    fileprivate func importerForFileType(_ file: String) -> (any TileMapImporter)? {
        for type in self.importers.tileMapImporters {
            if type.supportedFileExtensions().contains(where: {
                $0.caseInsensitiveCompare(file) == .orderedSame
            }) {
                return type.init()
            }
        }
        return nil
    }
}

extension ResourceManager.Cache {
    @usableFromInline
    struct TileMapKey: Hashable {
        let requestedPath: String
        let tileMapOptions: TileMapImporterOptions
    }

    @usableFromInline
    class TileMapCache {
        @usableFromInline var tileMapBackend: TileMapBackend?
        var lastLoaded: Date
        var state: ResourceState
        var referenceCount: UInt
        var minutesDead: UInt
        var cacheHint: CacheHint
        init() {
            self.tileMapBackend = nil
            self.lastLoaded = Date()
            self.state = .pending
            self.referenceCount = 0
            self.minutesDead = 0
            self.cacheHint = .until(minutes: 5)
        }
    }
}
extension ResourceManager {
    func changeCacheHint(_ cacheHint: CacheHint, for key: Cache.TileMapKey) {
        if let tileSetCache = cache.tileMaps[key] {
            tileSetCache.cacheHint = cacheHint
            tileSetCache.minutesDead = 0
        }
    }
    
    func tileMapCacheKey(path: String, options: TileMapImporterOptions) -> Cache.TileMapKey {
        let key = Cache.TileMapKey(requestedPath: path, tileMapOptions: options)
        if cache.tileMaps[key] == nil {
            cache.tileMaps[key] = Cache.TileMapCache()
            self._reloadTileMap(for: key)
        }
        return key
    }
    
    func tileMapCacheKey(layers: [TileMap.Layer]) -> Cache.TileMapKey {
        let key = Cache.TileMapKey(requestedPath: "$\(rawCacheIDGenerator.generateID())", tileMapOptions: .none)
        if cache.tileMaps[key] == nil {
            cache.tileMaps[key] = Cache.TileMapCache()
            Task.detached(priority: .low) {
                let backend = await TileMapBackend(layers: layers)
                
                Task { @MainActor in
                    self.cache.tileMaps[key]!.tileMapBackend = backend
                    self.cache.tileMaps[key]!.state = .ready
                }
            }
        }
        return key
    }
    
    @usableFromInline
    func tileMapCache(for key: Cache.TileMapKey) -> Cache.TileMapCache? {
        return cache.tileMaps[key]
    }
    
    func incrementReference(_ key: Cache.TileMapKey) {
        self.tileMapCache(for: key)?.referenceCount += 1
    }
    func decrementReference(_ key: Cache.TileMapKey) {
        self.tileMapCache(for: key)?.referenceCount -= 1
    }
    
    func reloadTileMapIfNeeded(key: Cache.TileMapKey) {
        // Skip if made from RawGeometry
        guard key.requestedPath[key.requestedPath.startIndex] != "$" else { return }
        Task.detached(priority: .low) {
            guard self.tileMapNeedsReload(key: key) else { return }
            self._reloadTileMap(for: key)
        }
    }
    
    func _reloadTileMap(for key: Cache.TileMapKey) {
        Task.detached(priority: .low) {
            let path = key.requestedPath
            
            do {
                guard let fileExtension = path.components(separatedBy: ".").last else {
                    throw GateEngineError.failedToLoad("Unknown file type.")
                }
                guard
                    let importer: any TileMapImporter = await Game.shared.resourceManager
                        .importerForFileType(fileExtension)
                else {
                    throw GateEngineError.failedToLoad("No importer for \(fileExtension).")
                }

                let data = try await Game.shared.platform.loadResource(from: path)
                let backend = try await importer.process(
                    data: data,
                    baseURL: URL(string: path)!.deletingLastPathComponent(),
                    options: key.tileMapOptions
                )

                Task { @MainActor in
                    self.cache.tileMaps[key]!.tileMapBackend = backend
                    self.cache.tileMaps[key]!.state = .ready
                }
            } catch let error as GateEngineError {
                Task { @MainActor in
                    Log.warn("Resource \"\(path)\"", error)
                    self.cache.tileMaps[key]!.state = .failed(error: error)
                }
            } catch {
                Log.fatalError("error must be a GateEngineError")
            }
        }
    }
    
    func tileMapNeedsReload(key: Cache.TileMapKey) -> Bool {
        #if GATEENGINE_ENABLE_HOTRELOADING && GATEENGINE_PLATFORM_FOUNDATION_FILEMANAGER
        // Skip if made from RawGeometry
        guard key.requestedPath[key.requestedPath.startIndex] != "$" else { return false }
        guard let cache = cache.tileMaps[key] else { return false }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: key.requestedPath)
            if let modified = (attributes[.modificationDate] ?? attributes[.creationDate]) as? Date
            {
                return modified > cache.lastLoaded
            } else {
                return false
            }
        } catch {
            Log.error(error)
            return false
        }
        #else
        return false
        #endif
    }
}
