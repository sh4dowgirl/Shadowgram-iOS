import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import ItemListPeerItem
import PresentationDataUtils
import AccountContext
import ShadowgramSettings

private final class ShadowgramEditHistoryChatContents: ChatCustomContentsProtocol, ChatCustomContentsTitleProviding {
    let kind: ChatCustomContentsKind = .hashTagSearch(publicPosts: false)
    let customTitle: String
    let customSubtitle: String?
    let messageLimit: Int? = nil
    var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in }

    private let view: EngineRawMessageHistoryView

    init(message: EngineRawMessage, title: String, subtitle: String?) {
        self.customTitle = title
        self.customSubtitle = subtitle
        self.view = EngineRawMessageHistoryView(tag: nil, namespaces: .just(Set([message.id.namespace])), entries: [EngineRawMessageHistoryEntry(message: message, isRead: true, location: nil, monthLocation: nil, attributes: EngineRawMutableMessageHistoryEntryAttributes(authorIsContact: false))], holeEarlier: false, holeLater: false, isLoading: false)
    }

    var historyView: Signal<(EngineRawMessageHistoryView, EngineViewUpdateType), NoError> {
        return .single((self.view, .Initial))
    }

    func enqueueMessages(messages: [EnqueueMessage]) {
    }

    func deleteMessages(ids: [EngineMessage.Id]) {
    }

    func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {
    }

    func quickReplyUpdateShortcut(value: String) {
    }

    func businessLinkUpdate(message: String, entities: [TelegramCore.MessageTextEntity], title: String?) {
    }

    func loadMore() {
    }

    func hashtagSearchUpdate(query: String) {
    }
}

private final class ShadowgramEditHistoryArguments {
    let context: AccountContext
    let openVersion: (Int) -> Void

    init(context: AccountContext, openVersion: @escaping (Int) -> Void) {
        self.context = context
        self.openVersion = openVersion
    }
}

private enum ShadowgramEditHistorySection: Int32 {
    case current
    case earlier
}

private enum ShadowgramEditHistoryEntry: ItemListNodeEntry {
    case header(ShadowgramEditHistorySection)
    case version(index: Int, peer: EnginePeer, text: String, date: String, isCurrent: Bool)

    var section: ItemListSectionId {
        switch self {
        case let .header(section):
            return section.rawValue
        case let .version(_, _, _, _, isCurrent):
            return isCurrent ? ShadowgramEditHistorySection.current.rawValue : ShadowgramEditHistorySection.earlier.rawValue
        }
    }

    var stableId: Int {
        switch self {
        case let .header(section):
            return section == .current ? -2 : -1
        case let .version(index, _, _, _, _):
            return index
        }
    }

    static func ==(lhs: ShadowgramEditHistoryEntry, rhs: ShadowgramEditHistoryEntry) -> Bool {
        switch lhs {
        case let .header(section):
            if case .header(section) = rhs {
                return true
            }
            return false
        case let .version(index, peer, text, date, isCurrent):
            if case .version(index, peer, text, date, isCurrent) = rhs {
                return true
            }
            return false
        }
    }

    static func <(lhs: ShadowgramEditHistoryEntry, rhs: ShadowgramEditHistoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ShadowgramEditHistoryArguments
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        switch self {
        case let .header(section):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: section == .current ? strings.editHistoryCurrent : strings.editHistoryEarlier, sectionId: self.section)
        case let .version(index, peer, text, date, isCurrent):
            return ItemListPeerItem(presentationData: presentationData, systemStyle: .glass, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer, presence: nil, text: .text(text, isCurrent ? .accent : .secondary), label: .text(date, .standard, nil, false), editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                arguments.openVersion(index)
            }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
        }
    }
}

private func shadowgramEditHistoryPreview(_ text: String, strings: ShadowgramStrings) -> String {
    let firstLine = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
    let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? strings.editHistoryEmptyText : trimmed
}

private func shadowgramEditHistoryTimestamp(_ timestamp: Int32, dateTimeFormat: PresentationDateTimeFormat) -> String {
    var t = time_t(timestamp)
    var components = tm()
    localtime_r(&t, &components)
    let hour = Int(components.tm_hour)
    let minute = Int(components.tm_min)
    let day = Int(components.tm_mday)
    let month = Int(components.tm_mon + 1)
    let year = Int(components.tm_year + 1900) % 100

    var now = time_t(Int(Date().timeIntervalSince1970))
    var nowComponents = tm()
    localtime_r(&now, &nowComponents)

    let timeString: String
    switch dateTimeFormat.timeFormat {
    case .military:
        timeString = String(format: "%02d:%02d", hour, minute)
    case .regular:
        let hour12 = (hour % 12 == 0) ? 12 : hour % 12
        timeString = String(format: "%d:%02d %@", hour12, minute, hour >= 12 ? "PM" : "AM")
    }
    if nowComponents.tm_year == components.tm_year && nowComponents.tm_yday == components.tm_yday {
        return timeString
    }
    let separator = dateTimeFormat.dateSeparator
    let dateString: String
    switch dateTimeFormat.dateFormat {
    case .monthFirst:
        dateString = String(format: "%02d%@%02d%@%02d", month, separator, day, separator, year)
    case .dayFirst:
        dateString = String(format: "%02d%@%02d%@%02d", day, separator, month, separator, year)
    }
    return "\(dateString) \(timeString)"
}

public func shadowgramEditHistoryController(context: AccountContext, message: EngineRawMessage) -> ViewController {
    let versions = shadowgramEditHistoryVersions(message)

    var peer: EnginePeer?
    if let author = message.author {
        peer = EnginePeer(author)
    } else if let chatPeer = message.peers[message.id.peerId] {
        peer = EnginePeer(chatPeer)
    }

    var dismissImpl: (() -> Void)?
    var pushImpl: ((ViewController) -> Void)?

    let arguments = ShadowgramEditHistoryArguments(context: context, openVersion: { index in
        guard index < versions.count else {
            return
        }
        let version = versions[index]
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let title = version.isCurrent ? strings.editHistoryCurrentVersion : "\(strings.editHistoryVersion) \(versions.count - index)"
        let contents = ShadowgramEditHistoryChatContents(message: version.message, title: title, subtitle: shadowgramEditHistoryTimestamp(version.date, dateTimeFormat: presentationData.dateTimeFormat))
        let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .customChatContents, subject: .customChatContents(contents: contents), botStart: nil, mode: .standard(.default), params: nil)
        pushImpl?(chatController)
    })

    let signal = context.sharedContext.presentationData
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)

        var entries: [ShadowgramEditHistoryEntry] = []
        if let peer {
            for (index, version) in versions.enumerated() {
                if index == 0 {
                    entries.append(.header(.current))
                } else if index == 1 {
                    entries.append(.header(.earlier))
                }
                entries.append(.version(index: index, peer: peer, text: shadowgramEditHistoryPreview(version.text, strings: strings), date: shadowgramEditHistoryTimestamp(version.date, dateTimeFormat: presentationData.dateTimeFormat), isCurrent: version.isCurrent))
            }
        }

        let closeButton = ItemListNavigationButton(content: .text(strings.close), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.editHistoryTitle), leftNavigationButton: closeButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
