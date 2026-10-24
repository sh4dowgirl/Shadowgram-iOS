import Foundation
import Postbox
import ShadowgramSettings

// Shadowgram: keep every previous text version of a message when the sender edits it,
// so the whole edit history is available from the long-press menu. Only text matters here:
// a repeated edit of the same text, or a media caption change where the text is unchanged,
// does not add a new entry. Entries are capped to avoid growing without bound on heavy editors.

private let shadowgramEditHistoryMaxEntries = 50

/// One past version of a message's text, kept with its timestamp.
public struct ShadowgramEditHistoryEntry: Equatable {
    public let text: String
    public let date: Int32

    public init(text: String, date: Int32) {
        self.text = text
        self.date = date
    }

    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

/// Message attribute carrying the edit history on the client. Newest entries are last.
public final class ShadowgramEditHistoryMessageAttribute: MessageAttribute {
    public let entries: [ShadowgramEditHistoryEntry]

    public init(entries: [ShadowgramEditHistoryEntry]) {
        self.entries = entries
    }

    required public init(decoder: PostboxDecoder) {
        let count = Int(decoder.decodeInt32ForKey("c", orElse: 0))
        var entries: [ShadowgramEditHistoryEntry] = []
        entries.reserveCapacity(count)
        for i in 0 ..< count {
            let prefix = "e\(i)_"
            let text = decoder.decodeStringForKey("\(prefix)t", orElse: "")
            let date = decoder.decodeInt32ForKey("\(prefix)d", orElse: 0)
            entries.append(ShadowgramEditHistoryEntry(text: text, date: date))
        }
        self.entries = entries
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(self.entries.count), forKey: "c")
        for (i, entry) in self.entries.enumerated() {
            let prefix = "e\(i)_"
            encoder.encodeString(entry.text, forKey: "\(prefix)t")
            encoder.encodeInt32(entry.date, forKey: "\(prefix)d")
        }
    }
}

/// Returns `attributes` extended so that the message's edit history holds every prior version.
///
/// `previousEntries` is the history already kept on the message before this edit — it must be read
/// from the *previous* stored message, because the server's updated message (whose `attributes` are
/// passed here) never carries this client-only attribute. Seeding from it is what makes the history
/// accumulate instead of resetting to a single entry on every edit. `previousText` is the text the
/// message had before this edit; it is appended as the newest kept version, so the full list is
/// every version except the current (live) one.
public func shadowgramAppendEditHistory(previousEntries: [ShadowgramEditHistoryEntry], previousText: String, previousDate: Int32, attributes: [MessageAttribute]) -> [MessageAttribute] {
    if !ShadowgramSettings.shared.values.keepEditHistory {
        return attributes
    }
    if previousText.isEmpty {
        return attributes
    }
    var existing = previousEntries
    var result: [MessageAttribute] = []
    result.reserveCapacity(attributes.count + 1)
    for attribute in attributes {
        // Drop any stale history copy in the passed attributes; previousEntries is authoritative.
        if attribute is ShadowgramEditHistoryMessageAttribute {
            continue
        }
        result.append(attribute)
    }
    if existing.last?.text == previousText {
        // Media edit without a text change; nothing new to keep.
        if existing.isEmpty {
            return attributes
        }
    } else {
        existing.append(ShadowgramEditHistoryEntry(text: previousText, date: previousDate))
    }
    if existing.count > shadowgramEditHistoryMaxEntries {
        existing.removeFirst(existing.count - shadowgramEditHistoryMaxEntries)
    }
    result.append(ShadowgramEditHistoryMessageAttribute(entries: existing))
    return result
}

public extension Message {
    /// The edit history kept for this message, oldest first, or an empty array when there is none.
    var shadowgramEditHistory: [ShadowgramEditHistoryEntry] {
        for attribute in self.attributes {
            if let attribute = attribute as? ShadowgramEditHistoryMessageAttribute {
                return attribute.entries
            }
        }
        return []
    }
}

public extension EngineMessage {
    var shadowgramEditHistory: [ShadowgramEditHistoryEntry] {
        for attribute in self.attributes {
            if let attribute = attribute as? ShadowgramEditHistoryMessageAttribute {
                return attribute.entries
            }
        }
        return []
    }
}

public struct ShadowgramEditHistoryVersion {
    public let message: Message
    public let isCurrent: Bool
    public let date: Int32
    public let text: String
}

public func shadowgramEditHistoryVersions(_ message: Message) -> [ShadowgramEditHistoryVersion] {
    let entries = message.shadowgramEditHistory
    var versions: [ShadowgramEditHistoryVersion] = []

    let currentDate = message.editedTime ?? message.timestamp
    versions.append(ShadowgramEditHistoryVersion(message: shadowgramEditHistoryVersionMessage(message, text: message.text, date: currentDate, keepEntities: true, index: 0), isCurrent: true, date: currentDate, text: message.text))

    for (offset, entry) in entries.reversed().enumerated() {
        versions.append(ShadowgramEditHistoryVersion(message: shadowgramEditHistoryVersionMessage(message, text: entry.text, date: entry.date, keepEntities: false, index: offset + 1), isCurrent: false, date: entry.date, text: entry.text))
    }
    return versions
}

private func shadowgramEditHistoryVersionMessage(_ message: Message, text: String, date: Int32, keepEntities: Bool, index: Int) -> Message {
    var attributes: [MessageAttribute] = []
    for attribute in message.attributes {
        if attribute is ShadowgramEditHistoryMessageAttribute || attribute is ShadowgramDeletedMessageAttribute || attribute is EditedMessageAttribute || attribute is ReactionsMessageAttribute || attribute is PendingReactionsMessageAttribute || attribute is ReplyThreadMessageAttribute {
            continue
        }
        if attribute is TextEntitiesMessageAttribute && !keepEntities {
            continue
        }
        attributes.append(attribute)
    }
    let media = message.media.filter { !($0 is TelegramMediaWebpage) }
    var flags = message.flags
    flags.remove(.Failed)
    flags.remove(.Unsent)
    flags.remove(.Sending)
    let id = MessageId(peerId: message.id.peerId, namespace: Namespaces.Message.Local, id: Int32.max - Int32(index))
    return Message(stableId: UInt32.max - UInt32(index), stableVersion: 0, id: id, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: message.threadId, timestamp: date, flags: flags, tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: message.forwardInfo, author: message.author, text: text, attributes: attributes, media: media, peers: message.peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds, associatedMedia: message.associatedMedia, associatedThreadInfo: message.associatedThreadInfo, associatedStories: message.associatedStories)
}
