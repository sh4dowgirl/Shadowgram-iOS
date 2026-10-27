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
    let openStarsEditing: () -> Void

    init(update: @escaping ((inout ShadowgramSettingsValues) -> Void) -> Void, openAutoReaction: @escaping () -> Void, openStarsEditing: @escaping () -> Void) {
        self.update = update
        self.openAutoReaction = openAutoReaction
        self.openStarsEditing = openStarsEditing
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
    case media
    case roundVideoCamera
    case premiumUnlocks
}

private enum ShadowgramExtraSettingsCategory: Int32, CaseIterable {
    case privacy
    case messages
    case chatList
    case interface
    case accounts
    case premium
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

    case forwardSelfDestructingMedia(Bool)
    case forwardSelfDestructingMediaFooter
    case messageBlockedUsers(Bool)
    case messageBlockedUsersFooter
    case starsEditing(String)
    case starsEditingFooter

    case roundVideoCameraHeader
    case roundVideoCamera(ShadowgramRoundVideoCamera, Bool)
    case mediaHeader
    case pictureInPictureOnBackground(Bool)
    case pictureInPictureOnBackgroundFooter

    case premiumUnlocksHeader
    case unlockStoryTools(Bool)
    case unlockMediaSaving(Bool)
    case unlockChatTranslation(Bool)
    case hideAds(Bool)
    case unlockExtraFolders(Bool)
    case premiumUnlocksFooter

    var category: ShadowgramExtraSettingsCategory {
        switch self {
        case .ghostHeader, .ghostMode, .ghostFooter, .captureHeader, .hidePhoneOnCapture, .hideEmailOnCapture, .hideIdOnCapture, .hideUsernameOnCapture, .captureFooter, .privacyHeader, .showExactLastSeen, .showExactLastSeenFooter, .bypassCopyProtection, .bypassCopyProtectionFooter, .bypassViewOnce, .bypassViewOnceFooter, .forwardSelfDestructingMedia, .forwardSelfDestructingMediaFooter, .messageBlockedUsers, .messageBlockedUsersFooter, .starsEditing, .starsEditingFooter:
            return .privacy
        case .messagesHeader, .saveDeletedMessages, .messagesFooter, .messagesExtraHeader, .keepEditHistory, .keepEditHistoryFooter, .autoReaction, .roundVideoCameraHeader, .roundVideoCamera, .mediaHeader, .pictureInPictureOnBackground, .pictureInPictureOnBackgroundFooter:
            return .messages
        case .groupsHeader, .groupsFolder, .groupsMinMembers, .groupsPlacementHeader, .groupsPlacement, .groupsFooter, .disableCameraSwipe, .disableCameraSwipeFooter, .chatListSortHeader, .chatListSort:
            return .chatList
        case .interfaceHeader, .showPeerIds, .showPeerIdsFooter, .openByPeerId, .openByPeerIdFooter:
            return .interface
        case .accountsHeader, .unlimitedAccounts, .accountsFooter:
            return .accounts
        case .premiumUnlocksHeader, .unlockStoryTools, .unlockMediaSaving, .unlockChatTranslation, .hideAds, .unlockExtraFolders, .premiumUnlocksFooter:
            return .premium
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
        case .interfaceHeader, .showPeerIds, .showPeerIdsFooter, .openByPeerId, .openByPeerIdFooter, .disableCameraSwipe, .disableCameraSwipeFooter:
            return ShadowgramExtraSettingsSection.interface.rawValue
        case .messagesExtraHeader, .keepEditHistory, .keepEditHistoryFooter:
            return ShadowgramExtraSettingsSection.messagesExtra.rawValue
        case .captureHeader, .hidePhoneOnCapture, .hideEmailOnCapture, .hideIdOnCapture, .hideUsernameOnCapture, .captureFooter:
            return ShadowgramExtraSettingsSection.capture.rawValue
        case .privacyHeader, .showExactLastSeen, .showExactLastSeenFooter, .bypassCopyProtection, .bypassCopyProtectionFooter, .bypassViewOnce, .bypassViewOnceFooter, .forwardSelfDestructingMedia, .forwardSelfDestructingMediaFooter, .messageBlockedUsers, .messageBlockedUsersFooter, .starsEditing, .starsEditingFooter:
            return ShadowgramExtraSettingsSection.privacy.rawValue
        case .roundVideoCameraHeader, .roundVideoCamera:
            return ShadowgramExtraSettingsSection.roundVideoCamera.rawValue
        case .mediaHeader, .pictureInPictureOnBackground, .pictureInPictureOnBackgroundFooter:
            return ShadowgramExtraSettingsSection.media.rawValue
        case .premiumUnlocksHeader, .unlockStoryTools, .unlockMediaSaving, .unlockChatTranslation, .hideAds, .unlockExtraFolders, .premiumUnlocksFooter:
            return ShadowgramExtraSettingsSection.premiumUnlocks.rawValue
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
        case .forwardSelfDestructingMedia:
            return 37
        case .forwardSelfDestructingMediaFooter:
            return 38
        case .messageBlockedUsers:
            return 2400
        case .messageBlockedUsersFooter:
            return 2401
        case .starsEditing:
            return 2402
        case .starsEditingFooter:
            return 2403
        case .roundVideoCameraHeader:
            return 50
        case let .roundVideoCamera(camera, _):
            return 51 + camera.rawValue
        case .mediaHeader:
            return 53
        case .pictureInPictureOnBackground:
            return 54
        case .pictureInPictureOnBackgroundFooter:
            return 55
        case .premiumUnlocksHeader:
            return 60
        case .unlockStoryTools:
            return 61
        case .unlockMediaSaving:
            return 62
        case .unlockChatTranslation:
            return 63
        case .hideAds:
            return 64
        case .unlockExtraFolders:
            return 65
        case .premiumUnlocksFooter:
            return 66
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
        case let .forwardSelfDestructingMedia(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.forwardSelfDestructingMedia, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.forwardSelfDestructingMedia = value }
            })
        case .forwardSelfDestructingMediaFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.forwardSelfDestructingMediaFooter), sectionId: self.section)
        case let .messageBlockedUsers(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.messageBlockedUsers, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.messageBlockedUsers = value }
            })
        case .messageBlockedUsersFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.messageBlockedUsersFooter), sectionId: self.section)
        case let .starsEditing(summary):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Stars Editing", label: summary, sectionId: self.section, style: .blocks, action: {
                arguments.openStarsEditing()
            })
        case .starsEditingFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Locally change what the Stars balance shows, on this device only. Nothing is actually credited or debited - the real balance is unaffected."), sectionId: self.section)
        case .roundVideoCameraHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.roundVideoCameraHeader, sectionId: self.section)
        case let .roundVideoCamera(camera, checked):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: camera == .back ? strings.roundVideoCameraBack : strings.roundVideoCameraFront, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.update { $0.roundVideoCamera = camera }
            })
        case .mediaHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.mediaHeader, sectionId: self.section)
        case let .pictureInPictureOnBackground(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.pictureInPictureOnBackground, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.pictureInPictureOnBackground = value }
            })
        case .pictureInPictureOnBackgroundFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.pictureInPictureOnBackgroundFooter), sectionId: self.section)
        case .premiumUnlocksHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.premiumUnlocksHeader, sectionId: self.section)
        case let .unlockStoryTools(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.unlockStoryTools, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.unlockStoryTools = value }
            })
        case let .unlockMediaSaving(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.unlockMediaSaving, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.unlockMediaSaving = value }
            })
        case let .unlockChatTranslation(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.unlockChatTranslation, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.unlockChatTranslation = value }
            })
        case let .hideAds(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.hideAds, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.hideAds = value }
            })
        case let .unlockExtraFolders(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.unlockExtraFolders, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.unlockExtraFolders = value }
            })
        case .premiumUnlocksFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.premiumUnlocksFooter), sectionId: self.section)
        }
    }
}

private func shadowgramExtraSettingsEntries(values: ShadowgramSettingsValues, strings: ShadowgramStrings, category: ShadowgramExtraSettingsCategory, accountPeerId: Int64) -> [ShadowgramExtraSettingsEntry] {
    return shadowgramAllExtraSettingsEntries(values: values, strings: strings, accountPeerId: accountPeerId).filter { entry in
        return entry.category == category && !entry.isCategoryTitleHeader
    }
}

private func shadowgramAllExtraSettingsEntries(values: ShadowgramSettingsValues, strings: ShadowgramStrings, accountPeerId: Int64) -> [ShadowgramExtraSettingsEntry] {
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

    entries.append(.roundVideoCameraHeader)
    entries.append(.roundVideoCamera(.front, values.roundVideoCamera == .front))
    entries.append(.roundVideoCamera(.back, values.roundVideoCamera == .back))
    entries.append(.mediaHeader)
    entries.append(.pictureInPictureOnBackground(values.pictureInPictureOnBackground))
    entries.append(.pictureInPictureOnBackgroundFooter)

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
    if values.bypassCopyProtection {
    }
    entries.append(.bypassViewOnce(values.bypassViewOnce))
    entries.append(.bypassViewOnceFooter)
    entries.append(.forwardSelfDestructingMedia(values.forwardSelfDestructingMedia))
    entries.append(.forwardSelfDestructingMediaFooter)
    entries.append(.messageBlockedUsers(values.messageBlockedUsers))
    entries.append(.messageBlockedUsersFooter)
    entries.append(.starsEditing(values.starsOverrides[accountPeerId] != nil ? "Overridden" : ""))
    entries.append(.starsEditingFooter)

    entries.append(.premiumUnlocksHeader)
    entries.append(.unlockStoryTools(values.unlockStoryTools))
    entries.append(.unlockMediaSaving(values.unlockMediaSaving))
    entries.append(.unlockChatTranslation(values.unlockChatTranslation))
    entries.append(.hideAds(values.hideAds))
    entries.append(.unlockExtraFolders(values.unlockExtraFolders))
    entries.append(.premiumUnlocksFooter)

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
    }, openStarsEditing: { [weak context] in
        guard let context, let controller = weakController else {
            return
        }
        presentShadowgramStarsEditing(context: context, from: controller)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        ShadowgramSettings.shared.valuesSignal
    )
    |> map { presentationData, values -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.extraSettingsCategoryTitle(category.rawValue)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: shadowgramExtraSettingsEntries(values: values, strings: strings, category: category, accountPeerId: context.account.peerId.toInt64()), style: .blocks, animateChanges: false)
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
        if !values.autoReactions.isEmpty {
            count += 1
        }
        return count == 0 ? "" : "\(count)"
    case .chatList:
        return values.chatListOldestFirst ? strings.chatListSortOldestFirst : ""
    case .interface:
        return ""
    case .accounts:
        return values.unlimitedAccounts ? strings.unlimitedAccountsShort : ""
    case .premium:
        let count = [values.unlockStoryTools, values.unlockMediaSaving, values.unlockChatTranslation, values.hideAds, values.unlockExtraFolders].filter { $0 }.count
        return count == 0 ? "" : "\(count)"
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
