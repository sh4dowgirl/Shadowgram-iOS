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

/// A gift this feature adds carries a made-up `.peer` reference whose id has this marker in its top
/// 16 bits ("SG"), so the grid can key it like a real gift (a stable identity, which is what lets
/// its neighbours animate when one is removed) and the editor can still tell it apart. Real saved
/// gift ids are small server counters and never reach these bits.
private let shadowgramLocalGiftIdMarker: Int64 = 0x5347 << 48
private let shadowgramLocalGiftIdMask: Int64 = (1 << 48) - 1

public func shadowgramMakeLocalGiftReference(peerId: EnginePeer.Id) -> StarGiftReference {
    return .peer(peerId: peerId, id: shadowgramLocalGiftIdMarker | Int64.random(in: 1 ... shadowgramLocalGiftIdMask))
}

private func shadowgramIsLocalGiftReference(_ reference: StarGiftReference) -> Bool {
    if case let .peer(_, id) = reference {
        return (id & ~shadowgramLocalGiftIdMask) == shadowgramLocalGiftIdMarker
    }
    return false
}

/// Gifts saved before references were assigned have none; they get one derived from their bytes,
/// so it stays the same across launches.
private func shadowgramDecodeAddedGift(_ data: Data, peerId: PeerId) -> ProfileGiftsContext.State.StarGift? {
    guard let gift = shadowgramDecodeGift(data) else {
        return nil
    }
    if gift.reference != nil {
        return gift
    }
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in data {
        hash = (hash ^ UInt64(byte)) &* 0x100000001b3
    }
    let id = shadowgramLocalGiftIdMarker | max(1, Int64(bitPattern: hash) & shadowgramLocalGiftIdMask)
    return gift.shadowgramWith(reference: .peer(peerId: peerId, id: id), fromPeer: nil)
}

/// The senders of this profile's added gifts, which the context loads before publishing.
func shadowgramAddedGiftSenderIds(peerId: PeerId) -> [EnginePeer.Id] {
    guard ShadowgramSettings.shared.values.giftEditingEnabled else {
        return []
    }
    var result: [EnginePeer.Id] = []
    for blob in ShadowgramGiftOverrides.shared.addedGifts(peerId: peerId.toInt64()) {
        if let id = shadowgramDecodeGift(blob)?.shadowgramFromPeerId, !result.contains(id) {
            result.append(id)
        }
    }
    return result
}

/// Merges locally-added fake gifts on top, and drops locally-hidden real ones, from one gift
/// list (`ProfileGiftsContextImpl` calls this once for its full list and once for its filtered
/// view - both need the same treatment since either can be what the pane actually renders).
func shadowgramOverlayGifts(peerId: PeerId, base: [ProfileGiftsContext.State.StarGift], includeAdded: Bool, peers: [EnginePeer.Id: EnginePeer]) -> [ProfileGiftsContext.State.StarGift] {
    guard ShadowgramSettings.shared.values.giftEditingEnabled else {
        return base
    }
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

    let addedBlobs = includeAdded ? overrides.addedGifts(peerId: key) : []
    if !addedBlobs.isEmpty {
        let addedGifts = addedBlobs.compactMap { blob -> ProfileGiftsContext.State.StarGift? in
            guard let gift = shadowgramDecodeAddedGift(blob, peerId: peerId) else {
                return nil
            }
            if gift.fromPeer == nil, let senderId = gift.shadowgramFromPeerId, let sender = peers[senderId] {
                return gift.shadowgramWith(reference: gift.reference, fromPeer: sender)
            }
            return gift
        }
        // Pinned gifts stay first, as on a real profile; added ones follow them.
        let pinnedCount = result.prefix(while: { $0.pinnedToTop }).count
        let addedPinned = addedGifts.filter { $0.pinnedToTop }
        let addedOther = addedGifts.filter { !$0.pinnedToTop }
        result = addedPinned + Array(result.prefix(pinnedCount)) + addedOther + Array(result.dropFirst(pinnedCount))
    }

    return result
}

/// A gift this feature added locally never got a real `StarGiftReference` (nothing was ever
/// created server-side), so that's also how the editor tells a client-added entry apart from a
/// real one - the green/yellow dot the person asked for.
public func shadowgramGiftIsLocallyAdded(_ gift: ProfileGiftsContext.State.StarGift) -> Bool {
    guard let reference = gift.reference else {
        return true
    }
    return shadowgramIsLocalGiftReference(reference)
}

/// Whether a server action on this reference must be skipped: it names a gift that exists only here.
public func shadowgramIsLocalGift(reference: StarGiftReference) -> Bool {
    return shadowgramIsLocalGiftReference(reference)
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
        // By reference: the grid's copy has its sender filled in, the stored one only its id.
        if let index = items.firstIndex(where: { shadowgramDecodeAddedGift($0, peerId: peerId)?.reference == gift.reference }) {
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
