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

/// "Gift Editing" - the "+" screen. Builds a fabricated `ProfileGiftsContext.State.StarGift`
/// entirely client-side (nothing is ever sent to the server) and adds it to the local overlay,
/// where `shadowgramOverlayGifts` picks it up for display the same way a real one renders.
/// Every field here is optional, matching the person's own spec for the editor.

private final class ShadowgramGiftEditorState {
    var base: StarGift.Gift?
    var isUnique: Bool = false
    var number: String = ""
    var text: String = ""
    var senderName: String = ""
    var dateString: String = ""
    var convertible: Bool = false
}

private final class ShadowgramGiftEditorArguments {
    let pickBase: () -> Void
    let update: (_ f: (ShadowgramGiftEditorState) -> Void) -> Void
    let save: () -> Void

    init(pickBase: @escaping () -> Void, update: @escaping (_ f: (ShadowgramGiftEditorState) -> Void) -> Void, save: @escaping () -> Void) {
        self.pickBase = pickBase
        self.update = update
        self.save = save
    }
}

private enum ShadowgramGiftEditorEntry: ItemListNodeEntry {
    case baseHeader
    case base(String)
    case detailsHeader
    case number(String)
    case text(String)
    case senderName(String)
    case date(String)
    case detailsFooter
    case unique(Bool)
    case uniqueFooter
    case convertible(Bool)
    case convertibleFooter
    case save

    var section: ItemListSectionId {
        switch self {
        case .baseHeader, .base:
            return 0
        case .detailsHeader, .number, .text, .senderName, .date, .detailsFooter:
            return 1
        case .unique, .uniqueFooter:
            return 2
        case .convertible, .convertibleFooter:
            return 3
        case .save:
            return 4
        }
    }

    var stableId: Int32 {
        switch self {
        case .baseHeader: return 0
        case .base: return 1
        case .detailsHeader: return 2
        case .number: return 3
        case .text: return 4
        case .senderName: return 5
        case .date: return 6
        case .detailsFooter: return 7
        case .unique: return 8
        case .uniqueFooter: return 9
        case .convertible: return 10
        case .convertibleFooter: return 11
        case .save: return 12
        }
    }

    static func <(lhs: ShadowgramGiftEditorEntry, rhs: ShadowgramGiftEditorEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ShadowgramGiftEditorArguments
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        switch self {
        case .baseHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: strings.shadowgramGiftEditingPickBase, sectionId: self.section)
        case let .base(title):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: strings.shadowgramGiftEditingPickBase, label: title, sectionId: self.section, style: .blocks, action: {
                arguments.pickBase()
            })
        case .detailsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: " ", sectionId: self.section)
        case let .number(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: ""), text: value, placeholder: strings.shadowgramGiftEditingNumber, type: .number, sectionId: self.section, textUpdated: { value in
                arguments.update { $0.number = value }
            }, action: {})
        case let .text(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: ""), text: value, placeholder: strings.shadowgramGiftEditingText, sectionId: self.section, textUpdated: { value in
                arguments.update { $0.text = value }
            }, action: {})
        case let .senderName(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: ""), text: value, placeholder: strings.shadowgramGiftEditingSender, sectionId: self.section, textUpdated: { value in
                arguments.update { $0.senderName = value }
            }, action: {})
        case let .date(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: ""), text: value, placeholder: strings.shadowgramGiftEditingDate, sectionId: self.section, textUpdated: { value in
                arguments.update { $0.dateString = value }
            }, action: {})
        case .detailsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(" "), sectionId: self.section)
        case let .unique(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.shadowgramGiftEditingMakeUnique, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.isUnique = value }
            })
        case .uniqueFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(" "), sectionId: self.section)
        case let .convertible(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: strings.shadowgramGiftEditingUpgraded, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.convertible = value }
            })
        case .convertibleFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(" "), sectionId: self.section)
        case .save:
            return ItemListActionItem(presentationData: presentationData, title: strings.shadowgramGiftEditingSave, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.save()
            })
        }
    }
}

private func shadowgramGiftEditorEntries(state: ShadowgramGiftEditorState, strings: ShadowgramStrings) -> [ShadowgramGiftEditorEntry] {
    var entries: [ShadowgramGiftEditorEntry] = []
    entries.append(.baseHeader)
    entries.append(.base(state.base?.title ?? "—"))
    entries.append(.detailsHeader)
    entries.append(.number(state.number))
    entries.append(.text(state.text))
    entries.append(.senderName(state.senderName))
    entries.append(.date(state.dateString))
    entries.append(.detailsFooter)
    entries.append(.unique(state.isUnique))
    entries.append(.uniqueFooter)
    entries.append(.convertible(state.convertible))
    entries.append(.convertibleFooter)
    entries.append(.save)
    return entries
}

/// Dates typed as `YYYY-MM-DD`; anything else (including empty) falls back to now.
private func shadowgramParseDate(_ string: String) -> Int32 {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return Int32(Date().timeIntervalSince1970)
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    if let date = formatter.date(from: trimmed) {
        return Int32(date.timeIntervalSince1970)
    }
    return Int32(Date().timeIntervalSince1970)
}

private func shadowgramBuildGift(state: ShadowgramGiftEditorState) -> ProfileGiftsContext.State.StarGift? {
    guard let base = state.base else {
        return nil
    }
    let number = Int32(state.number.trimmingCharacters(in: .whitespacesAndNewlines))
    let date = shadowgramParseDate(state.dateString)
    let text = state.text.trimmingCharacters(in: .whitespacesAndNewlines)
    let senderName = state.senderName.trimmingCharacters(in: .whitespacesAndNewlines)

    let gift: TelegramCore.StarGift
    if state.isUnique {
        var attributes: [StarGift.UniqueGift.Attribute] = []
        attributes.append(.model(name: base.title ?? "Model", file: base.file, rarity: .rare, crafted: false))
        // A pleasant, fixed backdrop rather than a real catalog lookup - good enough to render
        // correctly without needing the attribute-catalog network calls a real upgrade uses.
        attributes.append(.backdrop(name: "Custom", id: 0, innerColor: 0x8C7BEF, outerColor: 0xAEB3F8, patternColor: 0xFFFFFF, textColor: 0xFFFFFF, rarity: .rare))
        let unique = StarGift.UniqueGift(
            id: Int64.random(in: 1 ... Int64.max),
            giftId: base.id,
            title: base.title ?? "Gift",
            number: number ?? Int32.random(in: 1 ... 9999),
            slug: "shadowgram-\(Int64.random(in: 1 ... Int64.max))",
            owner: senderName.isEmpty ? nil : .name(senderName),
            attributes: attributes,
            availability: StarGift.UniqueGift.Availability(issued: 1, total: 1),
            giftAddress: nil,
            resellAmounts: nil,
            resellForTonOnly: false,
            releasedBy: nil,
            valueAmount: nil,
            valueCurrency: nil,
            valueUsdAmount: nil,
            flags: [],
            themePeerId: nil,
            peerColor: nil,
            hostPeerId: nil,
            minOfferStars: nil,
            craftChancePermille: nil
        )
        gift = .unique(unique)
    } else {
        gift = .generic(base)
    }

    return ProfileGiftsContext.State.StarGift(
        gift: gift,
        reference: nil,
        fromPeer: nil,
        date: date,
        text: text.isEmpty ? nil : text,
        entities: nil,
        nameHidden: false,
        savedToProfile: true,
        pinnedToTop: false,
        convertStars: state.convertible ? max(1, base.convertStars) : nil,
        canUpgrade: false,
        canExportDate: nil,
        upgradeStars: nil,
        transferStars: nil,
        canTransferDate: nil,
        canResaleDate: nil,
        collectionIds: nil,
        prepaidUpgradeHash: nil,
        upgradeSeparate: false,
        dropOriginalDetailsStars: nil,
        number: number,
        isRefunded: false,
        canCraftAt: nil
    )
}

private struct ShadowgramGiftBasePickerEntry: ItemListNodeEntry {
    let index: Int
    let gift: StarGift.Gift
    let action: (StarGift.Gift) -> Void

    var section: ItemListSectionId { return 0 }
    var stableId: Int { return self.index }

    // `action` is a closure (not Equatable), so synthesis can't provide `==` - only `index`
    // (this entry's whole identity) needs to be compared.
    static func ==(lhs: ShadowgramGiftBasePickerEntry, rhs: ShadowgramGiftBasePickerEntry) -> Bool {
        return lhs.index == rhs.index
    }

    static func <(lhs: ShadowgramGiftBasePickerEntry, rhs: ShadowgramGiftBasePickerEntry) -> Bool {
        return lhs.index < rhs.index
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: self.gift.title ?? "Gift #\(self.gift.id)", label: "", sectionId: self.section, style: .blocks, action: { [gift = self.gift, action = self.action] in
            action(gift)
        })
    }
}

/// `onPick` fires on the main queue and is responsible for dismissing `controller` itself -
/// the picker only dismisses its own pushed screen.
private func shadowgramPresentGiftBasePicker(context: AccountContext, controller: ItemListController, onPick: @escaping (StarGift.Gift) -> Void) {
    var pickImpl: ((StarGift.Gift) -> Void)?

    let signal: Signal<[StarGift], NoError> = context.engine.payments.cachedStarGifts() |> map { $0 ?? [] }

    let itemsSignal: Signal<(ItemListControllerState, (ItemListNodeState, Any)), NoError> = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, signal)
    |> map { presentationData, gifts -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [ShadowgramGiftBasePickerEntry] = []
        var index = 0
        for gift in gifts {
            if case let .generic(generic) = gift {
                entries.append(ShadowgramGiftBasePickerEntry(index: index, gift: generic, action: { gift in
                    pickImpl?(gift)
                }))
                index += 1
            }
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Settings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, 0 as Any))
    }

    let pickerController = ItemListController(context: context, state: itemsSignal)
    pickImpl = { [weak pickerController] gift in
        pickerController?.dismiss()
        onPick(gift)
    }
    controller.push(pickerController)
}

public func shadowgramPresentGiftEditorScreen(context: AccountContext, peerId: EnginePeer.Id, present: @escaping (ViewController) -> Void) {
    let state = ShadowgramGiftEditorState()
    let statePromise = ValuePromise<Int>(0, ignoreRepeated: false)

    weak var weakController: ItemListController?

    let arguments = ShadowgramGiftEditorArguments(pickBase: {
        guard let controller = weakController else {
            return
        }
        shadowgramPresentGiftBasePicker(context: context, controller: controller, onPick: { gift in
            state.base = gift
            statePromise.set(0)
        })
    }, update: { f in
        f(state)
        statePromise.set(0)
    }, save: {
        guard let gift = shadowgramBuildGift(state: state) else {
            return
        }
        shadowgramAddEditedGift(peerId: peerId, gift: gift)
        weakController?.dismiss()
    })

    let signal: Signal<(ItemListControllerState, (ItemListNodeState, Any)), NoError> = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.shadowgramGiftEditingAddTitle), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: shadowgramGiftEditorEntries(state: state, strings: strings), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    weakController = controller
    present(controller)
}
