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

/// If `previousText` is a real previous version (different, non-empty), returns the message
/// attributes extended with that version. Otherwise returns `attributes` unchanged.
public func shadowgramAppendEditHistory(previousText: String, previousDate: Int32, attributes: [MessageAttribute]) -> [MessageAttribute] {
    if !ShadowgramSettings.shared.values.keepEditHistory {
        return attributes
    }
    if previousText.isEmpty {
        return attributes
    }
    var existing: [ShadowgramEditHistoryEntry] = []
    var result: [MessageAttribute] = []
    result.reserveCapacity(attributes.count)
    for attribute in attributes {
        if let historyAttribute = attribute as? ShadowgramEditHistoryMessageAttribute {
            existing = historyAttribute.entries
        } else {
            result.append(attribute)
        }
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
