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
    let openByPeerIdPrompt: () -> Void
    let openAutoReaction: () -> Void

    init(update: @escaping ((inout ShadowgramSettingsValues) -> Void) -> Void, openByPeerIdPrompt: @escaping () -> Void, openAutoReaction: @escaping () -> Void) {
        self.update = update
        self.openByPeerIdPrompt = openByPeerIdPrompt
        self.openAutoReaction = openAutoReaction
    }
}

private enum ShadowgramExtraSettingsSection: Int32 {
    case messages
    case accounts
    case ghost
    case groups
    case interface
    case messagesExtra
    case capture
    case groupsPlacement
    case autoReaction
    case privacy
    case chatListSort
}

private enum ShadowgramExtraSettingsCategory: Int32, CaseIterable {
    case privacy
    case messages
    case chatList
    case interface
    case accounts
}

private enum ShadowgramExtraSettingsEntry: ItemListNodeEntry {
    case messagesHeader
    case saveDeletedMessages(Bool)
    case messagesFooter

    case accountsHeader
    case unlimitedAccounts(Bool)
    case accountsFooter

    case ghostHeader
    case ghostMode(Bool)
    case ghostFooter

    case groupsHeader
    case groupsFolder(Bool)
    case groupsMinMembers(Int32)
    case groupsPlacementHeader
    case groupsPlacement(ShadowgramGroupsFolderPlacement, Bool)
    case groupsFooter

    case interfaceHeader
    case showPeerIds(Bool)
    case showPeerIdsFooter
    case openByPeerId(Bool)
    case openByPeerIdAction
    case openByPeerIdFooter
    case disableCameraSwipe(Bool)
    case disableCameraSwipeFooter

    case messagesExtraHeader
    case keepEditHistory(Bool)
    case keepEditHistoryFooter
    case autoReaction(String)

    case captureHeader
    case hidePhoneOnCapture(Bool)
    case hideEmailOnCapture(Bool)
    case hideIdOnCapture(Bool)
    case hideUsernameOnCapture(Bool)
    case captureFooter

    case privacyHeader
    case showExactLastSeen(Bool)
    case showExactLastSeenFooter
    case bypassCopyProtection(Bool)
    case bypassCopyProtectionFooter
    case bypassViewOnce(Bool)
    case bypassViewOnceFooter

    case chatListSortHeader
    case chatListSort(oldestFirst: Bool, checked: Bool)

    var category: ShadowgramExtraSettingsCategory {
        switch self {
        case .ghostHeader, .ghostMode, .ghostFooter, .captureHeader, .hidePhoneOnCapture, .hideEmailOnCapture, .hideIdOnCapture, .hideUsernameOnCapture, .captureFooter, .privacyHeader, .showExactLastSeen, .showExactLastSeenFooter, .bypassCopyProtection, .bypassCopyProtectionFooter, .bypassViewOnce, .bypassViewOnceFooter:
            return .privacy
        case .messagesHeader, .saveDeletedMessages, .messagesFooter, .messagesExtraHeader, .keepEditHistory, .keepEditHistoryFooter, .autoReaction:
            return .messages
        case .groupsHeader, .groupsFolder, .groupsMinMembers, .groupsPlacementHeader, .groupsPlacement, .groupsFooter, .disableCameraSwipe, .disableCameraSwipeFooter, .chatListSortHeader, .chatListSort:
            return .chatList
        case .interfaceHeader, .showPeerIds, .showPeerIdsFooter, .openByPeerId, .openByPeerIdAction, .openByPeerIdFooter:
            return .interface
        case .accountsHeader, .unlimitedAccounts, .accountsFooter:
            return .accounts
        }
    }

    var isCategoryTitleHeader: Bool {
        switch self {
        case .messagesHeader, .messagesExtraHeader, .interfaceHeader, .accountsHeader:
            return true
        default:
            return false
        }
    }

    var section: ItemListSectionId {
        switch self {
        case .messagesHeader, .saveDeletedMessages, .messagesFooter:
            return ShadowgramExtraSettingsSection.messages.rawValue
        case .accountsHeader, .unlimitedAccounts, .accountsFooter:
            return ShadowgramExtraSettingsSection.accounts.rawValue
        case .ghostHeader, .ghostMode, .ghostFooter:
            return ShadowgramExtraSettingsSection.ghost.rawValue
        case .groupsHeader, .groupsFolder, .groupsMinMembers, .groupsFooter:
            return ShadowgramExtraSettingsSection.groups.rawValue
        case .groupsPlacementHeader, .groupsPlacement:
            return ShadowgramExtraSettingsSection.groupsPlacement.rawValue
        case .autoReaction:
            return ShadowgramExtraSettingsSection.autoReaction.rawValue
        case .interfaceHeader, .showPeerIds, .showPeerIdsFooter, .openByPeerId, .openByPeerIdAction, .openByPeerIdFooter, .disableCameraSwipe, .disableCameraSwipeFooter:
            return ShadowgramExtraSettingsSection.interface.rawValue
        case .messagesExtraHeader, .keepEditHistory, .keepEditHistoryFooter:
            return ShadowgramExtraSettingsSection.messagesExtra.rawValue
        case .captureHeader, .hidePhoneOnCapture, .hideEmailOnCapture, .hideIdOnCapture, .hideUsernameOnCapture, .captureFooter:
            return ShadowgramExtraSettingsSection.capture.rawValue
        case .privacyHeader, .showExactLastSeen, .showExactLastSeenFooter, .bypassCopyProtection, .bypassCopyProtectionFooter, .bypassViewOnce, .bypassViewOnceFooter:
            return ShadowgramExtraSettingsSection.privacy.rawValue
        case .chatListSortHeader, .chatListSort:
            return ShadowgramExtraSettingsSection.chatListSort.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .messagesHeader:
            return 0
        case .saveDeletedMessages:
            return 1
        case .messagesFooter:
            return 2
        case .accountsHeader:
            return 3
        case .unlimitedAccounts:
            return 4
        case .accountsFooter:
            return 5
        case .ghostHeader:
            return 6
        case .ghostMode:
            return 7
        case .ghostFooter:
            return 8
        case .groupsHeader:
            return 9
        case .groupsFolder:
            return 10
        case .groupsMinMembers:
            return 11
        case .groupsFooter:
            return 12
        case .interfaceHeader:
            return 13
        case .showPeerIds:
            return 14
        case .showPeerIdsFooter:
            return 15
        case .openByPeerId:
            return 16
        case .openByPeerIdAction:
            return 17
        case .openByPeerIdFooter:
            return 18
        case .disableCameraSwipe:
            return 19
        case .disableCameraSwipeFooter:
            return 20
        case .messagesExtraHeader:
            return 21
        case .keepEditHistory:
            return 22
        case .keepEditHistoryFooter:
            return 23
        case .privacyHeader:
            return 30
        case .showExactLastSeen:
            return 31
        case .showExactLastSeenFooter:
            return 32
        case .bypassCopyProtection:
            return 33
        case .bypassCopyProtectionFooter:
            return 34
        case .bypassViewOnce:
            return 35
        case .bypassViewOnceFooter:
            return 36
        case .captureHeader:
            return 24
        case .hidePhoneOnCapture:
            return 25
        case .hideEmailOnCapture:
            return 26
        case .hideIdOnCapture:
            return 27
        case .hideUsernameOnCapture:
            return 28
        case .captureFooter:
            return 29
        case .groupsPlacementHeader:
            return 1100
        case let .groupsPlacement(placement, _):
            return 1101 + placement.rawValue
        case .autoReaction:
            return 2300
        case .chatListSortHeader:
            return 40
        case let .chatListSort(oldestFirst, _):
            return oldestFirst ? 42 : 41
        }
    }

    /// Display order; stable ids added later sort into their sections by this.
    private var sortKey: Int32 {
        switch self {
        case .groupsPlacementHeader:
            return 12 * 100 + 50
        case let .groupsPlacement(placement, _):
            return 12 * 100 + 51 + placement.rawValue
        case .autoReaction:
            return 23 * 100 + 50
        case .chatListSortHeader:
            return 12 * 100 + 60
        case let .chatListSort(oldestFirst, _):
            return 12 * 100 + (oldestFirst ? 62 : 61)
        default:
            return self.stableId * 100
        }
    }

    static func <(lhs: ShadowgramExtraSettingsEntry, rhs: ShadowgramExtraSettingsEntry) -> Bool {
        return lhs.sortKey < rhs.sortKey
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ShadowgramExtraSettingsArguments
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        switch self {
        case .messagesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.messagesHeader, sectionId: self.section)
        case let .saveDeletedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.saveDeletedMessages, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.saveDeletedMessages = value }
            })
        case .messagesFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.saveDeletedMessagesFooter), sectionId: self.section)
        case .accountsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.accountsHeader, sectionId: self.section)
        case let .unlimitedAccounts(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.unlimitedAccounts, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.unlimitedAccounts = value }
            })
        case .accountsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.unlimitedAccountsFooter), sectionId: self.section)
        case .ghostHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.ghostModeHeader, sectionId: self.section)
        case let .ghostMode(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.ghostMode, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.ghostModeEnabled = value }
            })
        case .ghostFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.ghostModeSwitchFooter), sectionId: self.section)
        case .groupsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.groupsFolderHeader, sectionId: self.section)
        case let .groupsFolder(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.groupsFolder, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.groupsFolderEnabled = value }
            })
        case let .groupsMinMembers(value):
            return ShadowgramStepSliderItem(theme: presentationData.theme, systemStyle: .glass, values: shadowgramGroupsFolderMemberSteps, labels: shadowgramGroupsFolderMemberSteps.map { strings.memberCountLabel($0) }, value: value, sectionId: self.section, updated: { value in
                arguments.update { $0.groupsFolderMinMembers = value }
            })
        case .groupsPlacementHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.groupsFolderPlacementHeader, sectionId: self.section)
        case let .groupsPlacement(placement, checked):
            let title: String
            switch placement {
            case .archive:
                title = strings.groupsFolderPlacementArchive
            case .tab:
                title = strings.groupsFolderPlacementTab
            }
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.update { $0.groupsFolderPlacement = placement }
            })
        case .groupsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.groupsFolderFooter), sectionId: self.section)
        case .interfaceHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.interfaceHeader, sectionId: self.section)
        case let .showPeerIds(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.showPeerIds, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.showPeerIds = value }
            })
        case .showPeerIdsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.showPeerIdsFooter), sectionId: self.section)
        case let .openByPeerId(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.openByPeerId, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.openByPeerId = value }
            })
        case .openByPeerIdAction:
            return ItemListDisclosureItem(presentationData: presentationData, title: strings.openByPeerIdAction, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openByPeerIdPrompt()
            })
        case .openByPeerIdFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.openByPeerIdFooter), sectionId: self.section)
        case let .disableCameraSwipe(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.disableCameraSwipe, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.disableCameraSwipe = value }
            })
        case .disableCameraSwipeFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.disableCameraSwipeFooter), sectionId: self.section)
        case .messagesExtraHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.messagesExtraHeader, sectionId: self.section)
        case let .keepEditHistory(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.keepEditHistory, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.keepEditHistory = value }
            })
        case .keepEditHistoryFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.keepEditHistoryFooter), sectionId: self.section)
        case let .autoReaction(summary):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: strings.autoReaction, label: summary, sectionId: self.section, style: .blocks, action: {
                arguments.openAutoReaction()
            })
        case .captureHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.captureHeader, sectionId: self.section)
        case let .hidePhoneOnCapture(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.hidePhoneOnCapture, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.hidePhoneOnCapture = value }
            })
        case let .hideEmailOnCapture(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.hideEmailOnCapture, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.hideEmailOnCapture = value }
            })
        case let .hideIdOnCapture(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.hideIdOnCapture, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.hideIdOnCapture = value }
            })
        case let .hideUsernameOnCapture(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.hideUsernameOnCapture, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.hideUsernameOnCapture = value }
            })
        case .captureFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.captureFooter), sectionId: self.section)
        case .privacyHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.privacyHeader, sectionId: self.section)
        case let .showExactLastSeen(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.showExactLastSeen, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.showExactLastSeen = value }
            })
        case .showExactLastSeenFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.showExactLastSeenFooter), sectionId: self.section)
        case let .bypassCopyProtection(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.bypassCopyProtection, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.bypassCopyProtection = value }
            })
        case .bypassCopyProtectionFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.bypassCopyProtectionFooter), sectionId: self.section)
        case let .bypassViewOnce(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.bypassViewOnce, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.bypassViewOnce = value }
            })
        case .bypassViewOnceFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.bypassViewOnceFooter), sectionId: self.section)
        case .chatListSortHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.chatListSortHeader, sectionId: self.section)
        case let .chatListSort(oldestFirst, checked):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: oldestFirst ? strings.chatListSortOldestFirst : strings.chatListSortNewestFirst, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.update { $0.chatListOldestFirst = oldestFirst }
            })
        }
    }
}

private func shadowgramExtraSettingsEntries(values: ShadowgramSettingsValues, strings: ShadowgramStrings, category: ShadowgramExtraSettingsCategory) -> [ShadowgramExtraSettingsEntry] {
    return shadowgramAllExtraSettingsEntries(values: values, strings: strings).filter { entry in
        return entry.category == category && !entry.isCategoryTitleHeader
    }
}

private func shadowgramAllExtraSettingsEntries(values: ShadowgramSettingsValues, strings: ShadowgramStrings) -> [ShadowgramExtraSettingsEntry] {
    var entries: [ShadowgramExtraSettingsEntry] = []

    entries.append(.messagesHeader)
    entries.append(.saveDeletedMessages(values.saveDeletedMessages))
    entries.append(.messagesFooter)

    entries.append(.accountsHeader)
    entries.append(.unlimitedAccounts(values.unlimitedAccounts))
    entries.append(.accountsFooter)

    entries.append(.ghostHeader)
    entries.append(.ghostMode(values.ghostModeEnabled))
    entries.append(.ghostFooter)

    entries.append(.groupsHeader)
    entries.append(.groupsFolder(values.groupsFolderEnabled))
    if values.groupsFolderEnabled {
        entries.append(.groupsMinMembers(values.groupsFolderMinMembers))
    }
    entries.append(.groupsFooter)
    if values.groupsFolderEnabled {
        entries.append(.groupsPlacementHeader)
        entries.append(.groupsPlacement(.archive, values.groupsFolderPlacement == .archive))
        entries.append(.groupsPlacement(.tab, values.groupsFolderPlacement == .tab))
    }

    entries.append(.interfaceHeader)
    entries.append(.showPeerIds(values.showPeerIds))
    entries.append(.showPeerIdsFooter)
    entries.append(.openByPeerId(values.openByPeerId))
    if values.openByPeerId {
        entries.append(.openByPeerIdAction)
    }
    entries.append(.openByPeerIdFooter)
    entries.append(.chatListSortHeader)
    entries.append(.chatListSort(oldestFirst: false, checked: !values.chatListOldestFirst))
    entries.append(.chatListSort(oldestFirst: true, checked: values.chatListOldestFirst))
    entries.append(.disableCameraSwipe(values.disableCameraSwipe))
    entries.append(.disableCameraSwipeFooter)

    entries.append(.messagesExtraHeader)
    entries.append(.keepEditHistory(values.keepEditHistory))
    entries.append(.keepEditHistoryFooter)
    entries.append(.autoReaction(shadowgramAutoReactionSummary(values: values, strings: strings)))

    entries.append(.captureHeader)
    entries.append(.hidePhoneOnCapture(values.hidePhoneOnCapture))
    entries.append(.hideEmailOnCapture(values.hideEmailOnCapture))
    entries.append(.hideIdOnCapture(values.hideIdOnCapture))
    entries.append(.hideUsernameOnCapture(values.hideUsernameOnCapture))
    entries.append(.captureFooter)

    entries.append(.privacyHeader)
    entries.append(.showExactLastSeen(values.showExactLastSeen))
    entries.append(.showExactLastSeenFooter)
    entries.append(.bypassCopyProtection(values.bypassCopyProtection))
    entries.append(.bypassCopyProtectionFooter)
    entries.append(.bypassViewOnce(values.bypassViewOnce))
    entries.append(.bypassViewOnceFooter)

    return entries
}

private func shadowgramExtraSettingsCategoryController(context: AccountContext, category: ShadowgramExtraSettingsCategory) -> ViewController {
    weak var weakController: ViewController?
    let arguments = ShadowgramExtraSettingsArguments(update: { f in
        ShadowgramSettings.shared.update(f)
    }, openByPeerIdPrompt: { [weak context] in
        guard let context, let controller = weakController else {
            return
        }
        shadowgramPresentOpenByPeerIdPrompt(context: context, from: controller)
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
        switch self {
        case .category:
            return 0
        case .footer:
            return 0
        }
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
            case .chatList:
                icon = PresentationResourcesSettings.chatFolders
            case .interface:
                icon = PresentationResourcesSettings.appearance
            case .accounts:
                icon = PresentationResourcesSettings.myProfile
            }
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: icon, title: strings.extraSettingsCategoryTitle(category.rawValue), label: label, sectionId: self.section, style: .blocks, action: {
                arguments.open(category)
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.extraSettingsFooter), sectionId: self.section)
        }
    }
}

private func shadowgramExtraSettingsCategoryLabel(_ category: ShadowgramExtraSettingsCategory, values: ShadowgramSettingsValues, strings: ShadowgramStrings) -> String {
    switch category {
    case .privacy:
        return values.ghostModeEnabled ? strings.ghostMode : ""
    case .messages:
        var count = 0
        if values.saveDeletedMessages {
            count += 1
        }
        if values.keepEditHistory {
            count += 1
        }
        if values.autoReactionMode != .nobody || !values.autoReactionAlwaysIds.isEmpty {
            count += 1
        }
        return count == 0 ? "" : "\(count)"
    case .chatList:
        return values.chatListOldestFirst ? strings.chatListSortOldestFirst : ""
    case .interface:
        return ""
    case .accounts:
        return values.unlimitedAccounts ? strings.unlimitedAccountsShort : ""
    }
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

// MARK: - Open chat by peer ID

private func shadowgramPresentOpenByPeerIdPrompt(context: AccountContext, from presentingController: ViewController) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
    let alert = UIAlertController(title: strings.openByPeerIdAction, message: strings.openByPeerIdPrompt, preferredStyle: .alert)
    alert.addTextField { textField in
        textField.keyboardType = .numberPad
        textField.placeholder = "1234567890"
    }
    alert.addAction(UIAlertAction(title: strings.openByPeerIdCancel, style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: strings.openByPeerIdOk, style: .default, handler: { [weak presentingController] _ in
        guard let text = alert.textFields?.first?.text, let value = Int64(text.trimmingCharacters(in: .whitespaces)), value > 0 else {
            return
        }
        shadowgramResolveAndOpenPeerId(context: context, idValue: value, from: presentingController)
    }))
    if let hostingController = presentingController.view.window?.rootViewController {
        hostingController.present(alert, animated: true, completion: nil)
    }
}

private func shadowgramResolveAndOpenPeerId(context: AccountContext, idValue: Int64, from presentingController: ViewController?) {
    // Try user, channel, and group namespaces in turn; the first one with a known peer wins.
    let candidates: [EnginePeer.Id] = [
        EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(idValue)),
        EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(idValue)),
        EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(idValue))
    ]
    let lookups = candidates.map { id in
        context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: id))
    }
    let _ = (combineLatest(lookups)
    |> take(1)
    |> deliverOnMainQueue).start(next: { [weak presentingController] peers in
        let found = peers.compactMap({ $0 }).first
        if let peer = found, let presentingController, let navigationController = presentingController.navigationController as? NavigationController {
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), keepStack: .default))
        } else {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
            let errorAlert = UIAlertController(title: nil, message: strings.openByPeerIdNotFound, preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: presentationData.strings.Common_OK, style: .default, handler: nil))
            presentingController?.view.window?.rootViewController?.present(errorAlert, animated: true, completion: nil)
        }
    })
}
