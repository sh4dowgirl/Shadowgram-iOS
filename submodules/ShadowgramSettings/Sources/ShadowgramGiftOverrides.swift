import Foundation
import SwiftSignalKit

/// "Gift Editing": a purely local, per-device overlay on top of a profile's real gift grid.
/// Stores opaque JSON blobs (one per gift) rather than a typed model, because the real gift
/// type lives in TelegramCore, which this module cannot import (TelegramCore itself imports
/// this module, and a typed `StarGift` here would need it). TelegramCore's
/// `shadowgramEncodeGift`/`shadowgramDecodeGift` do the encoding; this class only persists the
/// bytes and tells observers when something changed.
public final class ShadowgramGiftOverrides {
    public static let shared = ShadowgramGiftOverrides()

    private enum Key {
        static let added = "shadowgram.gifts.added"
        static let removed = "shadowgram.gifts.removed"
    }

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var added: [Int64: [Data]]
    private var removed: [Int64: [Data]]
    private let changePromise = ValuePromise<Void>(Void(), ignoreRepeated: false)

    private init() {
        let defaults = ShadowgramGiftOverrides.appGroupSuiteName().flatMap({ UserDefaults(suiteName: $0) }) ?? UserDefaults.standard
        self.defaults = defaults
        self.added = ShadowgramGiftOverrides.load(defaults, key: Key.added)
        self.removed = ShadowgramGiftOverrides.load(defaults, key: Key.removed)
    }

    private static func load(_ defaults: UserDefaults, key: String) -> [Int64: [Data]] {
        var result: [Int64: [Data]] = [:]
        for (stringKey, value) in (defaults.dictionary(forKey: key) as? [String: [Data]]) ?? [:] {
            if let peerId = Int64(stringKey) {
                result[peerId] = value
            }
        }
        return result
    }

    private func persist() {
        var encodedAdded: [String: [Data]] = [:]
        for (peerId, items) in self.added {
            encodedAdded["\(peerId)"] = items
        }
        self.defaults.set(encodedAdded, forKey: Key.added)

        var encodedRemoved: [String: [Data]] = [:]
        for (peerId, items) in self.removed {
            encodedRemoved["\(peerId)"] = items
        }
        self.defaults.set(encodedRemoved, forKey: Key.removed)

        self.changePromise.set(Void())
    }

    /// Fires once on subscription and again after every change (to any peer - cheap to
    /// re-filter, and keeps every open gifts view in sync without threading peer ids through).
    public var changeSignal: Signal<Void, NoError> {
        return self.changePromise.get()
    }

    public func addedGifts(peerId: Int64) -> [Data] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.added[peerId] ?? []
    }

    public func removedGifts(peerId: Int64) -> [Data] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.removed[peerId] ?? []
    }

    public func appendAddedGift(peerId: Int64, gift: Data) {
        self.lock.lock()
        var items = self.added[peerId] ?? []
        items.append(gift)
        self.added[peerId] = items
        self.lock.unlock()
        self.persist()
    }

    public func removeAddedGift(peerId: Int64, at index: Int) {
        self.lock.lock()
        var items = self.added[peerId] ?? []
        if items.indices.contains(index) {
            items.remove(at: index)
        }
        self.added[peerId] = items
        self.lock.unlock()
        self.persist()
    }

    /// Moves a real gift from the visible grid into the locally-removed list, so it can be
    /// restored later from the "removed gifts" screen.
    public func hideRealGift(peerId: Int64, gift: Data) {
        self.lock.lock()
        var items = self.removed[peerId] ?? []
        items.append(gift)
        self.removed[peerId] = items
        self.lock.unlock()
        self.persist()
    }

    public func restoreRealGift(peerId: Int64, at index: Int) {
        self.lock.lock()
        var items = self.removed[peerId] ?? []
        if items.indices.contains(index) {
            items.remove(at: index)
        }
        self.removed[peerId] = items
        self.lock.unlock()
        self.persist()
    }

    /// `group.<main app bundle id>`, the same app group Telegram-iOS uses for its shared data.
    private static func appGroupSuiteName() -> String? {
        guard var bundleId = Bundle.main.bundleIdentifier else {
            return nil
        }
        if Bundle.main.bundlePath.hasSuffix(".appex"), let range = bundleId.range(of: ".", options: .backwards) {
            bundleId = String(bundleId[..<range.lowerBound])
        }
        return "group.\(bundleId)"
    }
}
