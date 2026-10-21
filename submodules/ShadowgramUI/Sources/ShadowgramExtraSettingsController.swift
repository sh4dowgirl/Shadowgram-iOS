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

    init(update: @escaping ((inout ShadowgramSettingsValues) -> Void) -> Void) {
        self.update = update
    }
}

private enum ShadowgramExtraSettingsSection: Int32 {
    case messages
    case accounts
    case ghost
    case groups
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
    case groupsFooter

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
        }
    }

    static func <(lhs: ShadowgramExtraSettingsEntry, rhs: ShadowgramExtraSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
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
        case .groupsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.groupsFolderFooter), sectionId: self.section)
        }
    }
}

private func shadowgramExtraSettingsEntries(values: ShadowgramSettingsValues) -> [ShadowgramExtraSettingsEntry] {
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

    return entries
}

/// The "Extra Settings" screen, opened from Settings above Telegram Premium.
public func shadowgramExtraSettingsController(context: AccountContext) -> ViewController {
    let arguments = ShadowgramExtraSettingsArguments(update: { f in
        ShadowgramSettings.shared.update(f)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        ShadowgramSettings.shared.valuesSignal
    )
    |> map { presentationData, values -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.extraSettingsTitle), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: shadowgramExtraSettingsEntries(values: values), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
