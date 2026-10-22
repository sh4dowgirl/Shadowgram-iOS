import Foundation
import SwiftSignalKit

/// Who gets an automatic reaction on their messages (Extra Settings ▸ Auto Reaction).
public enum ShadowgramAutoReactionMode: Int32 {
    /// Off, apart from the "always" exceptions.
    case nobody = 0
    case contacts = 1
    case everybody = 2
}

/// Where the groups folder shows up.
public enum ShadowgramGroupsFolderPlacement: Int32 {
    /// An entry under the archive in "All", with the archive's hide-on-scroll behaviour.
    case archive = 0
    /// Its own tab next to the chat folders.
    case tab = 1
}

/// Client-side switches of Shadowgram's "Extra Settings".
///
/// Stored in the app group's user defaults, so the main app and its extensions read the same
/// values. Foundation-only on purpose: TelegramCore reads it and must stay free of UIKit.
public struct ShadowgramSettingsValues: Equatable {
    /// Keep messages that someone else deleted, marked with a trash icon.
    public var saveDeletedMessages: Bool
    /// Allow adding any number of accounts.
    public var unlimitedAccounts: Bool
    /// Ghost mode as a whole: shows the ghost button in the profile and applies the three switches below.
    public var ghostModeEnabled: Bool
    /// Ghost mode: send read receipts. When off, chats are marked read only on this device.
    public var sendReadReceipts: Bool
    /// Ghost mode: send "typing…" and other input activities.
    public var sendTyping: Bool
    /// Ghost mode: report the account as online.
    public var sendOnlineStatus: Bool
    /// Ghost mode: tell the server which stories were viewed. When off, stories are marked seen on
    /// this device only and the author does not see the view.
    public var sendStoryViews: Bool
    /// Move large groups out of "All" into a folder under the archive.
    public var groupsFolderEnabled: Bool
    /// Minimum member count for a group to go into the folder.
    public var groupsFolderMinMembers: Int32
    /// Show numeric user, group and channel IDs in profiles.
    public var showPeerIds: Bool
    /// Let the chat list search open a user/chat by numeric ID.
    public var openByPeerId: Bool
    /// Keep the previous text of a message when the sender edits it, so the whole edit history can be
    /// opened from the long-press menu.
    public var keepEditHistory: Bool
    /// Replace the left-swipe camera panel in the main chat list with a plain left swipe.
    public var disableCameraSwipe: Bool
    /// Hide the phone number from screenshots, screen recordings and streams (it stays visible on
    /// the device itself).
    public var hidePhoneOnCapture: Bool
    /// Same for the e-mail address.
    public var hideEmailOnCapture: Bool
    /// Same for numeric user, group and channel IDs.
    public var hideIdOnCapture: Bool
    /// Same for @usernames.
    public var hideUsernameOnCapture: Bool
    /// Chats marked Private from the chat list: their content is hidden from screenshots,
    /// recordings and streams. Raw peer ids (`PeerId.toInt64()`).
    public var privateChatIds: Set<Int64>
    /// Where the groups folder shows up.
    public var groupsFolderPlacement: ShadowgramGroupsFolderPlacement
    /// Whose new messages get the automatic reaction.
    public var autoReactionMode: ShadowgramAutoReactionMode
    /// The reaction, a standard reaction emoji.
    public var autoReaction: String
    /// Users and groups that always get the reaction (raw peer ids).
    public var autoReactionAlwaysIds: Set<Int64>
    /// Users and groups that never get it (raw peer ids).
    public var autoReactionNeverIds: Set<Int64>
    public var chatListOldestFirst: Bool
    /// Show exact last-seen timestamps even when users hide them.
    public var showExactLastSeen: Bool
    /// Allow forwarding, copying and screenshots in chats with copy protection / secret chats.
    public var bypassCopyProtection: Bool
    /// View once-view media unlimited times without notifying the sender.
    public var bypassViewOnce: Bool

    public static let defaultValues = ShadowgramSettingsValues(
        saveDeletedMessages: false,
        unlimitedAccounts: false,
        ghostModeEnabled: false,
        sendReadReceipts: true,
        sendTyping: true,
        sendOnlineStatus: true,
        sendStoryViews: true,
        groupsFolderEnabled: false,
        groupsFolderMinMembers: 100,
        showPeerIds: false,
        openByPeerId: false,
        keepEditHistory: false,
        disableCameraSwipe: false,
        hidePhoneOnCapture: false,
        hideEmailOnCapture: false,
        hideIdOnCapture: false,
        hideUsernameOnCapture: false,
        privateChatIds: Set(),
        groupsFolderPlacement: .archive,
        autoReactionMode: .nobody,
        autoReaction: "👍",
        autoReactionAlwaysIds: Set(),
        autoReactionNeverIds: Set(),
        chatListOldestFirst: false,
        showExactLastSeen: false,
        bypassCopyProtection: false,
        bypassViewOnce: false
    )

    public init(saveDeletedMessages: Bool, unlimitedAccounts: Bool, ghostModeEnabled: Bool, sendReadReceipts: Bool, sendTyping: Bool, sendOnlineStatus: Bool, sendStoryViews: Bool, groupsFolderEnabled: Bool, groupsFolderMinMembers: Int32, showPeerIds: Bool, openByPeerId: Bool, keepEditHistory: Bool, disableCameraSwipe: Bool, hidePhoneOnCapture: Bool, hideEmailOnCapture: Bool, hideIdOnCapture: Bool, hideUsernameOnCapture: Bool, privateChatIds: Set<Int64>, groupsFolderPlacement: ShadowgramGroupsFolderPlacement, autoReactionMode: ShadowgramAutoReactionMode, autoReaction: String, autoReactionAlwaysIds: Set<Int64>, autoReactionNeverIds: Set<Int64>, chatListOldestFirst: Bool, showExactLastSeen: Bool, bypassCopyProtection: Bool, bypassViewOnce: Bool) {
        self.saveDeletedMessages = saveDeletedMessages
        self.unlimitedAccounts = unlimitedAccounts
        self.ghostModeEnabled = ghostModeEnabled
        self.sendReadReceipts = sendReadReceipts
        self.sendTyping = sendTyping
        self.sendOnlineStatus = sendOnlineStatus
        self.sendStoryViews = sendStoryViews
        self.groupsFolderEnabled = groupsFolderEnabled
        self.groupsFolderMinMembers = groupsFolderMinMembers
        self.showPeerIds = showPeerIds
        self.openByPeerId = openByPeerId
        self.keepEditHistory = keepEditHistory
        self.disableCameraSwipe = disableCameraSwipe
        self.hidePhoneOnCapture = hidePhoneOnCapture
        self.hideEmailOnCapture = hideEmailOnCapture
        self.hideIdOnCapture = hideIdOnCapture
        self.hideUsernameOnCapture = hideUsernameOnCapture
        self.privateChatIds = privateChatIds
        self.groupsFolderPlacement = groupsFolderPlacement
        self.autoReactionMode = autoReactionMode
        self.autoReaction = autoReaction
        self.autoReactionAlwaysIds = autoReactionAlwaysIds
        self.autoReactionNeverIds = autoReactionNeverIds
        self.chatListOldestFirst = chatListOldestFirst
        self.showExactLastSeen = showExactLastSeen
        self.bypassCopyProtection = bypassCopyProtection
        self.bypassViewOnce = bypassViewOnce
    }

    /// What the client actually sends: everything unless ghost mode is on and hides it.
    public var effectiveSendReadReceipts: Bool {
        return !self.ghostModeEnabled || self.sendReadReceipts
    }

    public var effectiveSendTyping: Bool {
        return !self.ghostModeEnabled || self.sendTyping
    }

    public var effectiveSendOnlineStatus: Bool {
        return !self.ghostModeEnabled || self.sendOnlineStatus
    }

    public var effectiveSendStoryViews: Bool {
        return !self.ghostModeEnabled || self.sendStoryViews
    }
}

public extension ShadowgramSettingsValues {
    func hidesChatFromCapture(stockProtected: Bool, rawPeerId: Int64?) -> Bool {
        if let rawPeerId, self.privateChatIds.contains(rawPeerId) {
            return true
        }
        return stockProtected && !self.bypassCopyProtection
    }
}

/// Steps offered by the groups-folder slider.
public let shadowgramGroupsFolderMemberSteps: [Int32] = [0, 10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]

public final class ShadowgramSettings {
    public static let shared = ShadowgramSettings()

    private enum Key {
        static let saveDeletedMessages = "shadowgram.saveDeletedMessages"
        static let unlimitedAccounts = "shadowgram.unlimitedAccounts"
        static let ghostModeEnabled = "shadowgram.ghost.enabled"
        static let sendReadReceipts = "shadowgram.ghost.sendReadReceipts"
        static let sendTyping = "shadowgram.ghost.sendTyping"
        static let sendOnlineStatus = "shadowgram.ghost.sendOnlineStatus"
        static let sendStoryViews = "shadowgram.ghost.sendStoryViews"
        static let groupsFolderEnabled = "shadowgram.groupsFolder.enabled"
        static let groupsFolderMinMembers = "shadowgram.groupsFolder.minMembers"
        static let showPeerIds = "shadowgram.showPeerIds"
        static let openByPeerId = "shadowgram.openByPeerId"
        static let keepEditHistory = "shadowgram.keepEditHistory"
        static let disableCameraSwipe = "shadowgram.disableCameraSwipe"
        static let hidePhoneOnCapture = "shadowgram.capture.hidePhone"
        static let hideEmailOnCapture = "shadowgram.capture.hideEmail"
        static let hideIdOnCapture = "shadowgram.capture.hideId"
        static let hideUsernameOnCapture = "shadowgram.capture.hideUsername"
        static let privateChatIds = "shadowgram.privateChatIds"
        static let groupsFolderPlacement = "shadowgram.groupsFolder.placement"
        static let autoReactionMode = "shadowgram.autoReaction.mode"
        static let autoReaction = "shadowgram.autoReaction.reaction"
        static let autoReactionAlwaysIds = "shadowgram.autoReaction.always"
        static let autoReactionNeverIds = "shadowgram.autoReaction.never"
        static let chatListOldestFirst = "shadowgram.chatList.oldestFirst"
        static let showExactLastSeen = "shadowgram.showExactLastSeen"
        static let bypassCopyProtection = "shadowgram.bypassCopyProtection"
        static let bypassViewOnce = "shadowgram.bypassViewOnce"
    }

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var currentValues: ShadowgramSettingsValues
    private let valuesPromise: ValuePromise<ShadowgramSettingsValues>

    private init() {
        let defaults = ShadowgramSettings.appGroupSuiteName().flatMap({ UserDefaults(suiteName: $0) }) ?? UserDefaults.standard
        self.defaults = defaults

        let defaultValues = ShadowgramSettingsValues.defaultValues
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            return (defaults.object(forKey: key) as? NSNumber)?.boolValue ?? fallback
        }
        let minMembers = (defaults.object(forKey: Key.groupsFolderMinMembers) as? NSNumber)?.int32Value ?? defaultValues.groupsFolderMinMembers
        func idSet(_ key: String) -> Set<Int64> {
            return Set(((defaults.array(forKey: key) as? [NSNumber]) ?? []).map { $0.int64Value })
        }

        let values = ShadowgramSettingsValues(
            saveDeletedMessages: bool(Key.saveDeletedMessages, defaultValues.saveDeletedMessages),
            unlimitedAccounts: bool(Key.unlimitedAccounts, defaultValues.unlimitedAccounts),
            ghostModeEnabled: bool(Key.ghostModeEnabled, defaultValues.ghostModeEnabled),
            sendReadReceipts: bool(Key.sendReadReceipts, defaultValues.sendReadReceipts),
            sendTyping: bool(Key.sendTyping, defaultValues.sendTyping),
            sendOnlineStatus: bool(Key.sendOnlineStatus, defaultValues.sendOnlineStatus),
            sendStoryViews: bool(Key.sendStoryViews, defaultValues.sendStoryViews),
            groupsFolderEnabled: bool(Key.groupsFolderEnabled, defaultValues.groupsFolderEnabled),
            groupsFolderMinMembers: max(0, minMembers),
            showPeerIds: bool(Key.showPeerIds, defaultValues.showPeerIds),
            openByPeerId: bool(Key.openByPeerId, defaultValues.openByPeerId),
            keepEditHistory: bool(Key.keepEditHistory, defaultValues.keepEditHistory),
            disableCameraSwipe: bool(Key.disableCameraSwipe, defaultValues.disableCameraSwipe),
            hidePhoneOnCapture: bool(Key.hidePhoneOnCapture, defaultValues.hidePhoneOnCapture),
            hideEmailOnCapture: bool(Key.hideEmailOnCapture, defaultValues.hideEmailOnCapture),
            hideIdOnCapture: bool(Key.hideIdOnCapture, defaultValues.hideIdOnCapture),
            hideUsernameOnCapture: bool(Key.hideUsernameOnCapture, defaultValues.hideUsernameOnCapture),
            privateChatIds: idSet(Key.privateChatIds),
            groupsFolderPlacement: (defaults.object(forKey: Key.groupsFolderPlacement) as? NSNumber).flatMap { ShadowgramGroupsFolderPlacement(rawValue: $0.int32Value) } ?? defaultValues.groupsFolderPlacement,
            autoReactionMode: (defaults.object(forKey: Key.autoReactionMode) as? NSNumber).flatMap { ShadowgramAutoReactionMode(rawValue: $0.int32Value) } ?? defaultValues.autoReactionMode,
            autoReaction: (defaults.string(forKey: Key.autoReaction)).flatMap { $0.isEmpty ? nil : $0 } ?? defaultValues.autoReaction,
            autoReactionAlwaysIds: idSet(Key.autoReactionAlwaysIds),
            autoReactionNeverIds: idSet(Key.autoReactionNeverIds),
            chatListOldestFirst: bool(Key.chatListOldestFirst, defaultValues.chatListOldestFirst),
            showExactLastSeen: bool(Key.showExactLastSeen, defaultValues.showExactLastSeen),
            bypassCopyProtection: bool(Key.bypassCopyProtection, defaultValues.bypassCopyProtection),
            bypassViewOnce: bool(Key.bypassViewOnce, defaultValues.bypassViewOnce)
        )
        self.currentValues = values
        self.valuesPromise = ValuePromise(values, ignoreRepeated: true)
    }

    /// The current values. Safe to read from any thread.
    public var values: ShadowgramSettingsValues {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.currentValues
    }

    /// Emits the current values, then every change.
    public var valuesSignal: Signal<ShadowgramSettingsValues, NoError> {
        return self.valuesPromise.get()
    }

    public func update(_ f: (inout ShadowgramSettingsValues) -> Void) {
        self.lock.lock()
        var values = self.currentValues
        f(&values)
        values.groupsFolderMinMembers = max(0, values.groupsFolderMinMembers)
        self.currentValues = values
        self.lock.unlock()

        self.defaults.set(values.saveDeletedMessages, forKey: Key.saveDeletedMessages)
        self.defaults.set(values.unlimitedAccounts, forKey: Key.unlimitedAccounts)
        self.defaults.set(values.ghostModeEnabled, forKey: Key.ghostModeEnabled)
        self.defaults.set(values.sendReadReceipts, forKey: Key.sendReadReceipts)
        self.defaults.set(values.sendTyping, forKey: Key.sendTyping)
        self.defaults.set(values.sendOnlineStatus, forKey: Key.sendOnlineStatus)
        self.defaults.set(values.sendStoryViews, forKey: Key.sendStoryViews)
        self.defaults.set(values.groupsFolderEnabled, forKey: Key.groupsFolderEnabled)
        self.defaults.set(NSNumber(value: values.groupsFolderMinMembers), forKey: Key.groupsFolderMinMembers)
        self.defaults.set(values.showPeerIds, forKey: Key.showPeerIds)
        self.defaults.set(values.openByPeerId, forKey: Key.openByPeerId)
        self.defaults.set(values.keepEditHistory, forKey: Key.keepEditHistory)
        self.defaults.set(values.disableCameraSwipe, forKey: Key.disableCameraSwipe)
        self.defaults.set(values.hidePhoneOnCapture, forKey: Key.hidePhoneOnCapture)
        self.defaults.set(values.hideEmailOnCapture, forKey: Key.hideEmailOnCapture)
        self.defaults.set(values.hideIdOnCapture, forKey: Key.hideIdOnCapture)
        self.defaults.set(values.hideUsernameOnCapture, forKey: Key.hideUsernameOnCapture)
        self.defaults.set(values.privateChatIds.sorted().map { NSNumber(value: $0) }, forKey: Key.privateChatIds)
        self.defaults.set(NSNumber(value: values.groupsFolderPlacement.rawValue), forKey: Key.groupsFolderPlacement)
        self.defaults.set(NSNumber(value: values.autoReactionMode.rawValue), forKey: Key.autoReactionMode)
        self.defaults.set(values.autoReaction, forKey: Key.autoReaction)
        self.defaults.set(values.autoReactionAlwaysIds.sorted().map { NSNumber(value: $0) }, forKey: Key.autoReactionAlwaysIds)
        self.defaults.set(values.autoReactionNeverIds.sorted().map { NSNumber(value: $0) }, forKey: Key.autoReactionNeverIds)
        self.defaults.set(values.chatListOldestFirst, forKey: Key.chatListOldestFirst)
        self.defaults.set(values.showExactLastSeen, forKey: Key.showExactLastSeen)
        self.defaults.set(values.bypassCopyProtection, forKey: Key.bypassCopyProtection)
        self.defaults.set(values.bypassViewOnce, forKey: Key.bypassViewOnce)

        self.valuesPromise.set(values)
    }

    /// `group.<main app bundle id>`, the same app group Telegram-iOS uses for its shared data.
    private static func appGroupSuiteName() -> String? {
        guard var bundleId = Bundle.main.bundleIdentifier else {
            return nil
        }
        if Bundle.main.bundlePath.hasSuffix(".appex"), let range = bundleId.range(of: ".", options: .backwards) {
            bundleId = String(bundleId[..<range.lowerBound])
        }
        return "group.\(bundleId)"
    }
}
