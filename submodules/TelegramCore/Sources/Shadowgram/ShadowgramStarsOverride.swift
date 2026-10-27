import Foundation
import Postbox
import SwiftSignalKit
import ShadowgramSettings

/// "Stars Editing": a purely local, per-device display override of the account's Stars
/// balance (never touches the server - nothing is actually credited or debited). `ton`
/// balances are left alone; only the Stars currency is spoofed.
func shadowgramApplyStarsOverride(ton: Bool, peerId: PeerId, state: StarsContext.State) -> StarsContext.State {
    let values = ShadowgramSettings.shared.values
    guard !ton, values.starsEditingEnabled, let override = values.starsOverrides[peerId.toInt64()] else {
        return state
    }
    return StarsContext.State(flags: state.flags, balance: StarsAmount(value: override, nanos: 0), subscriptions: state.subscriptions, canLoadMoreSubscriptions: state.canLoadMoreSubscriptions, transactions: state.transactions, canLoadMoreTransactions: state.canLoadMoreTransactions, isLoading: state.isLoading)
}

/// What the override for `peerId` currently resolves to; the context re-publishes when it changes
/// (the feature switched on or off, or an edit made elsewhere).
func shadowgramStarsOverrideSignal(peerId: PeerId) -> Signal<Int64?, NoError> {
    let key = peerId.toInt64()
    return ShadowgramSettings.shared.valuesSignal
    |> map { values -> Int64? in
        return values.starsEditingEnabled ? values.starsOverrides[key] : nil
    }
    |> distinctUntilChanged
}

public enum ShadowgramStarsOverrideOperation {
    case add(Int64)
    case subtract(Int64)
    case set(Int64)
    case reset
}

/// Applies a Stars Editing operation and republishes the context's state immediately (rather
/// than waiting for the next real balance update) so the Stars screen picks it up at once.
/// `currentDisplayedValue` is whatever the caller currently shows on screen - the basis for a
/// relative add/subtract, matching what the person sees rather than a hidden "real" number.
public func shadowgramApplyStarsOverrideOperation(context: StarsContext, peerId: EnginePeer.Id, currentDisplayedValue: Int64, operation: ShadowgramStarsOverrideOperation) {
    let key = peerId.toInt64()
    ShadowgramSettings.shared.update { values in
        switch operation {
        case let .add(amount):
            values.starsOverrides[key] = max(0, currentDisplayedValue + amount)
        case let .subtract(amount):
            values.starsOverrides[key] = max(0, currentDisplayedValue - amount)
        case let .set(amount):
            values.starsOverrides[key] = max(0, amount)
        case .reset:
            values.starsOverrides.removeValue(forKey: key)
        }
    }
    // A zero-delta "add" re-runs updateState() against the real cached balance, so the
    // published state picks up the override that was just written (or its absence, on reset).
    context.add(balance: StarsAmount(value: 0, nanos: 0), addTransaction: false)
}
