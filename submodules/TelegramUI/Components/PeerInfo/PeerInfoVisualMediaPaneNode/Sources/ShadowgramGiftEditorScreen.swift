import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import ItemListDatePickerItem
import AccountContext
import GiftItemComponent
import GiftViewScreen
import LocalizedPeerData
import ShadowgramSettings

/// "Gift Editing" - the "+" screen. Builds a `ProfileGiftsContext.State.StarGift` entirely on this
/// device (nothing is sent to the server) and adds it to the local overlay, where the profile grid
/// and the gift's own screen show it like a real one.

private struct ShadowgramGiftEditorState: Equatable {
    var base: StarGift.Gift?
    var isUnique: Bool = false
    var model: StarGift.UniqueGift.Attribute?
    var backdrop: StarGift.UniqueGift.Attribute?
    var pattern: StarGift.UniqueGift.Attribute?
    var number: String = ""
    var sender: EnginePeer?
    var hideSenderName: Bool = false
    var text: String = ""
    var date: Int32 = Int32(Date().timeIntervalSince1970)
    var isEditingDate: Bool = false
    var pinned: Bool = false
    var canConvert: Bool = false
    var canUpgrade: Bool = false
}

private enum ShadowgramGiftAttributeKind {
    case model
    case backdrop
    case pattern
}

private final class ShadowgramGiftEditorArguments {
    let pickBase: () -> Void
    let pickAttribute: (ShadowgramGiftAttributeKind) -> Void
    let pickSender: () -> Void
    let clearSender: () -> Void
    let update: (@escaping (inout ShadowgramGiftEditorState) -> Void) -> Void
    let preview: () -> Void
    let save: () -> Void

    init(pickBase: @escaping () -> Void, pickAttribute: @escaping (ShadowgramGiftAttributeKind) -> Void, pickSender: @escaping () -> Void, clearSender: @escaping () -> Void, update: @escaping (@escaping (inout ShadowgramGiftEditorState) -> Void) -> Void, preview: @escaping () -> Void, save: @escaping () -> Void) {
        self.pickBase = pickBase
        self.pickAttribute = pickAttribute
        self.pickSender = pickSender
        self.clearSender = clearSender
        self.update = update
        self.preview = preview
        self.save = save
    }
}

private enum ShadowgramGiftEditorSection: Int32 {
    case gift
    case nft
    case sender
    case message
    case options
    case actions
}

private enum ShadowgramGiftEditorEntry: ItemListNodeEntry {
    case giftHeader(String)
    case gift(String, String)
    case giftFooter(String)
    case unique(String, Bool)
    case model(String, String)
    case backdrop(String, String)
    case pattern(String, String)
    case number(String, String)
    case nftFooter(String)
    case senderHeader(String)
    case sender(String, String)
    case clearSender(String)
    case hideSenderName(String, Bool)
    case messageHeader(String)
    case text(String, String)
    case date(PresentationDateTimeFormat, String, Int32, Bool)
    case optionsHeader(String)
    case pinned(String, Bool)
    case canConvert(String, Bool)
    case canUpgrade(String, Bool)
    case preview(String, Bool)
    case save(String, Bool)

    var section: ItemListSectionId {
        switch self {
        case .giftHeader, .gift, .giftFooter:
            return ShadowgramGiftEditorSection.gift.rawValue
        case .unique, .model, .backdrop, .pattern, .number, .nftFooter:
            return ShadowgramGiftEditorSection.nft.rawValue
        case .senderHeader, .sender, .clearSender, .hideSenderName:
            return ShadowgramGiftEditorSection.sender.rawValue
        case .messageHeader, .text, .date:
            return ShadowgramGiftEditorSection.message.rawValue
        case .optionsHeader, .pinned, .canConvert, .canUpgrade:
            return ShadowgramGiftEditorSection.options.rawValue
        case .preview, .save:
            return ShadowgramGiftEditorSection.actions.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .giftHeader: return 0
        case .gift: return 1
        case .giftFooter: return 2
        case .unique: return 10
        case .model: return 11
        case .backdrop: return 12
        case .pattern: return 13
        case .number: return 14
        case .nftFooter: return 15
        case .senderHeader: return 20
        case .sender: return 21
        case .clearSender: return 22
        case .hideSenderName: return 23
        case .messageHeader: return 30
        case .text: return 31
        case .date: return 32
        case .optionsHeader: return 40
        case .pinned: return 41
        case .canConvert: return 42
        case .canUpgrade: return 43
        case .preview: return 50
        case .save: return 51
        }
    }

    static func <(lhs: ShadowgramGiftEditorEntry, rhs: ShadowgramGiftEditorEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ShadowgramGiftEditorArguments
        switch self {
        case let .giftHeader(text), let .senderHeader(text), let .messageHeader(text), let .optionsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .giftFooter(text), let .nftFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .gift(title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.pickBase()
            })
        case let .unique(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.isUnique = value }
            })
        case let .model(title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.pickAttribute(.model)
            })
        case let .backdrop(title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.pickAttribute(.backdrop)
            })
        case let .pattern(title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.pickAttribute(.pattern)
            })
        case let .number(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "#"), text: value, placeholder: placeholder, type: .number, sectionId: self.section, textUpdated: { value in
                arguments.update { $0.number = value.filter { $0.isNumber } }
            }, action: {})
        case let .sender(title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.pickSender()
            })
        case let .clearSender(title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearSender()
            })
        case let .hideSenderName(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.hideSenderName = value }
            })
        case let .text(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, sectionId: self.section, textUpdated: { value in
                arguments.update { $0.text = value }
            }, action: {})
        case let .date(dateTimeFormat, title, date, isEditing):
            return ItemListDatePickerItem(presentationData: presentationData, systemStyle: .glass, dateTimeFormat: dateTimeFormat, date: date, maxDate: Int32(Date().timeIntervalSince1970), title: title, displayingDateSelection: isEditing, displayingTimeSelection: false, sectionId: self.section, style: .blocks, toggleDateSelection: {
                arguments.update { $0.isEditingDate = !$0.isEditingDate }
            }, toggleTimeSelection: nil, updated: { date in
                arguments.update { $0.date = date }
            })
        case let .pinned(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.pinned = value }
            })
        case let .canConvert(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.canConvert = value }
            })
        case let .canUpgrade(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update { $0.canUpgrade = value }
            })
        case let .preview(title, enabled):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: enabled ? .generic : .disabled, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.preview()
            })
        case let .save(title, enabled):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: enabled ? .generic : .disabled, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.save()
            })
        }
    }
}

private func shadowgramAttributeName(_ attribute: StarGift.UniqueGift.Attribute?) -> String {
    guard let attribute else {
        return ""
    }
    switch attribute {
    case let .model(name, _, _, _), let .pattern(name, _, _), let .backdrop(name, _, _, _, _, _, _):
        return name
    case .originalInfo:
        return ""
    }
}

private func shadowgramGiftEditorEntries(state: ShadowgramGiftEditorState, strings: ShadowgramStrings, presentationData: PresentationData) -> [ShadowgramGiftEditorEntry] {
    var entries: [ShadowgramGiftEditorEntry] = []
    let hasBase = state.base != nil

    entries.append(.giftHeader(strings.shadowgramGiftEditingGiftHeader))
    entries.append(.gift(strings.shadowgramGiftEditingPickBase, state.base?.title ?? strings.shadowgramGiftEditingNotChosen))
    if !hasBase {
        entries.append(.giftFooter(strings.shadowgramGiftEditingGiftFooter))
    }

    if hasBase {
        entries.append(.unique(strings.shadowgramGiftEditingMakeUnique, state.isUnique))
        if state.isUnique {
            entries.append(.model(strings.shadowgramGiftEditingModel, shadowgramAttributeName(state.model)))
            entries.append(.backdrop(strings.shadowgramGiftEditingBackdrop, shadowgramAttributeName(state.backdrop)))
            entries.append(.pattern(strings.shadowgramGiftEditingPattern, shadowgramAttributeName(state.pattern)))
            entries.append(.number(strings.shadowgramGiftEditingNumberPlaceholder, state.number))
        }
        entries.append(.nftFooter(state.isUnique ? strings.shadowgramGiftEditingNftFooter : strings.shadowgramGiftEditingRegularFooter))

        entries.append(.senderHeader(strings.shadowgramGiftEditingSenderHeader))
        entries.append(.sender(strings.shadowgramGiftEditingSender, state.sender.flatMap { $0.compactDisplayTitle } ?? strings.shadowgramGiftEditingSenderNone))
        if state.sender != nil {
            entries.append(.clearSender(strings.shadowgramGiftEditingSenderClear))
            entries.append(.hideSenderName(strings.shadowgramGiftEditingHideSender, state.hideSenderName))
        }

        entries.append(.messageHeader(strings.shadowgramGiftEditingMessageHeader))
        entries.append(.text(strings.shadowgramGiftEditingText, state.text))
        entries.append(.date(presentationData.dateTimeFormat, strings.shadowgramGiftEditingDate, state.date, state.isEditingDate))

        entries.append(.optionsHeader(strings.shadowgramGiftEditingOptionsHeader))
        entries.append(.pinned(strings.shadowgramGiftEditingPinned, state.pinned))
        if !state.isUnique {
            entries.append(.canConvert(strings.shadowgramGiftEditingUpgraded, state.canConvert))
            entries.append(.canUpgrade(strings.shadowgramGiftEditingCanUpgrade, state.canUpgrade))
        }
    }

    entries.append(.preview(strings.shadowgramGiftEditingPreview, hasBase))
    entries.append(.save(strings.shadowgramGiftEditingSave, hasBase))
    return entries
}

/// A backdrop for a collection whose catalog could not be loaded.
private let shadowgramFallbackBackdrop: StarGift.UniqueGift.Attribute = .backdrop(name: "Amethyst", id: 0, innerColor: 0x8C7BEF, outerColor: 0x6E5DD9, patternColor: 0x4B3DAA, textColor: 0xFFFFFF, rarity: .permille(20))

private func shadowgramUniqueAttributes(state: ShadowgramGiftEditorState, base: StarGift.Gift) -> [StarGift.UniqueGift.Attribute] {
    var attributes: [StarGift.UniqueGift.Attribute] = []
    attributes.append(state.model ?? .model(name: base.title ?? "Gift", file: base.file, rarity: .permille(20), crafted: false))
    if let pattern = state.pattern {
        attributes.append(pattern)
    }
    attributes.append(state.backdrop ?? shadowgramFallbackBackdrop)
    return attributes
}

private func shadowgramBuildGift(state: ShadowgramGiftEditorState, peerId: EnginePeer.Id) -> ProfileGiftsContext.State.StarGift? {
    guard let base = state.base else {
        return nil
    }
    let number = Int32(state.number)
    let text = state.text.trimmingCharacters(in: .whitespacesAndNewlines)

    let gift: TelegramCore.StarGift
    var giftNumber: Int32?
    if state.isUnique {
        let total = base.availability?.total ?? 100000
        let resolvedNumber = number ?? Int32.random(in: 1 ... max(1, total))
        giftNumber = resolvedNumber
        let unique = StarGift.UniqueGift(
            id: Int64.random(in: 1 ... Int64.max),
            giftId: base.id,
            title: base.title ?? "Gift",
            number: resolvedNumber,
            slug: "\((base.title ?? "Gift").replacingOccurrences(of: " ", with: ""))-\(resolvedNumber)",
            owner: .peerId(peerId),
            attributes: shadowgramUniqueAttributes(state: state, base: base),
            availability: StarGift.UniqueGift.Availability(issued: max(resolvedNumber, total), total: max(resolvedNumber, total)),
            giftAddress: nil,
            resellAmounts: nil,
            resellForTonOnly: false,
            releasedBy: base.releasedBy,
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
        reference: shadowgramMakeLocalGiftReference(peerId: peerId),
        fromPeer: state.sender,
        date: state.date,
        text: text.isEmpty ? nil : text,
        entities: nil,
        nameHidden: state.sender != nil && state.hideSenderName,
        savedToProfile: true,
        pinnedToTop: state.pinned,
        convertStars: !state.isUnique && state.canConvert ? max(1, base.convertStars) : nil,
        canUpgrade: !state.isUnique && state.canUpgrade,
        canExportDate: nil,
        upgradeStars: !state.isUnique && state.canUpgrade ? base.upgradeStars : nil,
        transferStars: nil,
        canTransferDate: nil,
        canResaleDate: nil,
        collectionIds: nil,
        prepaidUpgradeHash: nil,
        upgradeSeparate: false,
        dropOriginalDetailsStars: nil,
        number: giftNumber,
        isRefunded: false,
        canCraftAt: nil
    )
}

/// The models, backdrops and patterns of one collection: the resale market's full list (the same
/// read-only request the gift store makes), else the upgrade preview's samples.
private final class ShadowgramGiftAttributeCatalog {
    let attributes = Promise<[StarGift.UniqueGift.Attribute]?>(nil)
    private var resaleContext: ResaleGiftsContext?
    private let disposable = MetaDisposable()

    func load(context: AccountContext, giftId: Int64) {
        let resaleContext = ResaleGiftsContext(account: context.account, giftId: giftId, forCrafting: false)
        self.resaleContext = resaleContext
        self.attributes.set(.single(nil))
        let resale: Signal<[StarGift.UniqueGift.Attribute]?, NoError> = resaleContext.state
        |> filter { state in
            if !state.attributes.isEmpty {
                return true
            }
            if case .ready = state.dataState {
                return true
            }
            return false
        }
        |> take(1)
        |> map { state -> [StarGift.UniqueGift.Attribute]? in
            return state.attributes
        }
        let signal: Signal<[StarGift.UniqueGift.Attribute]?, NoError> = resale
        |> mapToSignal { attributes -> Signal<[StarGift.UniqueGift.Attribute]?, NoError> in
            if let attributes, !attributes.isEmpty {
                return .single(attributes)
            }
            return context.engine.payments.starGiftUpgradePreview(giftId: giftId)
            |> map { preview -> [StarGift.UniqueGift.Attribute]? in
                return preview?.attributes ?? []
            }
        }
        self.disposable.set(signal.start(next: { [weak self] attributes in
            self?.attributes.set(.single(attributes))
        }))
    }

    deinit {
        self.disposable.dispose()
    }
}

private func shadowgramRarityText(_ rarity: StarGift.UniqueGift.Attribute.Rarity) -> String? {
    switch rarity {
    case let .permille(value):
        return String(format: "%0.1f", Float(value) / 10.0).replacingOccurrences(of: ".0", with: "") + "%"
    default:
        return nil
    }
}

private func shadowgramAttributeRarity(_ attribute: StarGift.UniqueGift.Attribute) -> StarGift.UniqueGift.Attribute.Rarity? {
    switch attribute {
    case let .model(_, _, rarity, _), let .pattern(_, _, rarity), let .backdrop(_, _, _, _, _, _, rarity):
        return rarity
    case .originalInfo:
        return nil
    }
}

private func shadowgramAttributeId(_ attribute: StarGift.UniqueGift.Attribute) -> String {
    switch attribute {
    case let .model(name, file, _, _):
        return "m_\(file.fileId.id)_\(name)"
    case let .pattern(name, file, _):
        return "p_\(file.fileId.id)_\(name)"
    case let .backdrop(_, id, _, _, _, _, _):
        return "b_\(id)"
    case .originalInfo:
        return "o"
    }
}

public func shadowgramPresentGiftEditorScreen(context: AccountContext, peerId: EnginePeer.Id, present: @escaping (ViewController) -> Void) {
    let initialState = ShadowgramGiftEditorState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((inout ShadowgramGiftEditorState) -> Void) -> Void = { f in
        statePromise.set(stateValue.modify { state in
            var state = state
            f(&state)
            return state
        })
    }
    let catalog = ShadowgramGiftAttributeCatalog()
    let catalogDisposable = MetaDisposable()

    weak var weakController: ItemListController?

    // A collection's catalog arrives once per chosen gift; the first of each kind becomes the default.
    func loadCatalog(giftId: Int64) {
        catalog.load(context: context, giftId: giftId)
        catalogDisposable.set((catalog.attributes.get()
        |> filter { $0 != nil }
        |> take(1)
        |> deliverOnMainQueue).start(next: { attributes in
            guard let attributes else {
                return
            }
            updateState { state in
                guard state.base?.id == giftId else {
                    return
                }
                if state.model == nil {
                    state.model = attributes.first(where: { $0.attributeType == .model })
                }
                if state.backdrop == nil {
                    state.backdrop = attributes.first(where: { $0.attributeType == .backdrop })
                }
                if state.pattern == nil {
                    state.pattern = attributes.first(where: { $0.attributeType == .pattern })
                }
            }
        }))
    }

    let arguments = ShadowgramGiftEditorArguments(pickBase: {
        guard let controller = weakController else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let selectedId = stateValue.with { $0.base?.id }
        let items: Signal<[ShadowgramGiftGridItem]?, NoError> = context.engine.payments.cachedStarGifts()
        |> map { gifts -> [ShadowgramGiftGridItem]? in
            guard let gifts else {
                return nil
            }
            var result: [ShadowgramGiftGridItem] = []
            for gift in gifts {
                guard case let .generic(generic) = gift else {
                    continue
                }
                var ribbon: GiftItemComponent.Ribbon?
                if let availability = generic.availability {
                    ribbon = GiftItemComponent.Ribbon(text: presentationData.strings.PeerInfo_Gifts_OneOf(compactNumericCountString(Int(availability.total), decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)).string, color: .blue)
                }
                result.append(ShadowgramGiftGridItem(id: "\(generic.id)", subject: .starGift(gift: generic, price: "# \(generic.price)"), ribbon: ribbon, isSelected: generic.id == selectedId))
            }
            return result
        }
        let picker = ShadowgramGiftGridController(context: context, title: strings.shadowgramGiftEditingPickBase, style: .catalog, emptyText: strings.shadowgramGiftEditingCatalogEmpty, items: items, selected: { picker, item in
            let _ = (context.engine.payments.cachedStarGifts()
            |> take(1)
            |> deliverOnMainQueue).start(next: { gifts in
                guard let gifts else {
                    return
                }
                for gift in gifts {
                    if case let .generic(generic) = gift, "\(generic.id)" == item.id {
                        updateState { state in
                            if state.base?.id != generic.id {
                                state.base = generic
                                state.model = nil
                                state.backdrop = nil
                                state.pattern = nil
                            }
                        }
                        loadCatalog(giftId: generic.id)
                        break
                    }
                }
                picker.dismiss()
            })
        })
        controller.push(picker)
    }, pickAttribute: { kind in
        guard let controller = weakController, let base = stateValue.with({ $0.base }) else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let title: String
        switch kind {
        case .model:
            title = strings.shadowgramGiftEditingModel
        case .backdrop:
            title = strings.shadowgramGiftEditingBackdrop
        case .pattern:
            title = strings.shadowgramGiftEditingPattern
        }
        let items: Signal<[ShadowgramGiftGridItem]?, NoError> = combineLatest(catalog.attributes.get(), statePromise.get())
        |> map { attributes, state -> [ShadowgramGiftGridItem]? in
            guard let attributes else {
                return nil
            }
            var result: [ShadowgramGiftGridItem] = []
            for attribute in attributes {
                var preview = state
                let isSelected: Bool
                switch (kind, attribute) {
                case (.model, .model):
                    preview.model = attribute
                    isSelected = state.model.flatMap(shadowgramAttributeId) == shadowgramAttributeId(attribute)
                case (.backdrop, .backdrop):
                    preview.backdrop = attribute
                    isSelected = state.backdrop.flatMap(shadowgramAttributeId) == shadowgramAttributeId(attribute)
                case (.pattern, .pattern):
                    preview.pattern = attribute
                    isSelected = state.pattern.flatMap(shadowgramAttributeId) == shadowgramAttributeId(attribute)
                default:
                    continue
                }
                result.append(ShadowgramGiftGridItem(id: shadowgramAttributeId(attribute), subject: .preview(attributes: shadowgramUniqueAttributes(state: preview, base: base), rarity: shadowgramAttributeRarity(attribute)), title: shadowgramAttributeName(attribute), isSelected: isSelected))
            }
            return result
        }
        let picker = ShadowgramGiftGridController(context: context, title: title, style: .attributes, emptyText: strings.shadowgramGiftEditingAttributesEmpty, footerText: strings.shadowgramGiftEditingAttributesFooter, items: items, selected: { _, item in
            let _ = (catalog.attributes.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { attributes in
                guard let attribute = attributes?.first(where: { shadowgramAttributeId($0) == item.id }) else {
                    return
                }
                updateState { state in
                    switch kind {
                    case .model:
                        state.model = attribute
                    case .backdrop:
                        state.backdrop = attribute
                    case .pattern:
                        state.pattern = attribute
                    }
                }
            })
        })
        controller.push(picker)
    }, pickSender: {
        guard let controller = weakController else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let peerController = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.excludeSecretChats, .removeSearchHeader, .excludeRecent, .doNotSearchMessages], title: strings.shadowgramGiftEditingSender))
        peerController.peerSelected = { [weak peerController] peer, _ in
            peerController?.dismiss()
            updateState { state in
                state.sender = peer
            }
        }
        controller.push(peerController)
    }, clearSender: {
        updateState { state in
            state.sender = nil
            state.hideSenderName = false
        }
    }, update: { f in
        updateState(f)
    }, preview: {
        guard let controller = weakController, let gift = shadowgramBuildGift(state: stateValue.with { $0 }, peerId: peerId) else {
            return
        }
        controller.view.endEditing(true)
        controller.push(GiftViewScreen(context: context, subject: .profileGift(peerId, gift)))
    }, save: {
        guard let gift = shadowgramBuildGift(state: stateValue.with { $0 }, peerId: peerId) else {
            return
        }
        shadowgramAddEditedGift(peerId: peerId, gift: gift)
        weakController?.dismiss()
    })

    let signal: Signal<(ItemListControllerState, (ItemListNodeState, Any)), NoError> = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = ShadowgramStrings(languageCode: presentationData.strings.primaryComponent.languageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.shadowgramGiftEditingAddTitle), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: shadowgramGiftEditorEntries(state: state, strings: strings, presentationData: presentationData), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        catalogDisposable.dispose()
        let _ = catalog
    }

    let controller = ItemListController(context: context, state: signal)
    weakController = controller
    present(controller)
}
