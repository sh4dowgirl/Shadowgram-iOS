import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import LegacyComponents
import ItemListUI
import PresentationDataUtils

/// A slider that snaps to fixed `values`, with a label above each step.
/// Modelled on `ChatSlowmodeItem` (PeerInfoUI).
final class ShadowgramStepSliderItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let systemStyle: ItemListSystemStyle
    let values: [Int32]
    let labels: [String]
    let value: Int32
    let sectionId: ItemListSectionId
    let updated: (Int32) -> Void

    init(theme: PresentationTheme, systemStyle: ItemListSystemStyle, values: [Int32], labels: [String], value: Int32, sectionId: ItemListSectionId, updated: @escaping (Int32) -> Void) {
        self.theme = theme
        self.systemStyle = systemStyle
        self.values = values
        self.labels = labels
        self.value = value
        self.sectionId = sectionId
        self.updated = updated
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ShadowgramStepSliderItemNode(stepCount: self.values.count)
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ShadowgramStepSliderItemNode {
                let makeLayout = nodeValue.asyncLayout()

                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

final class ShadowgramStepSliderItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode

    private let textNodes: [TextNode]
    private var sliderView: TGPhotoEditorSliderView?

    private var item: ShadowgramStepSliderItem?
    private var layoutParams: ListViewItemLayoutParams?
    private var reportedValue: Int32?

    init(stepCount: Int) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true

        self.maskNode = ASImageNode()

        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true

        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true

        self.textNodes = (0 ..< max(2, stepCount)).map { _ -> TextNode in
            let textNode = TextNode()
            textNode.isUserInteractionEnabled = false
            textNode.displaysAsynchronously = false
            return textNode
        }

        super.init(layerBacked: false)

        self.textNodes.forEach(self.addSubnode)
    }

    private static func position(of value: Int32, in values: [Int32]) -> Int {
        for i in 0 ..< values.count {
            if values[i] >= value {
                return i
            }
        }
        return max(0, values.count - 1)
    }

    private func updateSliderView() {
        if let sliderView = self.sliderView, let item = self.item {
            sliderView.maximumValue = CGFloat(item.values.count - 1)
            sliderView.positionsCount = item.values.count
            sliderView.value = CGFloat(ShadowgramStepSliderItemNode.position(of: item.value, in: item.values))
            sliderView.isUserInteractionEnabled = true
            sliderView.alpha = 1.0
            sliderView.layer.allowsGroupOpacity = false
        }
    }

    override func didLoad() {
        super.didLoad()

        self.view.disablesInteractiveTransitionGestureRecognizer = true

        let sliderView = TGPhotoEditorSliderView()
        sliderView.limitValueChangedToLatestState = true
        sliderView.enablePanHandling = true
        sliderView.trackCornerRadius = 2.0
        sliderView.lineSize = 4.0
        sliderView.dotSize = 5.0
        sliderView.minimumValue = 0.0
        sliderView.maximumValue = CGFloat(max(1, self.textNodes.count - 1))
        sliderView.positionsCount = self.textNodes.count
        sliderView.startValue = 0.0
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        sliderView.useLinesForPositions = true
        if let item = self.item, let params = self.layoutParams {
            sliderView.value = CGFloat(ShadowgramStepSliderItemNode.position(of: item.value, in: item.values))
            self.reportedValue = item.value
            sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
            sliderView.backColor = item.theme.list.itemSwitchColors.frameColor
            sliderView.startColor = item.theme.list.itemSwitchColors.frameColor
            sliderView.trackColor = item.theme.list.itemAccentColor
            sliderView.knobImage = PresentationResourcesItemList.knobImage(item.theme)

            sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: 37.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 15.0 * 2.0, height: 44.0))
            sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minX, left: 0.0, bottom: 0.0, right: -sliderView.frame.minX)
        }
        self.view.addSubview(sliderView)
        sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        self.sliderView = sliderView

        self.updateSliderView()
    }

    func asyncLayout() -> (_ item: ShadowgramStepSliderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        let makeTextLayouts = self.textNodes.map(TextNode.asyncLayout)

        return { [weak self] item, params, neighbors in
            var themeUpdated = false
            if currentItem?.theme !== item.theme {
                themeUpdated = true
            }

            let separatorHeight = UIScreenPixel
            let separatorRightInset: CGFloat = item.systemStyle == .glass ? 16.0 : 0.0

            var textLayoutAndApply: [(TextNodeLayout, () -> TextNode)] = []
            for i in 0 ..< makeTextLayouts.count {
                let label = i < item.labels.count ? item.labels[i] : ""
                let (textLayout, textApply) = makeTextLayouts[i](TextNodeLayoutArguments(attributedString: NSAttributedString(string: label, font: Font.regular(13.0), textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
                textLayoutAndApply.append((textLayout, textApply))
            }

            let contentSize = CGSize(width: params.width, height: 88.0)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)

            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size

            return (layout, { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.item = item
                strongSelf.layoutParams = params

                strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor

                if strongSelf.backgroundNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                }
                if strongSelf.topStripeNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                }
                if strongSelf.bottomStripeNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                }
                if strongSelf.maskNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.maskNode, at: 3)
                }
                let hasCorners = itemListHasRoundedBlockLayout(params)
                var hasTopCorners = false
                var hasBottomCorners = false
                switch neighbors.top {
                case .sameSection(false):
                    strongSelf.topStripeNode.isHidden = true
                default:
                    hasTopCorners = true
                    strongSelf.topStripeNode.isHidden = hasCorners
                }
                let bottomStripeOffset: CGFloat
                switch neighbors.bottom {
                case .sameSection(false):
                    bottomStripeOffset = -separatorHeight
                    strongSelf.bottomStripeNode.isHidden = false
                default:
                    hasBottomCorners = true
                    strongSelf.bottomStripeNode.isHidden = hasCorners
                    bottomStripeOffset = 0.0
                }

                strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners, glass: item.systemStyle == .glass) : nil

                strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - params.rightInset - separatorRightInset, height: separatorHeight))

                let textNodes: [(TextNode, CGSize)] = textLayoutAndApply.map { layout, apply -> (TextNode, CGSize) in
                    let node = apply()
                    return (node, layout.size)
                }

                let delta = (params.width - params.leftInset - params.rightInset - 18.0 * 2.0) / CGFloat(max(1, textNodes.count - 1))
                for i in 0 ..< textNodes.count {
                    let (textNode, textSize) = textNodes[i]

                    var position = params.leftInset + 18.0 + delta * CGFloat(i)
                    if i == textNodes.count - 1 {
                        position -= textSize.width
                    } else if i > 0 {
                        position -= textSize.width / 2.0
                    }

                    textNode.frame = CGRect(origin: CGPoint(x: position, y: 15.0), size: textSize)
                }

                if let sliderView = strongSelf.sliderView {
                    if themeUpdated {
                        sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        sliderView.backColor = item.theme.list.itemSwitchColors.frameColor
                        sliderView.startColor = item.theme.list.itemSwitchColors.frameColor
                        sliderView.trackColor = item.theme.list.itemAccentColor
                        sliderView.knobImage = PresentationResourcesItemList.knobImage(item.theme)
                    }

                    sliderView.frame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: 37.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 15.0 * 2.0, height: 44.0))
                    sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minX, left: 0.0, bottom: 0.0, right: -sliderView.frame.minX)

                    strongSelf.updateSliderView()
                }
            })
        }
    }

    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }

    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }

    @objc private func sliderValueChanged() {
        guard let item = self.item, let sliderView = self.sliderView, !item.values.isEmpty else {
            return
        }

        let position = Int(sliderView.value)
        let value = item.values[max(0, min(item.values.count - 1, position))]
        if self.reportedValue != value {
            self.reportedValue = value
            item.updated(value)
        }
    }
}
