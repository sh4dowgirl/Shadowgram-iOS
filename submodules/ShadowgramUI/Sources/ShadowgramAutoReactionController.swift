import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import SettingsUI
import ShadowgramSettings

private final class ShadowgramAutoReactionArguments {
    let setMode: (ShadowgramAutoReactionMode) -> Void
    let openReaction: () -> Void
    let openExceptions: (Bool) -> Void

    init(setMode: @escaping (ShadowgramAutoReactionMode) -> Void, openReaction: @escaping () -> Void, openExceptions: @escaping (Bool) -> Void) {
        self.setMode = setMode
        self.openReaction = openReaction
        self.openExceptions = openExceptions
    }
}

private enum ShadowgramAutoReactionSection: Int32 {
    case mode
    case reaction
    case exceptions
}

private enum ShadowgramAutoReactionEntry: ItemListNodeEntry {
    case modeHeader
    case mode(ShadowgramAutoReactionMode, Bool)
    case modeFooter
    case reactionHeader
    case reaction(String)
    case exceptionsHeader
    case always(Int)
    case never(Int)
    case exceptionsFooter

    var section: ItemListSectionId {
        switch self {
        case .modeHeader, .mode, .modeFooter:
            return ShadowgramAutoReactionSection.mode.rawValue
        case .reactionHeader, .reaction:
            return ShadowgramAutoReactionSection.reaction.rawValue
        case .exceptionsHeader, .always, .never, .exceptionsFooter:
            return ShadowgramAutoReactionSection.exceptions.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .modeHeader:
            return 0
        case let .mode(mode, _):
            switch mode {
            case .everybody:
                return 1
            case .contacts:
                return 2
            case .nobody:
                return 3
            }
        case .modeFooter:
            return 4
        case .reactionHeader:
            return 5
        case .reaction:
            return 6
        case .exceptionsHeader:
            return 7
        case .always:
            return 8
        case .never:
            return 9
        case .exceptionsFooter:
            return 10
        }
    }

    static func <(lhs: ShadowgramAutoReactionEntry, rhs: ShadowgramAutoReactionEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ShadowgramAutoReactionArguments
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        switch self {
        case .modeHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.autoReactionWhoHeader, sectionId: self.section)
        case let .mode(mode, checked):
            let title: String
            switch mode {
            case .everybody:
                title = strings.autoReactionEverybody
            case .contacts:
                title = strings.autoReactionContacts
            case .nobody:
                title = strings.autoReactionNobody
            }
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.setMode(mode)
            })
        case .modeFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.autoReactionWhoFooter), sectionId: self.section)
        case .reactionHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.autoReactionReactionHeader, sectionId: self.section)
        case let .reaction(reaction):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: strings.autoReactionReaction, label: reaction, sectionId: self.section, style: .blocks, action: {
                arguments.openReaction()
            })
        case .exceptionsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.autoReactionExceptionsHeader, sectionId: self.section)
        case let .always(count):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: strings.autoReactionAlways, label: strings.autoReactionPeerCount(count), sectionId: self.section, style: .blocks, action: {
                arguments.openExceptions(true)
            })
        case let .never(count):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: strings.autoReactionNever, label: strings.autoReactionPeerCount(count), sectionId: self.section, style: .blocks, action: {
                arguments.openExceptions(false)
            })
        case .exceptionsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.autoReactionExceptionsFooter), sectionId: self.section)
        }
    }
}

private func shadowgramAutoReactionEntries(values: ShadowgramSettingsValues) -> [ShadowgramAutoReactionEntry] {
    var entries: [ShadowgramAutoReactionEntry] = []
    entries.append(.modeHeader)
    entries.append(.mode(.everybody, values.autoReactionMode == .everybody))
    entries.append(.mode(.contacts, values.autoReactionMode == .contacts))
    entries.append(.mode(.nobody, values.autoReactionMode == .nobody))
    entries.append(.modeFooter)
    entries.append(.reactionHeader)
    entries.append(.reaction(values.autoReaction))
    entries.append(.exceptionsHeader)
    entries.append(.always(values.autoReactionAlwaysIds.count))
    entries.append(.never(values.autoReactionNeverIds.count))
    entries.append(.exceptionsFooter)
    return entries
}

/// Short label for the Extra Settings row: the mode, and the reaction while it is on.
public func shadowgramAutoReactionSummary(values: ShadowgramSettingsValues, strings: ShadowgramStrings) -> String {
    switch values.autoReactionMode {
    case .everybody:
        return "\(values.autoReaction) \(strings.autoReactionEverybody)"
    case .contacts:
        return "\(values.autoReaction) \(strings.autoReactionContacts)"
    case .nobody:
        return values.autoReactionAlwaysIds.isEmpty ? strings.autoReactionOff : "\(values.autoReaction) \(strings.autoReactionPeerCount(values.autoReactionAlwaysIds.count))"
    }
}

/// Extra Settings ▸ Auto Reaction.
public func shadowgramAutoReactionController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?
    var presentImpl: ((ViewController) -> Void)?

    let arguments = ShadowgramAutoReactionArguments(setMode: { mode in
        ShadowgramSettings.shared.update { $0.autoReactionMode = mode }
    }, openReaction: {
        pushImpl?(shadowgramAutoReactionPickerController(context: context))
    }, openExceptions: { isAlways in
        shadowgramOpenAutoReactionExceptions(context: context, isAlways: isAlways, push: { c in
            pushImpl?(c)
        }, present: { c in
            presentImpl?(c)
        })
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        ShadowgramSettings.shared.valuesSignal
    )
    |> map { presentationData, values -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.autoReaction), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: shadowgramAutoReactionEntries(values: values), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    return controller
}

// MARK: - Exceptions

/// Stores an exceptions list. A chat moved into one list leaves the other, as in privacy settings.
private func shadowgramSaveAutoReactionExceptions(isAlways: Bool, ids: Set<Int64>) {
    ShadowgramSettings.shared.update { values in
        if isAlways {
            values.autoReactionAlwaysIds = ids
            values.autoReactionNeverIds.subtract(ids)
        } else {
            values.autoReactionNeverIds = ids
            values.autoReactionAlwaysIds.subtract(ids)
        }
    }
}

/// The privacy-style exceptions list: straight to the chat picker while it is empty, the list
/// screen (add, remove, open) once it has chats.
private func shadowgramOpenAutoReactionExceptions(context: AccountContext, isAlways: Bool, push: @escaping (ViewController) -> Void, present: @escaping (ViewController) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
    let title = isAlways ? strings.autoReactionAlways : strings.autoReactionNever
    let values = ShadowgramSettings.shared.values
    let ids = isAlways ? values.autoReactionAlwaysIds : values.autoReactionNeverIds

    let pushList: ([EnginePeer.Id]) -> Void = { peerIds in
        let _ = (context.engine.data.get(EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)))
        |> deliverOnMainQueue).start(next: { peerMap in
            var initialPeers: [EnginePeer.Id: SelectivePrivacyPeer] = [:]
            for peerId in peerIds {
                if let maybePeer = peerMap[peerId], let peer = maybePeer {
                    initialPeers[peerId] = SelectivePrivacyPeer(peer: peer, participantCount: nil)
                }
            }
            let controller = selectivePrivacyPeersController(context: context, title: title, initialPeers: initialPeers, initialEnableForPremium: false, displayPremiumCategory: false, initialEnableForBots: false, displayBotsCategory: false, updated: { updatedPeers, _, _ in
                shadowgramSaveAutoReactionExceptions(isAlways: isAlways, ids: Set(updatedPeers.keys.map { $0.toInt64() }))
            })
            push(controller)
        })
    }

    if !ids.isEmpty {
        pushList(ids.sorted().map { EnginePeer.Id($0) })
        return
    }

    let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(
        title: strings.autoReactionSearchTitle,
        searchPlaceholder: strings.autoReactionSearchPlaceholder,
        selectedChats: Set(),
        additionalCategories: nil,
        chatListFilters: nil,
        onlyUsers: false,
        disableChannels: false,
        disableBots: false,
        disableContacts: false
    )), alwaysEnabled: true))
    let _ = (controller.result
    |> take(1)
    |> deliverOnMainQueue).start(next: { [weak controller] result in
        guard case let .result(peerIds, _) = result else {
            return
        }
        let selected = peerIds.compactMap { peerId -> EnginePeer.Id? in
            if case let .peer(value) = peerId {
                return value
            } else {
                return nil
            }
        }
        controller?.dismiss()
        if selected.isEmpty {
            return
        }
        shadowgramSaveAutoReactionExceptions(isAlways: isAlways, ids: Set(selected.map { $0.toInt64() }))
        pushList(selected)
    })
    present(controller)
}

// MARK: - Reaction picker

private final class ShadowgramAutoReactionPickerArguments {
    let select: (String) -> Void

    init(select: @escaping (String) -> Void) {
        self.select = select
    }
}

private struct ShadowgramAutoReactionPickerEntry: ItemListNodeEntry {
    let index: Int32
    let emoji: String
    let title: String
    let isSelected: Bool

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        return self.index
    }

    static func <(lhs: ShadowgramAutoReactionPickerEntry, rhs: ShadowgramAutoReactionPickerEntry) -> Bool {
        return lhs.index < rhs.index
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ShadowgramAutoReactionPickerArguments
        let emoji = self.emoji
        return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: "\(emoji)  \(self.title)", style: .left, checked: self.isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
            arguments.select(emoji)
        })
    }
}

/// The standard (non-Premium) reactions, one tap to pick.
private func shadowgramAutoReactionPickerController(context: AccountContext) -> ViewController {
    let arguments = ShadowgramAutoReactionPickerArguments(select: { emoji in
        ShadowgramSettings.shared.update { $0.autoReaction = emoji }
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        ShadowgramSettings.shared.valuesSignal,
        context.engine.stickers.availableReactions()
    )
    |> map { presentationData, values, availableReactions -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        var entries: [ShadowgramAutoReactionPickerEntry] = []
        var seen = Set<String>()
        for reaction in availableReactions?.reactions ?? [] {
            guard reaction.isEnabled, !reaction.isPremium, case let .builtin(emoji) = reaction.value, !seen.contains(emoji) else {
                continue
            }
            seen.insert(emoji)
            entries.append(ShadowgramAutoReactionPickerEntry(index: Int32(entries.count), emoji: emoji, title: reaction.title, isSelected: emoji == values.autoReaction))
        }
        if entries.isEmpty {
            entries.append(ShadowgramAutoReactionPickerEntry(index: 0, emoji: values.autoReaction, title: "", isSelected: true))
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.autoReactionReaction), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
