import Foundation
import UIKit
import Display
import AsyncDisplayKit
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

private enum ShadowgramGhostModeEntry: ItemListNodeEntry {
    case readReceipts(Bool)
    case readReceiptsInfo
    case typing(Bool)
    case typingInfo
    case onlineStatus(Bool)
    case onlineStatusInfo
    case storyViews(Bool)
    case storyViewsInfo

    /// Every function is its own section, so its explanation sits right under its switch.
    var section: ItemListSectionId {
        switch self {
        case .readReceipts, .readReceiptsInfo:
            return 0
        case .typing, .typingInfo:
            return 1
        case .onlineStatus, .onlineStatusInfo:
            return 2
        case .storyViews, .storyViewsInfo:
            return 3
        }
    }

    var stableId: Int32 {
        switch self {
        case .readReceipts:
            return 0
        case .readReceiptsInfo:
            return 1
        case .typing:
            return 2
        case .typingInfo:
            return 3
        case .onlineStatus:
            return 4
        case .onlineStatusInfo:
            return 5
        case .storyViews:
            return 6
        case .storyViewsInfo:
            return 7
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
        case .readReceiptsInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.sendReadReceiptsInfo), sectionId: self.section)
        case let .typing(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.sendTyping, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.sendTyping = value }
            })
        case .typingInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.sendTypingInfo), sectionId: self.section)
        case let .onlineStatus(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.sendOnlineStatus, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.sendOnlineStatus = value }
            })
        case .onlineStatusInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.sendOnlineStatusInfo), sectionId: self.section)
        case let .storyViews(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.sendStoryViews, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.sendStoryViews = value }
            })
        case .storyViewsInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain(strings.sendStoryViewsInfo), sectionId: self.section)
        }
    }
}

/// The modal opened by the ghost button in the profile.
public func shadowgramGhostModeController(context: AccountContext) -> ViewController {
    var dismissImpl: (() -> Void)?

    let arguments = ShadowgramGhostModeArguments(update: { f in
        ShadowgramSettings.shared.update(f)
    })

    let powerNode = ASImageNode()
    powerNode.displaysAsynchronously = false
    powerNode.contentMode = .center
    powerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 24.0, height: 24.0))
    var powerColor: UIColor?
    var modalThemeCache: (base: PresentationTheme, modal: PresentationTheme)?

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        ShadowgramSettings.shared.valuesSignal
    )
    |> map { presentationData, values -> (ItemListControllerState, (ItemListNodeState, Any)) in
        // withModalBlocksBackground() returns a new theme object on every call, and ItemListController
        // treats a different theme object as a theme change: it rebuilds (and animates) both navigation
        // buttons. The derived theme is reused for as long as the base theme is the same.
        let modalTheme: PresentationTheme
        if let cached = modalThemeCache, cached.base === presentationData.theme {
            modalTheme = cached.modal
        } else {
            modalTheme = presentationData.theme.withModalBlocksBackground()
            modalThemeCache = (presentationData.theme, modalTheme)
        }
        let presentationData = presentationData.withUpdated(theme: modalTheme)

        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let closeButton = ItemListNavigationButton(content: .text(strings.close), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        // ⏻ flips every function at once: all on if any is off, otherwise all off.
        let accentColor = presentationData.theme.rootController.navigationBar.accentTextColor
        if powerColor != accentColor {
            powerColor = accentColor
            powerNode.image = shadowgramPowerIcon(color: accentColor)
        }
        let powerButton = ItemListNavigationButton(content: .node(powerNode), style: .regular, enabled: true, action: {
            ShadowgramSettings.shared.update { values in
                let allOn = values.sendReadReceipts && values.sendTyping && values.sendOnlineStatus && values.sendStoryViews
                let newValue = !allOn
                values.sendReadReceipts = newValue
                values.sendTyping = newValue
                values.sendOnlineStatus = newValue
                values.sendStoryViews = newValue
            }
        })
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.ghostMode), leftNavigationButton: closeButton, rightNavigationButton: powerButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let entries: [ShadowgramGhostModeEntry] = [
            .readReceipts(values.sendReadReceipts),
            .readReceiptsInfo,
            .typing(values.sendTyping),
            .typingInfo,
            .onlineStatus(values.sendOnlineStatus),
            .onlineStatusInfo,
            .storyViews(values.sendStoryViews),
            .storyViewsInfo
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
