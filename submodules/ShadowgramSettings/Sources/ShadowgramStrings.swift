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
    public var sendStoryViews: String { return t("Отправка просмотра историй", "Story Views") }
    public var ghostModeFooter: String { return t("Выключенный пункт ничего не отправляет собеседникам. Без прочтения чаты отмечаются прочитанными только на этом устройстве. Без онлайн-статуса вы видны оффлайн, но отправка сообщения всё равно обновляет время последнего визита. Без отправки просмотра истории отмечаются просмотренными только на этом устройстве, и автор не увидит вас среди зрителей.", "A switched-off item sends nothing to others. Without read receipts, chats are marked read on this device only. Without online status you appear offline, but sending a message still updates your last seen time. Without story views, stories are marked seen on this device only and the author does not see you among the viewers.") }

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

    public var privacyHeader: String { return t("ПРИВАТНОСТЬ И ОГРАНИЧЕНИЯ", "PRIVACY & RESTRICTIONS") }
    public var showExactLastSeen: String { return t("Точное время в сети", "Exact Last Seen") }
    public var showExactLastSeenFooter: String { return t("Показывает точное время последнего визита пользователя, даже если он скрыл его в настройках приватности. Работает только при наличии данных, которые Telegram передаёт для сортировки контактов.", "Shows the exact last seen time even when a user hides it in privacy settings. Works only when data is available — Telegram transmits it for contact sorting.") }
    public var bypassCopyProtection: String { return t("Снять защиту от копирования", "Bypass Copy Protection") }
    public var bypassCopyProtectionFooter: String { return t("Разрешает пересылку, копирование текста, скриншоты и запись экрана в чатах с включённой защитой контента и в секретных чатах.", "Allows forwarding, text copying, screenshots and screen recording in chats with content protection and in secret chats.") }
    public var bypassViewOnce: String { return t("Одноразовые медиа без ограничений", "Unlimited View-Once Media") }
    public var bypassViewOnceFooter: String { return t("Одноразовые фото и видео можно просматривать сколько угодно раз. Отправитель не получит уведомления о просмотре, скриншоты и запись экрана тоже не будут ограничены.", "View-once photos and videos can be viewed unlimited times. The sender won't be notified, and screenshots and screen recording won't be restricted.") }
}

extension ShadowgramStrings {
}

extension ShadowgramStrings {
    public var captureHeader: String { return t("СКРЫВАТЬ НА СКРИНШОТАХ И ЗАПИСИ ЭКРАНА", "HIDE ON SCREENSHOTS AND SCREEN RECORDING") }
    public var hidePhoneOnCapture: String { return t("Номер телефона", "Phone Number") }
    public var hideEmailOnCapture: String { return t("Электронная почта", "Email") }
    public var hideIdOnCapture: String { return t("ID", "ID") }
    public var hideUsernameOnCapture: String { return t("Юзернейм (@тег)", "Username (@tag)") }
    public var captureFooter: String { return t("Включённые данные видны вам на экране, но на скриншотах, записи экрана и трансляциях вместо них пусто. В шапке настроек номер и юзернейм стоят в одной строке, поэтому она скрывается целиком, если скрыто хотя бы одно из двух.", "Selected data stays visible on your screen but is blank on screenshots, screen recordings and streams. In the Settings header the phone number and username share one line, so the whole line is hidden if either of them is.") }

    public var markChatPrivate: String { return t("Сделать приватным", "Mark as Private") }
    public var unmarkChatPrivate: String { return t("Убрать из приватных", "Remove from Private") }
}

extension ShadowgramStrings {
    public var autoReaction: String { return t("Авто-реакция", "Auto Reaction") }
    public var autoReactionOff: String { return t("Выкл", "Off") }
    public var autoReactionUsersHeader: String { return t("ПОЛЬЗОВАТЕЛИ", "USERS") }
    public var autoReactionAddUser: String { return t("Добавить пользователя", "Add User") }
    public var autoReactionSelectUser: String { return t("Выберите пользователя", "Select User") }
    public var autoReactionFooter: String { return t("На каждое новое сообщение от этих пользователей Shadowgram сам поставит выбранную реакцию: в личном чате и, если включён переключатель «В группах», в группах, где такая реакция разрешена. Нажмите на пользователя, чтобы сменить реакцию, смахните влево, чтобы убрать. Реакции из своих эмодзи работают только с Telegram Premium.", "Shadowgram puts the chosen reaction on every new message from these users: in your private chat and, if In Groups is on, in groups that allow that reaction. Tap a user to change the reaction, swipe left to remove them. Custom emoji reactions require Telegram Premium.") }

    public func autoReactionUserCount(_ count: Int) -> String {
        if self.isRussian {
            let mod10 = count % 10
            let mod100 = count % 100
            if mod10 == 1 && mod100 != 11 {
                return "\(count) пользователь"
            } else if (2 ... 4).contains(mod10) && !(12 ... 14).contains(mod100) {
                return "\(count) пользователя"
            } else {
                return "\(count) пользователей"
            }
        } else {
            return count == 1 ? "1 user" : "\(count) users"
        }
    }

    public var groupsFolderPlacementHeader: String { return t("ГДЕ ПОКАЗЫВАТЬ ПАПКУ", "WHERE TO SHOW THE FOLDER") }
    public var groupsFolderPlacementArchive: String { return t("Рядом с архивом", "Next to the Archive") }
    public var groupsFolderPlacementTab: String { return t("Отдельная вкладка", "Separate Tab") }
}

extension ShadowgramStrings {
    public var editHistoryTitle: String { return t("История правок", "Edit History") }
    public var editHistoryCurrent: String { return t("СЕЙЧАС", "CURRENT") }
    public var editHistoryEarlier: String { return t("ПРЕДЫДУЩИЕ ВЕРСИИ", "EARLIER VERSIONS") }
    public var editHistoryCurrentVersion: String { return t("Текущая версия", "Current version") }
    public var editHistoryVersion: String { return t("Версия", "Version") }
    public var editHistoryEmptyText: String { return t("Без текста", "No text") }
}

extension ShadowgramStrings {
    public var chatListSortNewestFirst: String { return t("Сначала новые", "Newest First") }
    public var chatListSortOldestFirst: String { return t("Сначала старые", "Oldest First") }
}

extension ShadowgramStrings {
    public var chatListSortHeader: String { return t("СОРТИРОВКА ЧАТОВ", "CHAT SORTING") }
    public var unlimitedAccountsShort: String { return t("Без лимита", "Unlimited") }
    public var extraSettingsFooter: String { return t("Все настройки хранятся только на этом устройстве.", "All settings are stored on this device only.") }

    public func extraSettingsCategoryTitle(_ category: Int32) -> String {
        switch category {
        case 0:
            return t("Конфиденциальность", "Privacy")
        case 1:
            return t("Сообщения", "Messages")
        case 2:
            return t("Список чатов", "Chat List")
        case 3:
            return t("Интерфейс", "Interface")
        case 4:
            return t("Аккаунты", "Accounts")
        default:
            return "Premium"
        }
    }
}

extension ShadowgramStrings {
    public var forwardSelfDestructingMedia: String { return t("Пересылка исчезающих медиа", "Forward Self-Destructing Media") }
    public var forwardSelfDestructingMediaFooter: String { return t("При просмотре исчезающего фото или видео появляется кнопка, которая пересылает его как обычное медиа.", "While viewing a self-destructing photo or video, a button forwards it as regular media.") }
    public var roundVideoCameraHeader: String { return t("ВИДЕОСООБЩЕНИЯ СНИМАТЬ НА", "RECORD VIDEO MESSAGES WITH") }
    public var roundVideoCameraFront: String { return t("Фронтальную камеру", "Front Camera") }
    public var roundVideoCameraBack: String { return t("Основную камеру", "Back Camera") }
    public var mediaHeader: String { return t("МЕДИА", "MEDIA") }
    public var pictureInPictureOnBackground: String { return t("Картинка в картинке при сворачивании", "Picture in Picture on Leaving") }
    public var pictureInPictureOnBackgroundFooter: String { return t("Видео, которое играет при сворачивании Telegram, продолжает воспроизводиться в окне поверх других приложений.", "A video that is playing when you leave Telegram keeps playing in a floating window over other apps.") }
    public var selfDestructingMarkViewed: String { return t("Отметить просмотренным", "Mark as Viewed") }
    public var selfDestructingMarkedViewed: String { return t("Отправитель увидит, что вы открыли медиа.", "The sender will see that you opened the media.") }
}

extension ShadowgramStrings {
    public var premiumUnlocksHeader: String { return t("ФУНКЦИИ PREMIUM", "PREMIUM FEATURES") }
    public var unlockStoryTools: String { return t("Сохранение и HD-качество историй", "Save Stories and HD Quality") }
    public var unlockMediaSaving: String { return t("Сохранение видео в оригинале", "Save Videos in Original Quality") }
    public var unlockChatTranslation: String { return t("Перевод всего чата", "Translate Entire Chats") }
    public var hideAds: String { return t("Скрыть рекламу", "Hide Ads") }
    public var unlockExtraFolders: String { return t("Папки сверх лимита", "Folders Over the Limit") }
    public var premiumUnlocksFooter: String { return t("Открывает функции Telegram Premium, которые работают на устройстве. Перевод всего чата включается в Настройки ▸ Язык. Папки сверх лимита можно открывать, но новые создать нельзя: это проверяет сервер.", "Unlocks Telegram Premium features that work on the device. Turn on entire chat translation in Settings ▸ Language. Folders over the limit can be opened, but new ones can't be created: the server checks that.") }
}

extension ShadowgramStrings {
    public var messageBlockedUsers: String { return t("Писать заблокированным", "Message Blocked Users") }
    public var messageBlockedUsersFooter: String { return t("В чате с заблокированным вами пользователем вместо кнопки «Разблокировать» остаётся поле ввода, и сообщения можно отправлять, не снимая блокировку. Блокировка при этом сохраняется.", "In a chat with a user you have blocked, the message input stays instead of the Unblock button, so you can send messages without unblocking. The block itself stays in place.") }

    public var autoReactionInGroups: String { return t("В группах", "In Groups") }
    public var autoReactionInGroupsFooter: String { return t("Если включено, реакция ставится на сообщения выбранных пользователей и в группах (где такая реакция разрешена). Если выключено — только в личных чатах.", "When on, the reaction is also put on messages from the chosen users in groups (where that reaction is allowed). When off, only in private chats.") }

    public var ghostModeToggleAll: String { return t("Переключить все", "Toggle All") }
    public var sendReadReceiptsInfo: String { return t("Собеседник не увидит, что вы прочитали его сообщения. Чат отмечается прочитанным только на этом устройстве.", "Others won't see that you read their messages. The chat is marked read on this device only.") }
    public var sendTypingInfo: String { return t("Собеседник не увидит, что вы печатаете, записываете голосовое или выбираете файл.", "Others won't see that you are typing, recording a voice message or choosing a file.") }
    public var sendOnlineStatusInfo: String { return t("Вы выглядите офлайн, пока приложение открыто. Отправка сообщения всё равно обновляет время последнего визита.", "You appear offline while the app is open. Sending a message still updates your last seen time.") }
    public var sendStoryViewsInfo: String { return t("Автор истории не увидит вас среди зрителей. История отмечается просмотренной только на этом устройстве.", "The author won't see you among the viewers. The story is marked seen on this device only.") }
}

extension ShadowgramStrings {
    public var forwardProtectedAsCopy: String { return t("Пересылать копией", "Forward as a Copy") }
    public var forwardProtectedAsCopyFooter: String { return t("Сервер не пропускает пересылку из чатов, где она запрещена. Такие сообщения отправляются копией в цитате с именем автора, как удалённые. Медиа отправляется, только если уже загружено на устройство.", "The server refuses forwards from chats where forwarding is restricted. Such messages are sent as a copy in a quote with the author's name, like deleted ones. Media is sent only if it is already downloaded to the device.") }
}
