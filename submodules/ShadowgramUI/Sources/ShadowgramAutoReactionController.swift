import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import ItemListPeerItem
import ItemListPeerActionItem
import PresentationDataUtils
import AccountContext
import LocalizedPeerData
import TextFormat
import EntityKeyboard
import ShadowgramSettings

/// A message can carry at most this many reactions from one account (matches the limit a
/// Premium account has when picking reactions by hand), so a peer can be added at most this
/// many times.
let shadowgramAutoReactionMaxPerPeer = 3

private final class ShadowgramAutoReactionArguments {
    let context: AccountContext
    let addUser: () -> Void
    let openUser: (EnginePeer.Id, Int) -> Void
    let removeUser: (EnginePeer.Id, Int) -> Void
    let setPeerIdWithRevealedOptions: (ShadowgramAutoReactionRowId?, ShadowgramAutoReactionRowId?) -> Void
    let setInGroups: (Bool) -> Void

    init(context: AccountContext, addUser: @escaping () -> Void, openUser: @escaping (EnginePeer.Id, Int) -> Void, removeUser: @escaping (EnginePeer.Id, Int) -> Void, setPeerIdWithRevealedOptions: @escaping (ShadowgramAutoReactionRowId?, ShadowgramAutoReactionRowId?) -> Void, setInGroups: @escaping (Bool) -> Void) {
        self.context = context
        self.addUser = addUser
        self.openUser = openUser
        self.removeUser = removeUser
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.setInGroups = setInGroups
    }
}

/// Identifies one row - a peer can occupy up to `shadowgramAutoReactionMaxPerPeer` rows, one per
/// occurrence, so the peer id alone is not a unique row identity any more.
struct ShadowgramAutoReactionRowId: Hashable {
    let peerId: EnginePeer.Id
    let occurrenceIndex: Int
}

private enum ShadowgramAutoReactionTag: ItemListItemTag, Equatable {
    case addUser
    case row(ShadowgramAutoReactionRowId)

    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? ShadowgramAutoReactionTag {
            return self == other
        } else {
            return false
        }
    }
}

private struct ShadowgramAutoReactionState: Equatable {
    var rowIdWithRevealedOptions: ShadowgramAutoReactionRowId?
}

private enum ShadowgramAutoReactionEntryId: Hashable {
    case groupsSwitch
    case groupsFooter
    case header
    case addUser
    case row(ShadowgramAutoReactionRowId)
    case footer
}

private enum ShadowgramAutoReactionEntry: ItemListNodeEntry {
    case groupsSwitch(Bool)
    case groupsFooter
    case header
    case addUser
    case user(index: Int32, rowId: ShadowgramAutoReactionRowId, peer: EnginePeer, reaction: ShadowgramAutoReactionValue, editing: ItemListPeerItemEditing)
    case footer

    var section: ItemListSectionId {
        switch self {
        case .groupsSwitch, .groupsFooter:
            return 0
        default:
            return 1
        }
    }

    var stableId: ShadowgramAutoReactionEntryId {
        switch self {
        case .groupsSwitch:
            return .groupsSwitch
        case .groupsFooter:
            return .groupsFooter
        case .header:
            return .header
        case .addUser:
            return .addUser
        case let .user(_, rowId, _, _, _):
            return .row(rowId)
        case .footer:
            return .footer
        }
    }

    private var sortIndex: Int32 {
        switch self {
        case .groupsSwitch:
            return -2
        case .groupsFooter:
            return -1
        case .header:
            return 0
        case .addUser:
            return 1
        case let .user(index, _, _, _, _):
            return 2 + index
        case .footer:
            return Int32.max
        }
    }

    static func <(lhs: ShadowgramAutoReactionEntry, rhs: ShadowgramAutoReactionEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ShadowgramAutoReactionArguments
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        switch self {
        case let .groupsSwitch(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.autoReactionInGroups, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.setInGroups(value)
            })
        case .groupsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.autoReactionInGroupsFooter), sectionId: self.section)
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.autoReactionUsersHeader, sectionId: self.section)
        case .addUser:
            return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.addPersonIcon(presentationData.theme), title: strings.autoReactionAddUser, sectionId: self.section, height: .peerList, editing: false, action: {
                arguments.addUser()
            }, tag: ShadowgramAutoReactionTag.addUser)
        case let .user(_, rowId, peer, reaction, editing):
            let font = Font.regular(floor(presentationData.fontSize.itemListBaseFontSize * 20.0 / 17.0))
            let label: NSAttributedString
            switch reaction {
            case let .emoji(emoji):
                label = NSAttributedString(string: emoji, font: font, textColor: presentationData.theme.list.itemPrimaryTextColor)
            case let .custom(fileId):
                label = NSAttributedString(string: "😀", attributes: [
                    .font: font,
                    .foregroundColor: presentationData.theme.list.itemPrimaryTextColor,
                    ChatTextInputAttributes.customEmoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: nil)
                ])
            }
            return ItemListPeerItem(presentationData: presentationData, systemStyle: .glass, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: arguments.context, peer: peer, presence: nil, text: .none, label: .attributedText(label), editing: editing, enabled: true, selectable: true, sectionId: self.section, action: {
                arguments.openUser(rowId.peerId, rowId.occurrenceIndex)
            }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                arguments.setPeerIdWithRevealedOptions(peerId.map { ShadowgramAutoReactionRowId(peerId: $0, occurrenceIndex: rowId.occurrenceIndex) }, fromPeerId.map { _ in rowId })
            }, removePeer: { _ in
                arguments.removeUser(rowId.peerId, rowId.occurrenceIndex)
            }, tag: ShadowgramAutoReactionTag.row(rowId))
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.autoReactionFooter), sectionId: self.section)
        }
    }
}

private func shadowgramAutoReactionEntries(presentationData: PresentationData, state: ShadowgramAutoReactionState, autoReactions: [Int64: [ShadowgramAutoReactionValue]], peers: [EnginePeer], inGroups: Bool) -> [ShadowgramAutoReactionEntry] {
    var entries: [ShadowgramAutoReactionEntry] = []
    entries.append(.groupsSwitch(inGroups))
    entries.append(.groupsFooter)
    entries.append(.header)
    entries.append(.addUser)
    let sortedPeers = peers.sorted { lhs, rhs in
        let lhsTitle = lhs.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        let rhsTitle = rhs.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        let result = lhsTitle.localizedCaseInsensitiveCompare(rhsTitle)
        if result == .orderedSame {
            return lhs.id.toInt64() < rhs.id.toInt64()
        }
        return result == .orderedAscending
    }
    var index: Int32 = 0
    for peer in sortedPeers {
        guard let reactions = autoReactions[peer.id.toInt64()], !reactions.isEmpty else {
            continue
        }
        for (occurrenceIndex, reaction) in reactions.enumerated() {
            let rowId = ShadowgramAutoReactionRowId(peerId: peer.id, occurrenceIndex: occurrenceIndex)
            entries.append(.user(index: index, rowId: rowId, peer: peer, reaction: reaction, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: state.rowIdWithRevealedOptions == rowId)))
            index += 1
        }
    }
    entries.append(.footer)
    return entries
}

public func shadowgramAutoReactionSummary(values: ShadowgramSettingsValues, strings: ShadowgramStrings) -> String {
    if values.autoReactions.isEmpty {
        return strings.autoReactionOff
    }
    return strings.autoReactionUserCount(values.autoReactions.count)
}

private func shadowgramAutoReactionSourceView(controller: ItemListController, tag: ShadowgramAutoReactionTag) -> UIView? {
    var result: UIView?
    controller.forEachItemNode { itemNode in
        if let taggedNode = itemNode as? ItemListItemNode, let itemTag = taggedNode.tag, itemTag.isEqual(to: tag) {
            result = itemNode.view
        }
    }
    return result
}

/// `occurrenceIndex`: nil appends a new reaction for `peerId` (capped at
/// `shadowgramAutoReactionMaxPerPeer`); a value replaces that existing occurrence.
private func shadowgramPresentAutoReactionSelector(context: AccountContext, controller: ItemListController, peerId: EnginePeer.Id, occurrenceIndex: Int?, anchor: ShadowgramAutoReactionTag) {
    let isPremium = context.isPremium
    let existing = ShadowgramSettings.shared.values.autoReactions[peerId.toInt64()] ?? []
    let current = occurrenceIndex.flatMap { existing.indices.contains($0) ? existing[$0] : nil }
    let _ = (context.engine.stickers.availableReactions()
    |> take(1)
    |> deliverOnMainQueue).start(next: { [weak controller] availableReactions in
        guard let controller else {
            return
        }
        let sourceView: UIView = shadowgramAutoReactionSourceView(controller: controller, tag: anchor) ?? controller.view

        var selectedItems = Set<EngineMedia.Id>()
        if let current {
            switch current {
            case let .emoji(emoji):
                if let reaction = availableReactions?.reactions.first(where: { $0.value == .builtin(emoji) }) {
                    selectedItems.insert(reaction.selectAnimation.fileId)
                }
            case let .custom(fileId):
                selectedItems.insert(EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: fileId))
            }
        }

        let selectionController = context.sharedContext.makeEmojiStatusSelectionController(
            context: context,
            mode: .customStatusSelection(completion: { file, _ in
                guard let file else {
                    return
                }
                let value: ShadowgramAutoReactionValue
                if let reaction = availableReactions?.reactions.first(where: { $0.selectAnimation.fileId == file.fileId }) {
                    guard case let .builtin(emoji) = reaction.value else {
                        return
                    }
                    value = .emoji(emoji)
                } else if isPremium {
                    value = .custom(file.fileId.id)
                } else {
                    return
                }
                ShadowgramSettings.shared.update { settings in
                    var reactions = settings.autoReactions[peerId.toInt64()] ?? []
                    if let occurrenceIndex, reactions.indices.contains(occurrenceIndex) {
                        reactions[occurrenceIndex] = value
                    } else if !reactions.contains(value) && reactions.count < shadowgramAutoReactionMaxPerPeer {
                        reactions.append(value)
                    }
                    if reactions.isEmpty {
                        settings.autoReactions.removeValue(forKey: peerId.toInt64())
                    } else {
                        settings.autoReactions[peerId.toInt64()] = reactions
                    }
                }
            }),
            sourceView: sourceView,
            emojiContent: EmojiPagerContentComponent.emojiInputData(
                context: context,
                animationCache: context.animationCache,
                animationRenderer: context.animationRenderer,
                isStandalone: false,
                subject: .reactionList,
                hasTrending: false,
                topReactionItems: [],
                areUnicodeEmojiEnabled: false,
                areCustomEmojiEnabled: isPremium,
                chatPeerId: nil,
                selectedItems: selectedItems
            ) |> map { $0 as AnyObject },
            currentSelection: nil,
            color: nil,
            destinationItemView: {
                return nil
            }
        )
        controller.present(selectionController, in: .window(.root))
    })
}

public func shadowgramAutoReactionController(context: AccountContext) -> ViewController {
    let initialState = ShadowgramAutoReactionState(rowIdWithRevealedOptions: nil)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ShadowgramAutoReactionState) -> ShadowgramAutoReactionState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    weak var weakController: ItemListController?

    let arguments = ShadowgramAutoReactionArguments(context: context, addUser: {
        guard let controller = weakController else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        // Users and broadcast channels (a channel's own posts show the channel as the author),
        // but not groups/supergroups or secret chats - those aren't valid auto-reaction targets.
        let peerController = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.excludeGroups, .excludeSavedMessages, .excludeSecretChats, .excludeBots, .removeSearchHeader, .excludeRecent, .doNotSearchMessages], title: strings.autoReactionSelectUser))
        peerController.peerSelected = { [weak peerController] peer, _ in
            peerController?.dismiss()
            let isValidTarget: Bool
            switch peer {
            case let .user(user):
                isValidTarget = user.botInfo == nil
            case let .channel(channel):
                if case .broadcast = channel.info {
                    isValidTarget = true
                } else {
                    isValidTarget = false
                }
            default:
                isValidTarget = false
            }
            guard isValidTarget, peer.id != context.account.peerId else {
                return
            }
            let peerId = peer.id
            let existingCount = (ShadowgramSettings.shared.values.autoReactions[peerId.toInt64()] ?? []).count
            guard existingCount < shadowgramAutoReactionMaxPerPeer else {
                return
            }
            Queue.mainQueue().after(0.45, {
                guard let controller = weakController else {
                    return
                }
                shadowgramPresentAutoReactionSelector(context: context, controller: controller, peerId: peerId, occurrenceIndex: nil, anchor: .addUser)
            })
        }
        controller.push(peerController)
    }, openUser: { peerId, occurrenceIndex in
        guard let controller = weakController else {
            return
        }
        let rowId = ShadowgramAutoReactionRowId(peerId: peerId, occurrenceIndex: occurrenceIndex)
        shadowgramPresentAutoReactionSelector(context: context, controller: controller, peerId: peerId, occurrenceIndex: occurrenceIndex, anchor: .row(rowId))
    }, removeUser: { peerId, occurrenceIndex in
        updateState { state in
            var state = state
            state.rowIdWithRevealedOptions = nil
            return state
        }
        ShadowgramSettings.shared.update { settings in
            var reactions = settings.autoReactions[peerId.toInt64()] ?? []
            if reactions.indices.contains(occurrenceIndex) {
                reactions.remove(at: occurrenceIndex)
            }
            if reactions.isEmpty {
                settings.autoReactions.removeValue(forKey: peerId.toInt64())
            } else {
                settings.autoReactions[peerId.toInt64()] = reactions
            }
        }
    }, setPeerIdWithRevealedOptions: { rowId, fromRowId in
        updateState { state in
            if (rowId == nil && fromRowId == state.rowIdWithRevealedOptions) || (rowId != nil && fromRowId == nil) {
                var state = state
                state.rowIdWithRevealedOptions = rowId
                return state
            } else {
                return state
            }
        }
    }, setInGroups: { value in
        ShadowgramSettings.shared.update { $0.autoReactionsInGroups = value }
    })

    let peers: Signal<([Int64: [ShadowgramAutoReactionValue]], [EnginePeer]), NoError> = ShadowgramSettings.shared.valuesSignal
    |> map { $0.autoReactions }
    |> distinctUntilChanged
    |> mapToSignal { autoReactions -> Signal<([Int64: [ShadowgramAutoReactionValue]], [EnginePeer]), NoError> in
        let peerIds = autoReactions.keys.map { EnginePeer.Id($0) }
        if peerIds.isEmpty {
            return .single((autoReactions, []))
        }
        return context.engine.data.subscribe(EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)))
        |> map { peerMap -> ([Int64: [ShadowgramAutoReactionValue]], [EnginePeer]) in
            var peers: [EnginePeer] = []
            for peerId in peerIds {
                if let maybePeer = peerMap[peerId], let peer = maybePeer {
                    peers.append(peer)
                }
            }
            return (autoReactions, peers)
        }
    }

    let inGroups: Signal<Bool, NoError> = ShadowgramSettings.shared.valuesSignal
    |> map { $0.autoReactionsInGroups }
    |> distinctUntilChanged

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        peers,
        inGroups
    )
    |> map { presentationData, state, peers, inGroups -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.autoReaction), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: shadowgramAutoReactionEntries(presentationData: presentationData, state: state, autoReactions: peers.0, peers: peers.1, inGroups: inGroups), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    weakController = controller
    return controller
}
