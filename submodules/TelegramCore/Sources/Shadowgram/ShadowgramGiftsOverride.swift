import Foundation
import Postbox
import SwiftSignalKit
import ShadowgramSettings

/// "Gift Editing": JSON round-trip for one gift grid entry. `ProfileGiftsContext.State.StarGift`
/// (and everything it embeds - the sticker file, a unique gift's model/backdrop/pattern
/// attributes, ...) is `Codable`, so storing the real value is simpler and more faithful than
/// inventing a parallel lightweight model; `ShadowgramGiftOverrides` only ever sees the opaque
/// bytes.
public func shadowgramEncodeGift(_ gift: ProfileGiftsContext.State.StarGift) -> Data? {
    return try? JSONEncoder().encode(gift)
}

public func shadowgramDecodeGift(_ data: Data) -> ProfileGiftsContext.State.StarGift? {
    return try? JSONDecoder().decode(ProfileGiftsContext.State.StarGift.self, from: data)
}

/// Merges locally-added fake gifts on top, and drops locally-hidden real ones, from one gift
/// list (`ProfileGiftsContextImpl` calls this once for its full list and once for its filtered
/// view - both need the same treatment since either can be what the pane actually renders).
func shadowgramOverlayGifts(peerId: PeerId, base: [ProfileGiftsContext.State.StarGift]) -> [ProfileGiftsContext.State.StarGift] {
    let overrides = ShadowgramGiftOverrides.shared
    let key = peerId.toInt64()

    var result = base
    let removedBlobs = overrides.removedGifts(peerId: key)
    if !removedBlobs.isEmpty {
        let removedReferences = Set(removedBlobs.compactMap { shadowgramDecodeGift($0)?.reference })
        if !removedReferences.isEmpty {
            result = result.filter { gift in
                guard let reference = gift.reference else {
                    return true
                }
                return !removedReferences.contains(reference)
            }
        }
    }

    let addedBlobs = overrides.addedGifts(peerId: key)
    if !addedBlobs.isEmpty {
        let addedGifts = addedBlobs.compactMap { shadowgramDecodeGift($0) }
        result = addedGifts + result
    }

    return result
}

/// A gift this feature added locally never got a real `StarGiftReference` (nothing was ever
/// created server-side), so that's also how the editor tells a client-added entry apart from a
/// real one - the green/yellow dot the person asked for.
public func shadowgramGiftIsLocallyAdded(_ gift: ProfileGiftsContext.State.StarGift) -> Bool {
    return gift.reference == nil
}

/// Adds a fabricated gift to the grid - purely local, nothing is sent to the server.
public func shadowgramAddEditedGift(peerId: EnginePeer.Id, gift: ProfileGiftsContext.State.StarGift) {
    guard let data = shadowgramEncodeGift(gift) else {
        return
    }
    ShadowgramGiftOverrides.shared.appendAddedGift(peerId: peerId.toInt64(), gift: data)
}

/// The minus button on one grid entry in edit mode: a client-added gift is deleted outright
/// (nothing to restore - it never existed anywhere else); a real one is only hidden, and can be
/// brought back from the "removed gifts" screen.
public func shadowgramRemoveEditedGift(peerId: EnginePeer.Id, gift: ProfileGiftsContext.State.StarGift) {
    let key = peerId.toInt64()
    if shadowgramGiftIsLocallyAdded(gift) {
        let items = ShadowgramGiftOverrides.shared.addedGifts(peerId: key)
        if let index = items.firstIndex(where: { shadowgramDecodeGift($0) == gift }) {
            ShadowgramGiftOverrides.shared.removeAddedGift(peerId: key, at: index)
        }
    } else if let data = shadowgramEncodeGift(gift) {
        ShadowgramGiftOverrides.shared.hideRealGift(peerId: key, gift: data)
    }
}

/// The "removed gifts" screen's contents: every real gift hidden from this profile, each with
/// the index needed to restore it.
public func shadowgramRemovedGifts(peerId: EnginePeer.Id) -> [(index: Int, gift: ProfileGiftsContext.State.StarGift)] {
    let blobs = ShadowgramGiftOverrides.shared.removedGifts(peerId: peerId.toInt64())
    var result: [(index: Int, gift: ProfileGiftsContext.State.StarGift)] = []
    for (index, blob) in blobs.enumerated() {
        if let gift = shadowgramDecodeGift(blob) {
            result.append((index, gift))
        }
    }
    return result
}

public func shadowgramRestoreRemovedGift(peerId: EnginePeer.Id, index: Int) {
    ShadowgramGiftOverrides.shared.restoreRealGift(peerId: peerId.toInt64(), at: index)
}
