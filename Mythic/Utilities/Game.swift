//
//  Game.swift
//  Mythic
//
//  Created by Esiayo Alegbe on 13/6/2024.
//

import Foundation
import Combine
import OSLog
import UserNotifications
import SwordRPC
import SwiftUI

class Game: ObservableObject, Hashable, Codable, Identifiable, Equatable {
    // MARK: Stubs
    static func == (lhs: Game, rhs: Game) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: Hash
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: Initializer
    init(source: Source, title: String, id: String? = nil, platform: Platform? = nil, imageURL: URL? = nil, wideImageURL: URL? = nil, path: String? = nil) {
        self.source = source
        self.title = title
        self.id = id ?? UUID().uuidString
        self.platform = platform
        self.imageURL = imageURL
        self.wideImageURL = wideImageURL
        self.path = path
    }
    
    // MARK: Mutables
    var source: Source
    var title: String
    var id: String
    
    private var _platform: Platform?
    var platform: Platform? {
        get { return _platform ?? (self.source == .epic ? try? Legendary.getGamePlatform(game: self) : nil) }
        set { _platform = newValue }
    }
    
    private var _imageURL: URL?
    var imageURL: URL? {
        get { _imageURL ?? (self.source == .epic ? .init(string: Legendary.getImage(of: self, type: .tall)) : nil) }
        set { _imageURL = newValue }
    }
    
    private var _wideImageURL: URL?
    var wideImageURL: URL? {
        get { _imageURL ?? (self.source == .epic ? .init(string: Legendary.getImage(of: self, type: .normal)) : nil) }
        set { _imageURL = newValue }
    }

    private var _path: String?
    var path: String? {
        get { _path ?? (self.source == .epic ? try? Legendary.getGamePath(game: self) : nil) }
        set { _path = newValue }
    }
    
    // MARK: Properties
    var containerURL: URL? {
        get {
            let key: String = id.appending("_containerURL")
            if let url = defaults.url(forKey: key), !Wine.containerExists(at: url) {
                defaults.removeObject(forKey: key)
            }
            
            if defaults.url(forKey: key) == nil {
                defaults.set(Wine.containerURLs.first, forKey: key)
            }
            
            return defaults.url(forKey: key)
        }
        set {
            let key: String = id.appending("_containerURL")
            guard let newValue = newValue else { defaults.set(nil, forKey: key); return }
            if Wine.containerURLs.contains(newValue) {
                defaults.set(newValue, forKey: key)
            }
        }
    }
    
    var launchArguments: [String] {
        get {
            let key: String = id.appending("_launchArguments")
            return defaults.array(forKey: key) as? [String] ?? .init()
        }
        set {
            defaults.set(newValue, forKey: id.appending("_launchArguments"))
        }
    }
    
    var isFavourited: Bool {
        get { favouriteGames.contains(id) }
        set {
            if newValue {
                favouriteGames.insert(id)
            } else {
                favouriteGames.remove(id)
            }
        }
    }
    
    var isInstalled: Bool {
        switch self.source {
        case .epic:
            let games = try? Legendary.getInstalledGames()
            return games?.contains(self) == true
        case .local:
            return true
        }
    }

    var needsUpdate: Bool {
        switch self.source {
        case .epic:
            return Legendary.needsUpdate(game: self)
        case .local:
            return false
        }
    }

    var isInstalling: Bool { GameOperation.shared.current?.game == self }
    var isQueuedForInstalling: Bool { GameOperation.shared.queue.contains(where: { $0.game == self }) }
    var isLaunching: Bool { GameOperation.shared.launching == self }

    // MARK: Functions
    func move(to newLocation: URL) async throws {
        switch source {
        case .epic:
            try await Legendary.move(game: self, newPath: newLocation.path(percentEncoded: false))
            path = try! Legendary.getGamePath(game: self) // swiftlint:disable:this force_try
        case .local:
            if let oldLocation = path {
                if files.isWritableFile(atPath: newLocation.path(percentEncoded: false)) {
                    try files.moveItem(atPath: oldLocation, toPath: newLocation.path(percentEncoded: false)) // not very good
                } else {
                    throw FileLocations.FileNotModifiableError(nil)
                }
            }
        }
    }

    func launch() async throws {
        switch source {
        case .epic:
            try await Legendary.launch(game: self)
        case .local:
            try await LocalGames.launch(game: self)
        }
    }

    /// Enumeration containing the two different game platforms available.
    enum Platform: String, CaseIterable, Codable, Hashable {
        case macOS = "macOS"
        case windows = "Windows®"
    }

    /// Enumeration containing all available game types.
    enum Source: String, CaseIterable, Codable, Hashable {
        case epic = "Epic"
        case local = "Local"
    }

    enum InclusivePlatform: String, CaseIterable {
        case all = "All"
        case macOS = "macOS"
        case windows = "Windows®"
    }

    enum InclusiveSource: String, CaseIterable {
        case all = "All"
        case epic = "Epic"
        case local = "Local"
    }
}

/// Returns the app names of all favourited games.
var favouriteGames: Set<String> {
    get { return Set(defaults.stringArray(forKey: "favouriteGames") ?? .init()) }
    set { defaults.set(Array(newValue), forKey: "favouriteGames") }
}

enum GameModificationType: String {
    case install = "installing"
    case update = "updating"
    case repair = "repairing"
    // case uninstall = "uninstalling"
}

@available(*, deprecated, renamed: "GameOperation", message: "womp")
@Observable class GameModification: ObservableObject {
    static var shared: GameModification = .init()
    
    var game: Mythic.Game?
    var type: GameModificationType?
    var status: [String: [String: Any]]?
    
    static func reset() {
        Task { @MainActor in
            shared.game = nil
            shared.type = nil
            shared.status = nil
        }
    }
    
    var launching: Game? // no other place bruh
}

class GameOperation: ObservableObject {
    static var shared: GameOperation = .init()
    
    internal static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "GameOperation"
    )
    
    func install() throws {
        // TODO: implement
    }
    
    // swiftlint:disable:next redundant_optional_initialization
    @Published var current: InstallArguments? = nil {
        didSet {
            // @ObservedObject var operation: GameOperation = .shared
            guard GameOperation.shared.current != oldValue, GameOperation.shared.current != nil else { return }
            switch GameOperation.shared.current!.game.source {
            case .epic:
                Task(priority: .high) { [weak self] in
                    guard self != nil else { return }
                    do {
                        try await Legendary.install(args: GameOperation.shared.current!, priority: false)
                        try? await notifications.add(
                            .init(identifier: UUID().uuidString,
                                  content: {
                                      let content = UNMutableNotificationContent()
                                      content.title = "Finished \(GameOperation.shared.current?.type.rawValue ?? "modifying") \"\(GameOperation.shared.current?.game.title ?? "Unknown")\"."
                                      return content
                                  }(),
                                  trigger: nil)
                        )
                    } catch {
                        Task { @MainActor in
                            let alert = NSAlert()
                            alert.messageText = "Error \(GameOperation.shared.current?.type.rawValue ?? "modifying") \"\(GameOperation.shared.current?.game.title ?? "Unknown")\"."
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "OK")
                            
                            if let window = NSApp.windows.first {
                                alert.beginSheetModal(for: window)
                            }
                        }
                    }
                    
                    DispatchQueue.main.asyncAndWait {
                        GameOperation.shared.current = nil
                    }
                    
                    GameOperation.advance()
                }
            case .local: // this should literally never happen how do you install a local game
                DispatchQueue.main.asyncAndWait {
                    GameOperation.shared.current = nil
                }
            }
        }
    }
    
    @Published var status: GameOperation.InstallStatus = .init()
    
    @Published var queue: [InstallArguments] = .init() {
        didSet { GameOperation.advance() }
    }
    
    static func advance() {
        log.debug("[operation.advance] attempting operation advancement")
        guard shared.current == nil, let first = shared.queue.first else { return }
        Task { @MainActor in
            shared.status = InstallStatus()
        }
        log.debug("[operation.advance] queuing configuration can advance, no active downloads, game present in queue")
        Task { @MainActor in
            shared.current = first; shared.queue.removeFirst()
            log.debug("[operation.advance] queuing configuration advanced. current game will now begin installation. (\(shared.current!.game.title))")
        }
    }
    
    @Published var runningGames: Set<Game> = .init()
    
    private func checkIfGameOpen(_ game: Game) async {
        guard let gamePath = game.path, let gamePlatform = game.platform else { return }

        var isOpen = true
        defer {
            discordRPC.setPresence({
                var presence = RichPresence()
                presence.details = "Just finished playing \(game.title)"
                presence.state = "Idle"
                presence.timestamps.start = .now
                presence.assets.largeImage = "macos_512x512_2x"
                return presence
            }())
        }

        GameOperation.log.debug("now monitoring \(gamePlatform.rawValue) game \(game.title)")

        Task { @MainActor in
            GameOperation.shared.runningGames.insert(game)
        }

        discordRPC.setPresence({
            var presence = RichPresence()
            presence.details = "Playing a \(gamePlatform.rawValue) game."
            presence.state = "Playing \(game.title)"
            presence.timestamps.start = .now
            presence.assets.largeImage = "macos_512x512_2x"
            return presence
        }())

        while isOpen {
            GameOperation.log.debug("checking if \"\(game.title)\" is still running")
            
            let isRunning = {
                switch gamePlatform {
                case .macOS:
                    workspace.runningApplications.contains(where: { $0.bundleURL?.path == gamePath }) // debounce may be necessary because macOS is slow at opening apps
                case .windows:
                    (try? Process.execute("/bin/bash", arguments: ["-c", "ps aux | grep -i '\(gamePath)' | grep -v grep"]))?.isEmpty == false
                }
            }()
            
            if !isRunning {
                Task { @MainActor in GameOperation.shared.runningGames.remove(game) }
                isOpen = false
            } else {
                try? await Task.sleep(for: .seconds(3))
            }
            
            GameOperation.log.debug("\"\(game.title)\" \(isRunning ? "is still running" : "has been quit" )")
        }
    }
    
    // swiftlint:disable:next redundant_optional_initialization
    @Published var launching: Game? = nil {
        didSet {
            guard launching == nil, let oldValue = oldValue else { return }
            Task(priority: .background) { await checkIfGameOpen(oldValue) }
        }
    }
    
    struct InstallArguments: Equatable, Hashable {
        var game: Mythic.Game,
            platform: Mythic.Game.Platform,
            type: GameModificationType,
            // swiftlint:disable redundant_optional_initialization
            optionalPacks: [String]? = nil,
            baseURL: URL? = nil,
            gameFolder: URL? = nil
            // swiftlint:enable redundant_optional_initialization
    }
    
    struct InstallStatus {
        // swiftlint:disable nesting
        struct Progress {
            var percentage: Double
            var downloadedObjects: Int
            var totalObjects: Int
            var runtime: String
            var eta: String
        }
        
        struct Download {
            var downloaded: Double
            var written: Double
        }
        
        struct Cache {
            var usage: Double
            var activeTasks: Int
        }
        
        struct DownloadSpeed {
            var raw: Double
            var decompressed: Double
        }
        
        struct DiskSpeed {
            var write: Double
            var read: Double
        }
        // swiftlint:enable nesting
        
        var progress: Progress?
        var download: Download?
        var cache: Cache?
        var downloadSpeed: DownloadSpeed?
        var diskSpeed: DiskSpeed?
    }
}

/// Your father.
struct GameDoesNotExistError: LocalizedError {
    init(_ game: Mythic.Game) { self.game = game }
    let game: Mythic.Game
    var errorDescription: String? = "This game doesn't exist."
}
