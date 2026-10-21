import Foundation

/// Texts of the Shadowgram screens: Russian for a Russian interface, English otherwise.
public struct ShadowgramStrings {
    public let isRussian: Bool

    /// `languageCode` is the app's interface language, e.g. `PresentationStrings.primaryComponent.languageCode`.
    public init(languageCode: String) {
        self.isRussian = languageCode.lowercased().hasPrefix("ru")
    }

    private func t(_ ru: String, _ en: String) -> String {
        return self.isRussian ? ru : en
    }

    public var extraSettingsTitle: String { return "Extra Settings" }

    public var messagesHeader: String { return t("СООБЩЕНИЯ", "MESSAGES") }
    public var saveDeletedMessages: String { return t("Сохранять удалённые сообщения", "Save Deleted Messages") }
    public var saveDeletedMessagesFooter: String { return t("Сообщения, которые удалил собеседник, остаются в чате со значком корзины. Медиа сохраняются, только если успели загрузиться. Секретные чаты не затрагиваются.", "Messages deleted by others stay in the chat, marked with a trash icon. Media is kept only if it was already downloaded. Secret chats are not affected.") }

    public var accountsHeader: String { return t("АККАУНТЫ", "ACCOUNTS") }
    public var unlimitedAccounts: String { return t("Без лимита аккаунтов", "Unlimited Accounts") }
    public var unlimitedAccountsFooter: String { return t("Можно добавить сколько угодно аккаунтов, с Telegram Premium и без.", "Add any number of accounts, with or without Telegram Premium.") }

    public var ghostModeHeader: String { return t("GHOST-РЕЖИМ", "GHOST MODE") }
    public var ghostMode: String { return t("Ghost-режим", "Ghost Mode") }
    public var ghostModeOn: String { return t("Вкл", "On") }
    public var ghostModeOff: String { return t("Выкл", "Off") }
    public var ghostModeSwitchFooter: String { return t("Добавляет призрака в профиль, слева сверху рядом с QR-кодом. Нажмите его, чтобы выбрать, что скрывать.", "Adds a ghost to your profile, top left next to the QR code. Tap it to choose what to hide.") }
    public var sendReadReceipts: String { return t("Прочтение сообщений", "Read Receipts") }
    public var sendTyping: String { return t("«Печатает…»", "\"Typing…\"") }
    public var sendOnlineStatus: String { return t("Онлайн-статус", "Online Status") }
    public var ghostModeFooter: String { return t("Выключенный пункт ничего не отправляет собеседникам. Без прочтения чаты отмечаются прочитанными только на этом устройстве. Без онлайн-статуса вы видны оффлайн, но отправка сообщения всё равно обновляет время последнего визита.", "A switched-off item sends nothing to others. Without read receipts, chats are marked read on this device only. Without online status you appear offline, but sending a message still updates your last seen time.") }

    public var groupsFolderHeader: String { return t("ПАПКА С ГРУППАМИ", "GROUPS FOLDER") }
    public var groupsFolder: String { return t("Папка с группами", "Groups Folder") }
    public var groupsFolderTitle: String { return t("Группы", "Groups") }
    public var groupsFolderMinMembersHeader: String { return t("МИНИМУМ УЧАСТНИКОВ", "MINIMUM MEMBERS") }
    public var groupsFolderFooter: String { return t("Группы, в которых не меньше указанного числа участников, убираются из «Все чаты» в папку под архивом. Число участников супергрупп загружается в фоне, поэтому они появляются в папке постепенно.", "Groups with at least this many members leave All Chats for a folder under the archive. Supergroup member counts load in the background, so they move into the folder gradually.") }

    public var close: String { return t("Закрыть", "Close") }

    public func memberCountLabel(_ value: Int32) -> String {
        if value >= 1000 && value % 1000 == 0 {
            return "\(value / 1000)K"
        } else if value >= 1000 {
            return String(format: "%.1fK", Double(value) / 1000.0)
        } else {
            return "\(value)"
        }
    }
}

extension ShadowgramStrings {
    public var interfaceHeader: String { return t("ИНТЕРФЕЙС", "INTERFACE") }
    public var showPeerIds: String { return t("Показывать ID пользователей", "Show User IDs") }
    public var showPeerIdsFooter: String { return t("Числовой ID появится в профилях пользователей, групп и каналов. По нажатию копируется.", "A numeric ID shows up in user, group and channel profiles. Tap it to copy.") }
    public var openByPeerId: String { return t("Открывать по ID из поиска", "Open by ID from Search") }
    public var openByPeerIdFooter: String { return t("Если в поиск ввести число, Shadowgram попробует открыть пользователя или чат с этим ID. Сервер отдаёт только тех, кого вы уже видели раньше.", "If you type a number into search, Shadowgram tries to open the user or chat with that ID. The server only returns peers you have already seen.") }
    public var disableCameraSwipe: String { return t("Отключить камеру слева по свайпу", "Disable left swipe camera") }
    public var disableCameraSwipeFooter: String { return t("Экран камеры в списке чатов больше не будет открываться смахиванием влево.", "The camera screen in the chat list will not open when you swipe left.") }

    public var messagesExtraHeader: String { return t("СООБЩЕНИЯ", "MESSAGES") }
    public var keepEditHistory: String { return t("Сохранять историю правок", "Keep Edit History") }
    public var keepEditHistoryFooter: String { return t("У отредактированных собеседником сообщений появится пункт «История правок» в меню по долгому нажатию.", "Edited messages gain an \"Edit History\" item in the long-press menu, with the earlier versions kept on this device.") }
}

extension ShadowgramStrings {
    public var openByPeerIdAction: String { return t("Открыть чат по ID…", "Open Chat by ID…") }
    public var openByPeerIdPrompt: String { return t("Введите числовой ID пользователя или чата. Чат можно открыть только если этот ID уже встречался этому аккаунту (общий чат, контакт, упоминание).", "Enter the numeric ID of a user or chat. A chat can be opened only if this ID has already been seen by this account (a shared chat, contact or mention).") }
    public var openByPeerIdOk: String { return t("Открыть", "Open") }
    public var openByPeerIdCancel: String { return t("Отмена", "Cancel") }
    public var openByPeerIdNotFound: String { return t("Чат с таким ID не найден на этом аккаунте.", "No chat with this ID was found on this account.") }
}
