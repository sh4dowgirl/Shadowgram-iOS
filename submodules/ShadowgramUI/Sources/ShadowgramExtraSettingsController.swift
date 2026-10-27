import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import ShadowgramSettings

private final class ShadowgramExtraSettingsArguments {
    let update: ((inout ShadowgramSettingsValues) -> Void) -> Void
    let openAutoReaction: () -> Void

    init(update: @escaping ((inout ShadowgramSettingsValues) -> Void) -> Void, openAutoReaction: @escaping () -> Void) {
        self.update = update
        self.openAutoReaction = openAutoReaction
    }
}

private enum ShadowgramExtraSettingsCategory: Int32, CaseIterable {
    case privacy
    case messages
    case restrictions
    case chatList
    case media
    case interface
    case localEdits
    case premium
}

/// One row of a category screen. Rows are listed in display order by `shadowgramExtraSettingsEntries`,
/// which also assigns their sections, so the enum only describes what a row shows.
private enum ShadowgramExtraSettingsRow: Equatable {
    case header(Int32, String)
    case footer(Int32, String)
    case toggle(Int32, String, Bool, WritableKeyPath<ShadowgramSettingsValues, Bool>)
    case checkbox(Int32, String, Bool, (inout ShadowgramSettingsValues) -> Void)
    case groupsMinMembers(Int32)
    case autoReaction(String)

    var stableId: Int32 {
        switch self {
        case let .header(id, _), let .footer(id, _), let .toggle(id, _, _, _), let .checkbox(id, _, _, _):
            return id
        case .groupsMinMembers:
            return 900
        case .autoReaction:
            return 901
        }
    }

    static func ==(lhs: ShadowgramExtraSettingsRow, rhs: ShadowgramExtraSettingsRow) -> Bool {
        switch lhs {
        case let .header(id, text):
            if case .header(id, text) = rhs { return true }
            return false
        case let .footer(id, text):
            if case .footer(id, text) = rhs { return true }
            return false
        case let .toggle(id, title, value, keyPath):
            if case let .toggle(rid, rtitle, rvalue, rkeyPath) = rhs {
                return id == rid && title == rtitle && value == rvalue && keyPath == rkeyPath
            }
            return false
        case let .checkbox(id, title, checked, _):
            if case let .checkbox(rid, rtitle, rchecked, _) = rhs {
                return id == rid && title == rtitle && checked == rchecked
            }
            return false
        case let .groupsMinMembers(value):
            if case .groupsMinMembers(value) = rhs { return true }
            return false
        case let .autoReaction(summary):
            if case .autoReaction(summary) = rhs { return true }
            return false
        }
    }
}

private struct ShadowgramExtraSettingsEntry: ItemListNodeEntry {
    let index: Int
    let sectionIndex: Int32
    let row: ShadowgramExtraSettingsRow

    var section: ItemListSectionId {
        return self.sectionIndex
    }

    var stableId: Int32 {
        return self.row.stableId
    }

    static func <(lhs: ShadowgramExtraSettingsEntry, rhs: ShadowgramExtraSettingsEntry) -> Bool {
        return lhs.index < rhs.index
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ShadowgramExtraSettingsArguments
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        switch self.row {
        case let .header(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .footer(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .toggle(_, title, value, keyPath):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0[keyPath: keyPath] = value }
            })
        case let .checkbox(_, title, checked, apply):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.update(apply)
            })
        case let .groupsMinMembers(value):
            return ShadowgramStepSliderItem(theme: presentationData.theme, systemStyle: .glass, values: shadowgramGroupsFolderMemberSteps, labels: shadowgramGroupsFolderMemberSteps.map { strings.memberCountLabel($0) }, value: value, sectionId: self.section, updated: { value in
                arguments.update { $0.groupsFolderMinMembers = value }
            })
        case let .autoReaction(summary):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: strings.autoReaction, label: summary, sectionId: self.section, style: .blocks, action: {
                arguments.openAutoReaction()
            })
        }
    }
}

/// Builds a category's rows: `blocks` are the visual groups, each one ItemList section.
private func shadowgramExtraSettingsEntries(values: ShadowgramSettingsValues, strings: ShadowgramStrings, category: ShadowgramExtraSettingsCategory) -> [ShadowgramExtraSettingsEntry] {
    var blocks: [[ShadowgramExtraSettingsRow]] = []

    switch category {
    case .privacy:
        blocks.append([
            .header(1, strings.ghostModeHeader),
            .toggle(2, strings.ghostMode, values.ghostModeEnabled, \.ghostModeEnabled),
            .footer(3, strings.ghostModeSwitchFooter)
        ])
        blocks.append([
            .toggle(10, strings.showExactLastSeen, values.showExactLastSeen, \.showExactLastSeen),
            .footer(11, strings.showExactLastSeenFooter)
        ])
        blocks.append([
            .header(20, strings.captureHeader),
            .toggle(21, strings.hidePhoneOnCapture, values.hidePhoneOnCapture, \.hidePhoneOnCapture),
            .toggle(22, strings.hideEmailOnCapture, values.hideEmailOnCapture, \.hideEmailOnCapture),
            .toggle(23, strings.hideIdOnCapture, values.hideIdOnCapture, \.hideIdOnCapture),
            .toggle(24, strings.hideUsernameOnCapture, values.hideUsernameOnCapture, \.hideUsernameOnCapture),
            .footer(25, strings.captureFooter)
        ])
    case .messages:
        blocks.append([
            .header(100, strings.messagesDeletedEditedHeader),
            .toggle(101, strings.saveDeletedMessages, values.saveDeletedMessages, \.saveDeletedMessages),
            .footer(102, strings.saveDeletedMessagesFooter)
        ])
        blocks.append([
            .toggle(110, strings.keepEditHistory, values.keepEditHistory, \.keepEditHistory),
            .footer(111, strings.keepEditHistoryFooter)
        ])
        blocks.append([
            .header(120, strings.messagesSendingHeader),
            .autoReaction(shadowgramAutoReactionSummary(values: values, strings: strings))
        ])
        blocks.append([
            .toggle(130, strings.messageBlockedUsers, values.messageBlockedUsers, \.messageBlockedUsers),
            .footer(131, strings.messageBlockedUsersFooter)
        ])
    case .restrictions:
        blocks.append([
            .header(200, strings.restrictionsProtectedHeader),
            .toggle(201, strings.bypassCopyProtection, values.bypassCopyProtection, \.bypassCopyProtection),
            .footer(202, strings.bypassCopyProtectionFooter)
        ])
        blocks.append([
            .header(210, strings.restrictionsSelfDestructingHeader),
            .toggle(211, strings.bypassViewOnce, values.bypassViewOnce, \.bypassViewOnce),
            .footer(212, strings.bypassViewOnceFooter)
        ])
        blocks.append([
            .toggle(220, strings.forwardSelfDestructingMedia, values.forwardSelfDestructingMedia, \.forwardSelfDestructingMedia),
            .footer(221, strings.forwardSelfDestructingMediaFooter)
        ])
    case .chatList:
        var groups: [ShadowgramExtraSettingsRow] = [
            .header(300, strings.groupsFolderHeader),
            .toggle(301, strings.groupsFolder, values.groupsFolderEnabled, \.groupsFolderEnabled)
        ]
        if values.groupsFolderEnabled {
            groups.append(.groupsMinMembers(values.groupsFolderMinMembers))
        }
        groups.append(.footer(302, strings.groupsFolderFooter))
        blocks.append(groups)
        if values.groupsFolderEnabled {
            blocks.append([
                .header(310, strings.groupsFolderPlacementHeader),
                .checkbox(311, strings.groupsFolderPlacementArchive, values.groupsFolderPlacement == .archive, { $0.groupsFolderPlacement = .archive }),
                .checkbox(312, strings.groupsFolderPlacementTab, values.groupsFolderPlacement == .tab, { $0.groupsFolderPlacement = .tab })
            ])
        }
        var sorting: [ShadowgramExtraSettingsRow] = [
            .header(320, strings.chatListSortHeader),
            .toggle(324, strings.chatListUnreadSort, values.chatListUnreadSortEnabled, \.chatListUnreadSortEnabled)
        ]
        if values.chatListUnreadSortEnabled {
            sorting.append(.checkbox(321, strings.chatListSortNewestFirst, !values.chatListOldestFirst, { $0.chatListOldestFirst = false }))
            sorting.append(.checkbox(322, strings.chatListSortOldestFirst, values.chatListOldestFirst, { $0.chatListOldestFirst = true }))
        }
        sorting.append(.footer(323, strings.chatListUnreadSortFooter))
        blocks.append(sorting)
        blocks.append([
            .toggle(330, strings.disableCameraSwipe, values.disableCameraSwipe, \.disableCameraSwipe),
            .footer(331, strings.disableCameraSwipeFooter)
        ])
    case .media:
        blocks.append([
            .header(400, strings.roundVideoCameraHeader),
            .checkbox(401, strings.roundVideoCameraFront, values.roundVideoCamera == .front, { $0.roundVideoCamera = .front }),
            .checkbox(402, strings.roundVideoCameraBack, values.roundVideoCamera == .back, { $0.roundVideoCamera = .back })
        ])
        blocks.append([
            .header(410, strings.mediaHeader),
            .toggle(411, strings.pictureInPictureOnBackground, values.pictureInPictureOnBackground, \.pictureInPictureOnBackground),
            .footer(412, strings.pictureInPictureOnBackgroundFooter)
        ])
    case .interface:
        blocks.append([
            .header(500, strings.peerIdsHeader),
            .toggle(501, strings.showPeerIds, values.showPeerIds, \.showPeerIds),
            .footer(502, strings.showPeerIdsFooter)
        ])
        blocks.append([
            .toggle(510, strings.openByPeerId, values.openByPeerId, \.openByPeerId),
            .footer(511, strings.openByPeerIdFooter)
        ])
    case .localEdits:
        blocks.append([
            .header(600, strings.localEditsStarsHeader),
            .toggle(601, strings.starsEditing, values.starsEditingEnabled, \.starsEditingEnabled),
            .footer(602, strings.starsEditingFooter)
        ])
        blocks.append([
            .header(610, strings.localEditsGiftsHeader),
            .toggle(611, strings.giftEditing, values.giftEditingEnabled, \.giftEditingEnabled),
            .footer(612, strings.giftEditingFooter)
        ])
    case .premium:
        blocks.append([
            .header(700, strings.accountsHeader),
            .toggle(701, strings.unlimitedAccounts, values.unlimitedAccounts, \.unlimitedAccounts),
            .footer(702, strings.unlimitedAccountsFooter)
        ])
        blocks.append([
            .header(710, strings.premiumUnlocksHeader),
            .toggle(711, strings.unlockStoryTools, values.unlockStoryTools, \.unlockStoryTools),
            .toggle(712, strings.unlockMediaSaving, values.unlockMediaSaving, \.unlockMediaSaving),
            .toggle(713, strings.unlockChatTranslation, values.unlockChatTranslation, \.unlockChatTranslation),
            .toggle(714, strings.hideAds, values.hideAds, \.hideAds),
            .toggle(715, strings.unlockExtraFolders, values.unlockExtraFolders, \.unlockExtraFolders),
            .footer(716, strings.premiumUnlocksFooter)
        ])
    }

    var entries: [ShadowgramExtraSettingsEntry] = []
    for (sectionIndex, block) in blocks.enumerated() {
        for row in block {
            entries.append(ShadowgramExtraSettingsEntry(index: entries.count, sectionIndex: Int32(sectionIndex), row: row))
        }
    }
    return entries
}

private func shadowgramExtraSettingsCategoryController(context: AccountContext, category: ShadowgramExtraSettingsCategory) -> ViewController {
    weak var weakController: ViewController?
    let arguments = ShadowgramExtraSettingsArguments(update: { f in
        ShadowgramSettings.shared.update(f)
    }, openAutoReaction: { [weak context] in
        guard let context, let controller = weakController else {
            return
        }
        controller.push(shadowgramAutoReactionController(context: context))
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        ShadowgramSettings.shared.valuesSignal
    )
    |> map { presentationData, values -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.extraSettingsCategoryTitle(category.rawValue)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: shadowgramExtraSettingsEntries(values: values, strings: strings, category: category), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    weakController = controller
    return controller
}

private final class ShadowgramExtraSettingsRootArguments {
    let open: (ShadowgramExtraSettingsCategory) -> Void

    init(open: @escaping (ShadowgramExtraSettingsCategory) -> Void) {
        self.open = open
    }
}

private enum ShadowgramExtraSettingsRootEntry: ItemListNodeEntry {
    case category(ShadowgramExtraSettingsCategory, String)
    case footer

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case let .category(category, _):
            return category.rawValue
        case .footer:
            return 100
        }
    }

    static func <(lhs: ShadowgramExtraSettingsRootEntry, rhs: ShadowgramExtraSettingsRootEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ShadowgramExtraSettingsRootArguments
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        switch self {
        case let .category(category, label):
            let icon: UIImage?
            switch category {
            case .privacy:
                icon = PresentationResourcesSettings.lockOrange
            case .messages:
                icon = PresentationResourcesSettings.savedMessages
            case .restrictions:
                icon = PresentationResourcesSettings.block
            case .chatList:
                icon = PresentationResourcesSettings.chatFolders
            case .media:
                icon = PresentationResourcesSettings.photos
            case .interface:
                icon = PresentationResourcesSettings.appearance
            case .localEdits:
                icon = PresentationResourcesSettings.premiumGift
            case .premium:
                icon = PresentationResourcesSettings.premium
            }
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: icon, title: strings.extraSettingsCategoryTitle(category.rawValue), label: label, sectionId: self.section, style: .blocks, action: {
                arguments.open(category)
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.extraSettingsFooter), sectionId: self.section)
        }
    }
}

/// The root row's label: how many of the category's switches are on.
private func shadowgramExtraSettingsCategoryLabel(_ category: ShadowgramExtraSettingsCategory, values: ShadowgramSettingsValues, strings: ShadowgramStrings) -> String {
    let enabled: [Bool]
    switch category {
    case .privacy:
        if values.ghostModeEnabled {
            return strings.ghostMode
        }
        enabled = [values.showExactLastSeen, values.hidePhoneOnCapture, values.hideEmailOnCapture, values.hideIdOnCapture, values.hideUsernameOnCapture]
    case .messages:
        enabled = [values.saveDeletedMessages, values.keepEditHistory, !values.autoReactions.isEmpty, values.messageBlockedUsers]
    case .restrictions:
        enabled = [values.bypassCopyProtection, values.bypassViewOnce, values.forwardSelfDestructingMedia]
    case .chatList:
        enabled = [values.groupsFolderEnabled, values.chatListUnreadSortEnabled, values.disableCameraSwipe]
    case .media:
        enabled = [values.roundVideoCamera == .back, values.pictureInPictureOnBackground]
    case .interface:
        enabled = [values.showPeerIds, values.openByPeerId]
    case .localEdits:
        enabled = [values.starsEditingEnabled, values.giftEditingEnabled]
    case .premium:
        enabled = [values.unlimitedAccounts, values.unlockStoryTools, values.unlockMediaSaving, values.unlockChatTranslation, values.hideAds, values.unlockExtraFolders]
    }
    let count = enabled.filter { $0 }.count
    return count == 0 ? "" : "\(count)"
}

/// The "Extra Settings" screen, opened from Settings above Telegram Premium.
public func shadowgramExtraSettingsController(context: AccountContext) -> ViewController {
    weak var weakController: ViewController?
    let arguments = ShadowgramExtraSettingsRootArguments(open: { [weak context] category in
        guard let context, let controller = weakController else {
            return
        }
        controller.push(shadowgramExtraSettingsCategoryController(context: context, category: category))
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        ShadowgramSettings.shared.valuesSignal
    )
    |> map { presentationData, values -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        var entries: [ShadowgramExtraSettingsRootEntry] = ShadowgramExtraSettingsCategory.allCases.map { category in
            return .category(category, shadowgramExtraSettingsCategoryLabel(category, values: values, strings: strings))
        }
        entries.append(.footer)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.extraSettingsTitle), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    weakController = controller
    return controller
}
