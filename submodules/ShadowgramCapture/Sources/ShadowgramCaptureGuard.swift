import Foundation
import UIKit
import SwiftSignalKit
import UIKitRuntimeUtils
import ShadowgramSettings

/// Personal data that Extra Settings can hide from screenshots, screen recordings and streams.
public enum ShadowgramCaptureKind: Hashable {
    case phone
    case email
    case id
    case username
}

public extension ShadowgramSettingsValues {
    func hidesOnCapture(_ kind: ShadowgramCaptureKind) -> Bool {
        switch kind {
        case .phone:
            return self.hidePhoneOnCapture
        case .email:
            return self.hideEmailOnCapture
        case .id:
            return self.hideIdOnCapture
        case .username:
            return self.hideUsernameOnCapture
        }
    }
}

/// Keeps one layer hidden from screen capture while it shows any of `kinds` and the matching
/// switch is on. It follows the switches live, so turning one on applies to what is already on
/// screen. The layer stays visible on the device itself: this is the secure-text-field mechanism
/// secret chats use (`setLayerDisableScreenshots`).
///
/// Create and update on the main thread.
public final class ShadowgramCaptureGuard {
    private weak var layer: CALayer?
    private var kinds: Set<ShadowgramCaptureKind> = Set()
    private var values: ShadowgramSettingsValues
    private var isApplied = false
    private var disposable: Disposable?

    public init(layer: CALayer) {
        self.layer = layer
        self.values = ShadowgramSettings.shared.values
        self.disposable = (ShadowgramSettings.shared.valuesSignal
        |> deliverOnMainQueue).start(next: { [weak self] values in
            guard let self else {
                return
            }
            self.values = values
            self.apply()
        })
    }

    deinit {
        self.disposable?.dispose()
    }

    /// What the layer currently shows. An empty set means nothing to hide.
    public func update(kinds: Set<ShadowgramCaptureKind>) {
        self.kinds = kinds
        self.apply()
    }

    private func apply() {
        guard let layer = self.layer else {
            return
        }
        let values = self.values
        let hide = self.kinds.contains(where: { values.hidesOnCapture($0) })
        if hide != self.isApplied {
            self.isApplied = hide
            setLayerDisableScreenshots(layer, hide)
        }
    }
}

/// Hides `layer` (and everything inside it) from screenshots, screen recordings and streams, or
/// shows it again. Calls that would not change anything are skipped.
public func shadowgramSetHiddenFromCapture(_ layer: CALayer, _ hidden: Bool) {
    if getLayerDisableScreenshots(layer) != hidden {
        setLayerDisableScreenshots(layer, hidden)
    }
}

/// Whether the chat with this raw peer id (`PeerId.toInt64()`) is marked Private.
public func shadowgramIsPrivateChat(_ rawPeerId: Int64) -> Bool {
    return ShadowgramSettings.shared.values.privateChatIds.contains(rawPeerId)
}

/// Keeps a set of layers hidden from screen capture while they show a chat marked Private, and
/// follows the mark live (marking a chat in the chat list applies to rows already on screen).
/// `layers` is asked again on every change, so it can return layers created later.
///
/// Create and update on the main thread.
public final class ShadowgramPrivateChatCaptureGuard {
    private let layers: () -> [CALayer]
    private var rawPeerId: Int64?
    private var privateChatIds: Set<Int64>
    private var disposable: Disposable?

    public private(set) var isHidden = false

    public init(layers: @escaping () -> [CALayer]) {
        self.layers = layers
        self.privateChatIds = ShadowgramSettings.shared.values.privateChatIds
        let privateChatIdsSignal: Signal<Set<Int64>, NoError> = ShadowgramSettings.shared.valuesSignal
        |> map { values -> Set<Int64> in
            return values.privateChatIds
        }
        |> distinctUntilChanged
        self.disposable = (privateChatIdsSignal |> deliverOnMainQueue).start(next: { [weak self] privateChatIds in
            guard let self else {
                return
            }
            self.privateChatIds = privateChatIds
            self.apply()
        })
    }

    deinit {
        self.disposable?.dispose()
    }

    /// The chat the layers currently show; nil for anything that is not a chat.
    public func update(rawPeerId: Int64?) {
        self.rawPeerId = rawPeerId
        self.apply()
    }

    /// Re-applies the current state, e.g. after new layers were added.
    public func apply() {
        let hidden = self.rawPeerId.flatMap({ self.privateChatIds.contains($0) }) ?? false
        if hidden == self.isHidden && !hidden {
            return
        }
        self.isHidden = hidden
        for layer in self.layers() {
            shadowgramSetHiddenFromCapture(layer, hidden)
        }
    }
}
