import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import AccountContext
import ShadowgramSettings
import UndoUI

/// "Gift Editing" - the "removed gifts" screen the arrow button opens: every real gift hidden
/// locally from this profile (via the minus button in edit mode), each restorable.

private struct ShadowgramRemovedGiftEntry: ItemListNodeEntry {
    let index: Int
    let gift: ProfileGiftsContext.State.StarGift
    let restore: (Int) -> Void

    var section: ItemListSectionId { return 0 }
    var stableId: Int { return self.index }

    static func ==(lhs: ShadowgramRemovedGiftEntry, rhs: ShadowgramRemovedGiftEntry) -> Bool {
        return lhs.index == rhs.index
    }

    static func <(lhs: ShadowgramRemovedGiftEntry, rhs: ShadowgramRemovedGiftEntry) -> Bool {
        return lhs.index < rhs.index
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        var title = ""
        switch self.gift.gift {
        case let .generic(generic):
            title = generic.title ?? "Gift"
        case let .unique(unique):
            title = unique.title
        }
        if let number = self.gift.number {
            title += " #\(number)"
        }
        return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: strings.shadowgramGiftEditingRestore, sectionId: self.section, style: .blocks, action: { [index = self.index, restore = self.restore] in
            restore(index)
        })
    }
}

public func shadowgramPresentRemovedGiftsScreen(context: AccountContext, peerId: EnginePeer.Id, present: @escaping (ViewController) -> Void) {
    let changeTick = ValuePromise<Int>(0, ignoreRepeated: false)

    weak var weakController: ItemListController?

    let signal: Signal<(ItemListControllerState, (ItemListNodeState, Any)), NoError> = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        changeTick.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let removed = shadowgramRemovedGifts(peerId: peerId)

        var entries: [ShadowgramRemovedGiftEntry] = []
        for (index, gift) in removed {
            entries.append(ShadowgramRemovedGiftEntry(index: index, gift: gift, restore: { index in
                shadowgramRestoreRemovedGift(peerId: peerId, index: index)
                changeTick.set(0)
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
                weakController?.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: strings.shadowgramGiftRestored, timeout: nil, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
            }))
        }

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.shadowgramGiftEditingRemovedGifts), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let emptyStateItem: ItemListControllerEmptyStateItem? = entries.isEmpty ? ItemListTextEmptyStateItem(text: strings.shadowgramGiftEditingRemovedGiftsEmpty) : nil
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: emptyStateItem, animateChanges: true)
        return (controllerState, (listState, 0 as Any))
    }

    let controller = ItemListController(context: context, state: signal)
    weakController = controller
    present(controller)
}
