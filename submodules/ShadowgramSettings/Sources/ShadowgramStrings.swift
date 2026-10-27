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
    public var autoReactionSelectUser: String { return t("Выберите пользователя или канал", "Select User or Channel") }
    public var autoReactionFooter: String { return t("На каждое новое сообщение от этих пользователей или постов этих каналов Shadowgram сам поставит выбранные реакции: в личном чате всегда, в группах и каналах — если включён переключатель «В группах». Одного и того же пользователя или канал можно добавить до 3 раз, чтобы поставить сразу несколько реакций (как Premium при выборе вручную). Нажмите на строку, чтобы сменить реакцию, смахните влево, чтобы убрать. Реакции из своих эмодзи работают только с Telegram Premium.", "Shadowgram puts the chosen reactions on every new message from these users and posts from these channels: always in a private chat, and in groups/channels if In Groups is on. The same user or channel can be added up to 3 times to put several reactions at once, like Premium lets you do by hand. Tap a row to change its reaction, swipe left to remove it. Custom emoji reactions require Telegram Premium.") }

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
            return t("Обход ограничений", "Bypass Restrictions")
        case 3:
            return t("Список чатов", "Chat List")
        case 4:
            return t("Медиа", "Media")
        case 5:
            return t("Интерфейс", "Interface")
        case 6:
            return t("Локальные правки", "Local Edits")
        default:
            return t("Premium и аккаунты", "Premium & Accounts")
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

    // Gift Editing - a purely local, per-device overlay on a profile's gift grid.
    public var shadowgramGiftEditingAddGift: String { return t("Добавить подарок", "Add Gift") }
    public var shadowgramGiftEditingEditGifts: String { return t("Редактировать подарки", "Edit Gifts") }
    public var shadowgramGiftEditingDoneEditing: String { return t("Готово", "Done") }
    public var shadowgramGiftEditingRemovedGifts: String { return t("Удалённые подарки", "Removed Gifts") }
    public var shadowgramGiftDeleted: String { return t("Добавленный подарок удалён.", "The added gift was deleted.") }
    public var shadowgramGiftHidden: String { return t("Подарок скрыт локально. Его можно вернуть в разделе «Удалённые подарки».", "The gift was hidden on this device. It can be brought back from the Removed Gifts screen.") }
    public var shadowgramGiftRestored: String { return t("Подарок возвращён.", "The gift was restored.") }
    public var shadowgramGiftEditingAddTitle: String { return t("Новый подарок", "New Gift") }
    public var shadowgramGiftEditingPickBase: String { return t("Подарок", "Gift") }
    public var shadowgramGiftEditingMakeUnique: String { return t("Уникальный (NFT)", "Unique (NFT)") }
    public var shadowgramGiftEditingModel: String { return t("Модель", "Model") }
    public var shadowgramGiftEditingBackdrop: String { return t("Фон", "Backdrop") }
    public var shadowgramGiftEditingPattern: String { return t("Узор", "Pattern") }
    public var shadowgramGiftEditingNumber: String { return t("Номер экземпляра", "Instance Number") }
    public var shadowgramGiftEditingText: String { return t("Сообщение к подарку", "Message with the Gift") }
    public var shadowgramGiftEditingSender: String { return t("Отправитель", "Sender") }
    public var shadowgramGiftEditingDate: String { return t("Дата получения", "Date Received") }
    public var shadowgramGiftEditingUpgraded: String { return t("Можно конвертировать в звёзды", "Convertible to Stars") }
    public var shadowgramGiftEditingSave: String { return t("Добавить в профиль", "Add to Profile") }
    public var shadowgramGiftEditingRemovedGiftsEmpty: String { return t("Здесь появятся настоящие подарки, которые вы убрали в режиме редактирования. Нажмите на подарок, чтобы вернуть его в профиль.", "Real gifts you remove in edit mode show up here. Tap a gift to put it back on the profile.") }
    public var shadowgramGiftEditingRestore: String { return t("Вернуть", "Restore") }
    public var shadowgramGiftEditingRemovedFooter: String { return t("Нажмите на подарок, чтобы вернуть его. Скрыты они только на этом устройстве.", "Tap a gift to put it back. They are hidden on this device only.") }
    public var shadowgramGiftEditingGiftHeader: String { return t("ПОДАРОК", "GIFT") }
    public var shadowgramGiftEditingNotChosen: String { return t("Выбрать", "Choose") }
    public var shadowgramGiftEditingGiftFooter: String { return t("Выберите подарок из каталога, как при отправке. Потом можно сделать его уникальным и настроить всё остальное.", "Choose a gift from the catalog, as when sending one. Then you can make it unique and set up the rest.") }
    public var shadowgramGiftEditingNumberPlaceholder: String { return t("Номер (случайный, если пусто)", "Number (random if empty)") }
    public var shadowgramGiftEditingNftFooter: String { return t("Модель, фон и узор берутся из настоящей коллекции этого подарка. Подарок будет выглядеть как улучшенный и принадлежать этому профилю.", "The model, backdrop and pattern come from this gift's real collection. The gift looks upgraded and owned by this profile.") }
    public var shadowgramGiftEditingRegularFooter: String { return t("Обычный подарок, как купленный в каталоге.", "A regular gift, as if bought from the catalog.") }
    public var shadowgramGiftEditingSenderHeader: String { return t("ОТ КОГО", "FROM") }
    public var shadowgramGiftEditingSenderNone: String { return t("Не указан", "None") }
    public var shadowgramGiftEditingSenderClear: String { return t("Убрать отправителя", "Remove Sender") }
    public var shadowgramGiftEditingHideSender: String { return t("Скрыть имя отправителя", "Hide Sender's Name") }
    public var shadowgramGiftEditingMessageHeader: String { return t("СООБЩЕНИЕ И ДАТА", "MESSAGE AND DATE") }
    public var shadowgramGiftEditingOptionsHeader: String { return t("В ПРОФИЛЕ", "ON THE PROFILE") }
    public var shadowgramGiftEditingPinned: String { return t("Закрепить сверху", "Pin to Top") }
    public var shadowgramGiftEditingCanUpgrade: String { return t("Можно улучшить", "Can Be Upgraded") }
    public var shadowgramGiftEditingPreview: String { return t("Посмотреть, как будет выглядеть", "Preview") }
    public var shadowgramGiftEditingCatalogEmpty: String { return t("Каталог подарков ещё не загружен. Откройте экран отправки подарка один раз и попробуйте снова.", "The gift catalog has not loaded yet. Open the Send Gift screen once and try again.") }
    public var shadowgramGiftEditingAttributesEmpty: String { return t("У этого подарка нет вариантов улучшения.", "This gift has no upgrade variants.") }
    public var shadowgramGiftEditingAttributesFooter: String { return t("Процент — редкость, как у настоящих подарков.", "The percentage is the rarity, as on real gifts.") }

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

    public var autoReactionInGroups: String { return t("В группах и каналах", "In Groups and Channels") }
    public var autoReactionInGroupsFooter: String { return t("Если включено, реакция ставится на сообщения выбранных пользователей и постов выбранных каналов также в группах и каналах (где такая реакция разрешена). Если выключено — только в личных чатах.", "When on, the reaction is also put on messages from the chosen users and posts from the chosen channels in groups and channels (where that reaction is allowed). When off, only in private chats.") }

    public var blockedMeAlertTitle: String { return t("Возможно, вы заблокированы", "Possibly Blocked") }
    public var blockedMeAlertText: String { return t("У этого пользователя нет фото и он был в сети «давно». Это совпадает с тем, как выглядит заблокировавший вас контакт, но также бывает у неактивных аккаунтов.", "This user has no photo and was last seen \"a long time ago\". This matches how a contact who blocked you looks, but it can also be an inactive account.") }

    public var ghostModeToggleAll: String { return t("Переключить все", "Toggle All") }
    public var sendReadReceiptsInfo: String { return t("Собеседник не увидит, что вы прочитали его сообщения. Чат отмечается прочитанным только на этом устройстве.", "Others won't see that you read their messages. The chat is marked read on this device only.") }
    public var sendTypingInfo: String { return t("Собеседник не увидит, что вы печатаете, записываете голосовое или выбираете файл.", "Others won't see that you are typing, recording a voice message or choosing a file.") }
    public var sendOnlineStatusInfo: String { return t("Вы выглядите офлайн, пока приложение открыто. Отправка сообщения всё равно обновляет время последнего визита.", "You appear offline while the app is open. Sending a message still updates your last seen time.") }
    public var sendStoryViewsInfo: String { return t("Автор истории не увидит вас среди зрителей. История отмечается просмотренной только на этом устройстве.", "The author won't see you among the viewers. The story is marked seen on this device only.") }
}

extension ShadowgramStrings {
}

extension ShadowgramStrings {
    public var lastSeenUnknown: String { return t("был(а): неизвестно", "last seen: unknown") }
}

extension ShadowgramStrings {
    public var messagesDeletedEditedHeader: String { return t("УДАЛЁННЫЕ И ИЗМЕНЁННЫЕ", "DELETED AND EDITED") }
    public var messagesSendingHeader: String { return t("ОТПРАВКА", "SENDING") }
    public var restrictionsProtectedHeader: String { return t("ЗАЩИЩЁННЫЕ ЧАТЫ", "PROTECTED CHATS") }
    public var restrictionsSelfDestructingHeader: String { return t("ИСЧЕЗАЮЩИЕ МЕДИА", "SELF-DESTRUCTING MEDIA") }
    public var chatListSortFooter: String { return t("Порядок меняется только у непрочитанных чатов, прочитанные остаются на своих местах.", "Only unread chats are reordered; read chats keep their places.") }
    public var peerIdsHeader: String { return t("ID ПОЛЬЗОВАТЕЛЕЙ И ЧАТОВ", "USER AND CHAT IDS") }
    public var localEditsStarsHeader: String { return t("ЗВЁЗДЫ", "STARS") }
    public var localEditsGiftsHeader: String { return t("ПОДАРКИ", "GIFTS") }
    public var starsEditing: String { return t("Редактирование звёзд", "Stars Editing") }
    public var starsEditingFooter: String { return t("На экране звёзд появится карандаш справа сверху: им можно поменять показываемый баланс. Меняется только отображение на этом устройстве, настоящий баланс не затрагивается. Если выключить, снова виден настоящий баланс, а правка сохраняется до следующего включения.", "A pencil appears top right on the Stars screen to change the balance shown. Only what this device displays changes; the real balance is untouched. Turning this off shows the real balance again and keeps your edit for next time.") }
    public var giftEditing: String { return t("Редактирование подарков", "Gift Editing") }
    public var giftEditingFooter: String { return t("Во вкладке «Подарки» любого профиля рядом с сортировкой появятся кнопки: добавить подарок, редактировать (удаление прямо в сетке) и удалённые подарки. Всё видно только на этом устройстве, на сервер ничего не отправляется. Если выключить, профиль снова показывает настоящие подарки, а правки сохраняются.", "The Gifts tab of any profile gets buttons next to sorting: add a gift, edit (remove right in the grid), and removed gifts. Everything is visible on this device only; nothing is sent to the server. Turning this off shows the real gifts again and keeps your edits.") }

    public var starsEditingTitle: String { return t("Баланс звёзд", "Stars Balance") }
    public var starsEditingAmountHeader: String { return t("КОЛИЧЕСТВО", "AMOUNT") }
    public var starsEditingAmountPlaceholder: String { return t("Число звёзд", "Number of Stars") }
    public var starsEditingAdd: String { return t("Добавить", "Add") }
    public var starsEditingSubtract: String { return t("Вычесть", "Subtract") }
    public var starsEditingSet: String { return t("Установить", "Set") }
    public var starsEditingReset: String { return t("Показать настоящий баланс", "Show Real Balance") }
    public var starsEditingCurrentHeader: String { return t("СЕЙЧАС ПОКАЗЫВАЕТСЯ", "CURRENTLY SHOWN") }
    public var starsEditingOverridden: String { return t("Изменён на этом устройстве", "Changed on this device") }
    public var starsEditingReal: String { return t("Настоящий баланс", "Real balance") }
    public var starsEditingFooterNote: String { return t("Меняется только то, что показывает это устройство. Настоящие звёзды не начисляются и не списываются.", "Only what this device shows changes. No real Stars are credited or debited.") }
}
