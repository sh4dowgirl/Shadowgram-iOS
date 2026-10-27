import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import ShadowgramSettings

private final class ShadowgramStarsEditingArguments {
    let updateAmount: (String) -> Void
    let apply: (ShadowgramStarsEditingOperationKind) -> Void
    let reset: () -> Void

    init(updateAmount: @escaping (String) -> Void, apply: @escaping (ShadowgramStarsEditingOperationKind) -> Void, reset: @escaping () -> Void) {
        self.updateAmount = updateAmount
        self.apply = apply
        self.reset = reset
    }
}

private enum ShadowgramStarsEditingOperationKind: Int32 {
    case add
    case subtract
    case set
}

private enum ShadowgramStarsEditingEntry: ItemListNodeEntry {
    case currentHeader(String)
    case current(String, String)
    case amountHeader(String)
    case amount(String, String)
    case operation(ShadowgramStarsEditingOperationKind, String, Bool)
    case reset(String, Bool)
    case footer(String)

    var section: ItemListSectionId {
        switch self {
        case .currentHeader, .current:
            return 0
        case .amountHeader, .amount, .operation:
            return 1
        case .reset, .footer:
            return 2
        }
    }

    var stableId: Int32 {
        switch self {
        case .currentHeader:
            return 0
        case .current:
            return 1
        case .amountHeader:
            return 2
        case .amount:
            return 3
        case let .operation(kind, _, _):
            return 4 + kind.rawValue
        case .reset:
            return 10
        case .footer:
            return 11
        }
    }

    static func <(lhs: ShadowgramStarsEditingEntry, rhs: ShadowgramStarsEditingEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ShadowgramStarsEditingArguments
        switch self {
        case let .currentHeader(text), let .amountHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .current(value, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: value, titleFont: .bold, label: label, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .amount(text, placeholder):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: text, placeholder: placeholder, type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateAmount(value)
            }, action: {})
        case let .operation(kind, title, enabled):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.apply(kind)
            })
        case let .reset(title, enabled):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: enabled ? .destructive : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.reset()
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

/// "Stars Editing": the editor the Stars screen's pencil opens. It changes only what this device
/// shows (`ShadowgramSettingsValues.starsOverrides`); nothing reaches the server.
public func shadowgramStarsEditingController(context: AccountContext) -> ViewController? {
    guard let starsContext = context.starsContext, !starsContext.ton else {
        return nil
    }
    let peerId = context.account.peerId
    let amountValue = ValuePromise<String>("", ignoreRepeated: true)
    let amountState = Atomic<String>(value: "")

    let displayedBalance = starsContext.state
    |> map { state -> Int64 in
        return state?.balance.value ?? 0
    }
    let currentBalance = Atomic<Int64>(value: 0)

    weak var weakController: ViewController?

    let arguments = ShadowgramStarsEditingArguments(updateAmount: { text in
        let digits = text.filter { $0.isNumber }
        let _ = amountState.swap(digits)
        amountValue.set(digits)
    }, apply: { kind in
        guard let amount = Int64(amountState.with { $0 }) else {
            return
        }
        let operation: ShadowgramStarsOverrideOperation
        switch kind {
        case .add:
            operation = .add(amount)
        case .subtract:
            operation = .subtract(amount)
        case .set:
            operation = .set(amount)
        }
        weakController?.view.endEditing(true)
        shadowgramApplyStarsOverrideOperation(context: starsContext, peerId: peerId, currentDisplayedValue: currentBalance.with { $0 }, operation: operation)
        let _ = amountState.swap("")
        amountValue.set("")
    }, reset: {
        weakController?.view.endEditing(true)
        shadowgramApplyStarsOverrideOperation(context: starsContext, peerId: peerId, currentDisplayedValue: currentBalance.with { $0 }, operation: .reset)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        displayedBalance,
        amountValue.get(),
        ShadowgramSettings.shared.valuesSignal
    )
    |> map { presentationData, balance, amount, values -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let _ = currentBalance.swap(balance)
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let isOverridden = values.starsOverrides[peerId.toInt64()] != nil
        let hasAmount = Int64(amount) != nil
        let formattedBalance = presentationStringsFormattedNumber(Int32(clamping: balance), presentationData.dateTimeFormat.groupingSeparator)

        var entries: [ShadowgramStarsEditingEntry] = []
        entries.append(.currentHeader(strings.starsEditingCurrentHeader))
        entries.append(.current("⭐️ \(formattedBalance)", isOverridden ? strings.starsEditingOverridden : strings.starsEditingReal))
        entries.append(.amountHeader(strings.starsEditingAmountHeader))
        entries.append(.amount(amount, strings.starsEditingAmountPlaceholder))
        entries.append(.operation(.add, strings.starsEditingAdd, hasAmount))
        entries.append(.operation(.subtract, strings.starsEditingSubtract, hasAmount))
        entries.append(.operation(.set, strings.starsEditingSet, hasAmount))
        entries.append(.reset(strings.starsEditingReset, isOverridden))
        entries.append(.footer(strings.starsEditingFooterNote))

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.starsEditingTitle), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    weakController = controller
    return controller
}
