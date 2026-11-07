import Foundation
import XCTest
import Postbox
import TelegramApi
import ShadowgramSettings
@testable import TelegramCore

/// Exercises the fork's hooks through the upstream state manager and its new replay structure.
final class ShadowgramReplayTests: StateSyncTestCase {
    private var originalSettings: ShadowgramSettingsValues?

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.originalSettings = ShadowgramSettings.shared.values
        ShadowgramSettings.shared.update {
            $0.saveDeletedMessages = false
            $0.keepEditHistory = false
            $0.autoReactions = [:]
        }
    }

    override func tearDown() {
        super.tearDown()
        if let originalSettings = self.originalSettings {
            ShadowgramSettings.shared.update { $0 = originalSettings }
        }
    }

    func testPrivateChatDeletionKeepsMessageAndAdvancesPts() {
        let peerId = self.seedUserChat(200)
        let id = self.messageId(peerId, 10)
        self.fixture.storeMessage(peerId: peerId, id: 10, timestamp: self.baseDate, authorId: peerId, text: "kept")
        ShadowgramSettings.shared.update { $0.saveDeletedMessages = true }
        self.launchIdle()

        self.server.push(StateSyncApi.updates([
            .updateDeleteMessages(.init(messages: [10], pts: 101, ptsCount: 1))
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.fixture.message(id)?.text, "kept")
        XCTAssertEqual(self.fixture.message(id)?.shadowgramIsDeleted, true)
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 101)
    }

    func testChannelDeletionKeepsMessageAndAdvancesChannelPts() {
        let peerId = self.seedChannel(300, pts: 20, storedMessageId: 10)
        ShadowgramSettings.shared.update { $0.saveDeletedMessages = true }
        self.launchIdle()

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updateDeleteChannelMessages(channelId: 300, messages: [10], pts: 21, ptsCount: 1)
        ], chats: [StateSyncApi.broadcastChannel(id: 300)], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 10))?.shadowgramIsDeleted, true)
        XCTAssertEqual(self.fixture.channelState(peerId)?.pts, 21)
    }

    func testConfirmationDeletionRespectsRetentionAndReturnsOnlyRemovedIds() {
        let peerId = self.seedUserChat(200)
        let id = self.messageId(peerId, 10)
        self.fixture.storeMessage(peerId: peerId, id: 10, timestamp: self.baseDate, authorId: peerId, text: "kept")
        let mediaBox = self.fixture.postbox.mediaBox
        ShadowgramSettings.shared.update { $0.saveDeletedMessages = true }

        let retained = self.fixture.transaction { transaction -> [MessageId] in
            return deleteStoredMessagesAsReceivedDeletion(transaction: transaction, mediaBox: mediaBox, ids: [id])
        }
        XCTAssertEqual(retained, [])
        XCTAssertEqual(self.fixture.message(id)?.shadowgramIsDeleted, true)

        ShadowgramSettings.shared.update { $0.saveDeletedMessages = false }
        let removed = self.fixture.transaction { transaction -> [MessageId] in
            return deleteStoredMessagesAsReceivedDeletion(transaction: transaction, mediaBox: mediaBox, ids: [id])
        }
        XCTAssertEqual(removed, [id])
        XCTAssertNil(self.fixture.message(id))
    }

    func testEditHistorySurvivesTheRecentEditRecordUsedByInflightFetches() {
        let peerId = self.seedUserChat(200)
        let id = self.messageId(peerId, 10)
        self.fixture.storeMessage(peerId: peerId, id: 10, timestamp: self.baseDate, authorId: peerId, text: "original")
        ShadowgramSettings.shared.update { $0.keepEditHistory = true }
        self.launchIdle()
        let since = FetchedAnswerAge.now()

        for (offset, text) in ["first edit", "second edit"].enumerated() {
            self.server.push(StateSyncApi.updates([
                .updateEditMessage(.init(message: StateSyncApi.privateMessage(id: 10, peerUserId: 200, fromUserId: 200, date: self.baseDate, text: text), pts: 101 + Int32(offset), ptsCount: 1))
            ], date: self.baseDate + 2, seq: 0))
            self.drainOperationQueue()
        }

        XCTAssertEqual(self.fixture.message(id)?.shadowgramEditHistory.map { $0.text }, ["original", "first edit"])
        let recordedHistory = self.fixture.transaction { transaction -> [String] in
            guard let edit = transaction.recentMessageEdit(id, since: since),
                  let history = edit.attributes.first(where: { $0 is ShadowgramEditHistoryMessageAttribute }) as? ShadowgramEditHistoryMessageAttribute else {
                return []
            }
            return history.entries.map { $0.text }
        }
        XCTAssertEqual(recordedHistory, ["original", "first edit"])
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 102)
    }

    func testNewIncomingMessageGetsItsConfiguredAutomaticReaction() {
        let peerId = self.seedUserChat(200)
        ShadowgramSettings.shared.update { $0.autoReactions = [peerId.toInt64(): [.emoji("👍")]] }
        self.launchIdle()

        self.server.push(StateSyncApi.updateShortMessage(id: 101, userId: 200, pts: 101, date: Int32(Date().timeIntervalSince1970)))
        self.drainOperationQueue()

        let pending = self.fixture.message(self.messageId(peerId, 101))?.attributes.first(where: { $0 is PendingReactionsMessageAttribute }) as? PendingReactionsMessageAttribute
        XCTAssertEqual(pending?.reactions.map { $0.value }, [.builtin("👍")])
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 101)
    }

    func testHistoryConfirmationKeepsClientOnlyAttributes() {
        let peerId = self.seedUserChat(200)
        let id = self.messageId(peerId, 10)
        self.fixture.storeMessage(peerId: peerId, id: 10, timestamp: self.baseDate, authorId: peerId, text: "original")
        ShadowgramSettings.shared.update {
            $0.saveDeletedMessages = true
            $0.keepEditHistory = true
        }
        self.launchIdle()
        self.server.push(StateSyncApi.updates([
            .updateEditMessage(.init(message: StateSyncApi.privateMessage(id: 10, peerUserId: 200, fromUserId: 200, date: self.baseDate, text: "edited"), pts: 101, ptsCount: 1)),
            .updateDeleteMessages(.init(messages: [10], pts: 102, ptsCount: 1))
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()
        XCTAssertEqual(self.fixture.message(id)?.shadowgramIsDeleted, true)

        let mediaBox = self.fixture.postbox.mediaBox
        self.fixture.transaction { transaction -> Void in
            guard let stored = transaction.getMessage(id) else {
                XCTFail("the replay lost the retained message")
                return
            }
            let fresh = StoreMessage(id: id, customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: self.baseDate, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: "edited", attributes: [], media: [])
            let confirmation = StoredMessageConfirmation(existing: [fresh], peers: AccumulatedPeers(), missing: [])
            applyStoredMessageConfirmation(transaction: transaction, accountPeerId: StateSyncFixture.accountPeerId, mediaBox: mediaBox, confirmation: confirmation, versions: [id: stored.stableVersion])
        }

        XCTAssertEqual(self.fixture.message(id)?.shadowgramIsDeleted, true)
        XCTAssertEqual(self.fixture.message(id)?.shadowgramEditHistory.map { $0.text }, ["original"])
    }
}
