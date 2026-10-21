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

private final class ShadowgramGhostModeArguments {
    let update: ((inout ShadowgramSettingsValues) -> Void) -> Void

    init(update: @escaping ((inout ShadowgramSettingsValues) -> Void) -> Void) {
        self.update = update
    }
}

private enum ShadowgramGhostModeSection: Int32 {
    case switches
}

private enum ShadowgramGhostModeEntry: ItemListNodeEntry {
    case readReceipts(Bool)
    case typing(Bool)
    case onlineStatus(Bool)
    case footer

    var section: ItemListSectionId {
        return ShadowgramGhostModeSection.switches.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .readReceipts:
            return 0
        case .typing:
            return 1
        case .onlineStatus:
            return 2
        case .footer:
            return 3
        }
    }

    static func <(lhs: ShadowgramGhostModeEntry, rhs: ShadowgramGhostModeEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ShadowgramGhostModeArguments
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        switch self {
        case let .readReceipts(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.sendReadReceipts, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.sendReadReceipts = value }
            })
        case let .typing(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.sendTyping, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.sendTyping = value }
            })
        case let .onlineStatus(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.sendOnlineStatus, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.sendOnlineStatus = value }
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.ghostModeFooter), sectionId: self.section)
        }
    }
}

/// The modal opened by the ghost button in the profile.
public func shadowgramGhostModeController(context: AccountContext) -> ViewController {
    var dismissImpl: (() -> Void)?

    let arguments = ShadowgramGhostModeArguments(update: { f in
        ShadowgramSettings.shared.update(f)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        ShadowgramSettings.shared.valuesSignal
    )
    |> map { presentationData, values -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())

        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let closeButton = ItemListNavigationButton(content: .text(strings.close), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.ghostMode), leftNavigationButton: closeButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let entries: [ShadowgramGhostModeEntry] = [
            .readReceipts(values.sendReadReceipts),
            .typing(values.sendTyping),
            .onlineStatus(values.sendOnlineStatus),
            .footer
        ]
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    return controller
}
