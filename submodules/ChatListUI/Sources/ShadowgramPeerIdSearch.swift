import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import ShadowgramSettings

private func shadowgramPeerIdCandidates(query: String) -> [EnginePeer.Id] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let value = Int64(trimmed), value != 0 else {
        return []
    }
    if value > 0 {
        let id = EnginePeer.Id.Id._internalFromInt64Value(value)
        return [
            EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: id),
            EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: id),
            EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: id)
        ]
    }
    let positive = -value
    if trimmed.hasPrefix("-100"), positive > 1_000_000_000_000 {
        return [EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(positive - 1_000_000_000_000))]
    }
    return [EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(positive))]
}

func shadowgramPeersMatchingId(context: AccountContext, query: String) -> Signal<[EngineRenderedPeer], NoError> {
    guard ShadowgramSettings.shared.values.openByPeerId else {
        return .single([])
    }
    let candidates = shadowgramPeerIdCandidates(query: query)
    if candidates.isEmpty {
        return .single([])
    }
    let local: Signal<[EnginePeer], NoError> = context.engine.data.get(EngineDataMap(candidates.map(TelegramEngine.EngineData.Item.Peer.Peer.init)))
    |> map { peerMap -> [EnginePeer] in
        return candidates.compactMap { id -> EnginePeer? in
            if let maybePeer = peerMap[id], let peer = maybePeer {
                return peer
            }
            return nil
        }
    }
    return local
    |> mapToSignal { found -> Signal<[EngineRenderedPeer], NoError> in
        let localPeers = found.map { EngineRenderedPeer(peer: $0) }
        var remoteSignals: [Signal<EnginePeer?, NoError>] = []
        if let channelId = candidates.first(where: { $0.namespace == Namespaces.Peer.CloudChannel }), !found.contains(where: { $0.id == channelId }) {
            remoteSignals.append(context.engine.peers.findChannelById(channelId: channelId.id._internalGetInt64Value()))
        }
        if let userId = candidates.first(where: { $0.namespace == Namespaces.Peer.CloudUser }), !found.contains(where: { $0.id == userId }) {
            remoteSignals.append(context.engine.peers.findUserById(userId: userId.id._internalGetInt64Value()))
        }
        if remoteSignals.isEmpty {
            return .single(localPeers)
        }
        let remote: Signal<[EngineRenderedPeer], NoError> = combineLatest(remoteSignals)
        |> map { peers -> [EngineRenderedPeer] in
            return localPeers + peers.compactMap { $0 }.map { EngineRenderedPeer(peer: $0) }
        }
        return .single(localPeers) |> then(remote)
    }
}

func shadowgramPrependingPeersMatchingId(context: AccountContext, query: String, peers: Signal<[EngineRenderedPeer], NoError>) -> Signal<[EngineRenderedPeer], NoError> {
    return combineLatest(shadowgramPeersMatchingId(context: context, query: query), peers)
    |> map { idPeers, peers -> [EngineRenderedPeer] in
        if idPeers.isEmpty {
            return peers
        }
        let idPeerIds = Set(idPeers.map { $0.peerId })
        return idPeers + peers.filter { !idPeerIds.contains($0.peerId) }
    }
}
