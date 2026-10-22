import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit
import ShadowgramSettings

private typealias SignalKitTimer = SwiftSignalKit.Timer


private final class AccountPresenceManagerImpl {
    /// What the account reports to the server.
    private enum Mode: Equatable {
        /// Online, refreshed every 30 s (stock behaviour).
        case online
        /// Shadowgram ghost mode with online status hidden while the app is in front. The server also
        /// marks an account online on its own activity (sending a message, for example), so offline is
        /// sent right away and then repeated, which keeps the account "last seen" instead of "online".
        case ghostForeground
        /// Offline: the app is in the background.
        case offline
    }
    
    /// What the switches ask for: whether the app is in front and whether ghost mode hides online.
    private struct PresenceTarget: Equatable {
        let shouldKeepOnline: Bool
        let sendsOnlineStatus: Bool
        
        var isGhost: Bool {
            return !self.sendsOnlineStatus
        }
        
        var mode: Mode {
            if !self.shouldKeepOnline {
                return .offline
            } else if self.sendsOnlineStatus {
                return .online
            } else {
                return .ghostForeground
            }
        }
    }
    
    private let queue: Queue
    private let network: Network
    private let postbox: Postbox
    private let accountPeerId: PeerId
    private let contactPresencesDisposable = MetaDisposable()
    let isPerformingUpdate = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private var shouldKeepOnlinePresenceDisposable: Disposable?
    private let currentRequestDisposable = MetaDisposable()
    private var onlineTimer: SignalKitTimer?
    
    private var mode: Mode?
    
    init(queue: Queue, shouldKeepOnlinePresence: Signal<Bool, NoError>, network: Network, postbox: Postbox, accountPeerId: PeerId) {
        self.queue = queue
        self.network = network
        self.postbox = postbox
        self.accountPeerId = accountPeerId
        
        // Split into explicitly typed steps: as one chain the type checker gave up on it.
        let sendsOnlineStatus: Signal<Bool, NoError> = ShadowgramSettings.shared.valuesSignal
        |> map { values -> Bool in
            return values.effectiveSendOnlineStatus
        }
        |> distinctUntilChanged
        let combined: Signal<(Bool, Bool), NoError> = combineLatest(shouldKeepOnlinePresence, sendsOnlineStatus)
        let target: Signal<PresenceTarget, NoError> = combined
        |> map { values -> PresenceTarget in
            return PresenceTarget(shouldKeepOnline: values.0, sendsOnlineStatus: values.1)
        }
        |> distinctUntilChanged
        let delivered: Signal<PresenceTarget, NoError> = target |> deliverOn(queue)
        self.shouldKeepOnlinePresenceDisposable = delivered.start(next: { [weak self] target in
            self?.apply(target)
        })
    }
    
    private func apply(_ target: PresenceTarget) {
        let mode = target.mode
        let previousMode = self.mode
        if previousMode == mode {
            return
        }
        self.mode = mode
        if mode == .offline && previousMode == nil && !target.isGhost {
            // Stock behaviour: nothing to report at launch in the background.
            return
        }
        self.updatePresence(mode)
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.shouldKeepOnlinePresenceDisposable?.dispose()
        self.currentRequestDisposable.dispose()
        self.contactPresencesDisposable.dispose()
        self.onlineTimer?.invalidate()
    }
    
    private func updatePresence(_ mode: Mode) {
        self.onlineTimer?.invalidate()
        self.onlineTimer = nil
        
        let request: Signal<Api.Bool, MTRpcError>
        switch mode {
        case .online, .ghostForeground:
            let timer = SignalKitTimer(timeout: mode == .online ? 30.0 : 15.0, repeat: false, completion: { [weak self] in
                guard let self, self.mode == mode else {
                    return
                }
                self.updatePresence(mode)
            }, queue: self.queue)
            self.onlineTimer = timer
            timer.start()
            request = self.network.request(Api.functions.account.updateStatus(offline: mode == .online ? .boolFalse : .boolTrue))
            if mode == .ghostForeground {
                self.contactPresencesDisposable.set(updateContactPresences(postbox: self.postbox, network: self.network, accountPeerId: self.accountPeerId).start())
            }
        case .offline:
            request = self.network.request(Api.functions.account.updateStatus(offline: .boolTrue))
        }
        self.isPerformingUpdate.set(true)
        self.currentRequestDisposable.set((request
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> deliverOn(self.queue)).start(completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isPerformingUpdate.set(false)
        }))
    }
}

final class AccountPresenceManager {
    private let queue = Queue()
    private let impl: QueueLocalObject<AccountPresenceManagerImpl>
    
    init(shouldKeepOnlinePresence: Signal<Bool, NoError>, network: Network, postbox: Postbox, accountPeerId: PeerId) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: self.queue, generate: {
            return AccountPresenceManagerImpl(queue: queue, shouldKeepOnlinePresence: shouldKeepOnlinePresence, network: network, postbox: postbox, accountPeerId: accountPeerId)
        })
    }
    
    func isPerformingUpdate() -> Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.isPerformingUpdate.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
}
