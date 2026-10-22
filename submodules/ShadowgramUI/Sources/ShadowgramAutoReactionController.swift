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

private final class ShadowgramAutoReactionArguments {
    let context: AccountContext
    let addUser: () -> Void
    let openUser: (EnginePeer.Id) -> Void
    let removeUser: (EnginePeer.Id) -> Void
    let setPeerIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void

    init(context: AccountContext, addUser: @escaping () -> Void, openUser: @escaping (EnginePeer.Id) -> Void, removeUser: @escaping (EnginePeer.Id) -> Void, setPeerIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void) {
        self.context = context
        self.addUser = addUser
        self.openUser = openUser
        self.removeUser = removeUser
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
    }
}

private enum ShadowgramAutoReactionTag: ItemListItemTag, Equatable {
    case addUser
    case user(EnginePeer.Id)

    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? ShadowgramAutoReactionTag {
            return self == other
        } else {
            return false
        }
    }
}

private struct ShadowgramAutoReactionState: Equatable {
    var peerIdWithRevealedOptions: EnginePeer.Id?
}

private enum ShadowgramAutoReactionEntryId: Hashable {
    case header
    case addUser
    case user(EnginePeer.Id)
    case footer
}

private enum ShadowgramAutoReactionEntry: ItemListNodeEntry {
    case header
    case addUser
    case user(index: Int32, peer: EnginePeer, reaction: ShadowgramAutoReactionValue, editing: ItemListPeerItemEditing)
    case footer

    var section: ItemListSectionId {
        return 0
    }

    var stableId: ShadowgramAutoReactionEntryId {
        switch self {
        case .header:
            return .header
        case .addUser:
            return .addUser
        case let .user(_, peer, _, _):
            return .user(peer.id)
        case .footer:
            return .footer
        }
    }

    private var sortIndex: Int32 {
        switch self {
        case .header:
            return 0
        case .addUser:
            return 1
        case let .user(index, _, _, _):
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
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.autoReactionUsersHeader, sectionId: self.section)
        case .addUser:
            return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.addPersonIcon(presentationData.theme), title: strings.autoReactionAddUser, sectionId: self.section, height: .peerList, editing: false, action: {
                arguments.addUser()
            }, tag: ShadowgramAutoReactionTag.addUser)
        case let .user(_, peer, reaction, editing):
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
                arguments.openUser(peer.id)
            }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                arguments.setPeerIdWithRevealedOptions(peerId, fromPeerId)
            }, removePeer: { peerId in
                arguments.removeUser(peerId)
            }, tag: ShadowgramAutoReactionTag.user(peer.id))
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.autoReactionFooter), sectionId: self.section)
        }
    }
}

private func shadowgramAutoReactionEntries(presentationData: PresentationData, state: ShadowgramAutoReactionState, autoReactions: [Int64: ShadowgramAutoReactionValue], peers: [EnginePeer]) -> [ShadowgramAutoReactionEntry] {
    var entries: [ShadowgramAutoReactionEntry] = []
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
        guard let reaction = autoReactions[peer.id.toInt64()] else {
            continue
        }
        entries.append(.user(index: index, peer: peer, reaction: reaction, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: state.peerIdWithRevealedOptions == peer.id)))
        index += 1
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

private func shadowgramPresentAutoReactionSelector(context: AccountContext, controller: ItemListController, peerId: EnginePeer.Id, anchor: ShadowgramAutoReactionTag) {
    let isPremium = context.isPremium
    let current = ShadowgramSettings.shared.values.autoReactions[peerId.toInt64()]
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
                ShadowgramSettings.shared.update { $0.autoReactions[peerId.toInt64()] = value }
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
    let initialState = ShadowgramAutoReactionState(peerIdWithRevealedOptions: nil)
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
        let peerController = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyPrivateChats, .excludeSavedMessages, .excludeSecretChats, .excludeBots, .removeSearchHeader, .excludeRecent, .doNotSearchMessages], title: strings.autoReactionSelectUser))
        peerController.peerSelected = { [weak peerController] peer, _ in
            peerController?.dismiss()
            guard case let .user(user) = peer, user.botInfo == nil, peer.id != context.account.peerId else {
                return
            }
            let peerId = peer.id
            Queue.mainQueue().after(0.45, {
                guard let controller = weakController else {
                    return
                }
                shadowgramPresentAutoReactionSelector(context: context, controller: controller, peerId: peerId, anchor: .addUser)
            })
        }
        controller.push(peerController)
    }, openUser: { peerId in
        guard let controller = weakController else {
            return
        }
        shadowgramPresentAutoReactionSelector(context: context, controller: controller, peerId: peerId, anchor: .user(peerId))
    }, removeUser: { peerId in
        updateState { state in
            var state = state
            state.peerIdWithRevealedOptions = nil
            return state
        }
        ShadowgramSettings.shared.update { $0.autoReactions[peerId.toInt64()] = nil }
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                var state = state
                state.peerIdWithRevealedOptions = peerId
                return state
            } else {
                return state
            }
        }
    })

    let peers: Signal<([Int64: ShadowgramAutoReactionValue], [EnginePeer]), NoError> = ShadowgramSettings.shared.valuesSignal
    |> map { $0.autoReactions }
    |> distinctUntilChanged
    |> mapToSignal { autoReactions -> Signal<([Int64: ShadowgramAutoReactionValue], [EnginePeer]), NoError> in
        let peerIds = autoReactions.keys.map { EnginePeer.Id($0) }
        if peerIds.isEmpty {
            return .single((autoReactions, []))
        }
        return context.engine.data.subscribe(EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)))
        |> map { peerMap -> ([Int64: ShadowgramAutoReactionValue], [EnginePeer]) in
            var peers: [EnginePeer] = []
            for peerId in peerIds {
                if let maybePeer = peerMap[peerId], let peer = maybePeer {
                    peers.append(peer)
                }
            }
            return (autoReactions, peers)
        }
    }

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        peers
    )
    |> map { presentationData, state, peers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.autoReaction), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: shadowgramAutoReactionEntries(presentationData: presentationData, state: state, autoReactions: peers.0, peers: peers.1), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    weakController = controller
    return controller
}
