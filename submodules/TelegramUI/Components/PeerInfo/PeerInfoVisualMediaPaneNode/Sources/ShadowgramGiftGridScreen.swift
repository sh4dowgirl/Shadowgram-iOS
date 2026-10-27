import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import GiftItemComponent
import PlainButtonComponent
import MultilineTextComponent

/// One cell of `ShadowgramGiftGridController`, drawn by the same `GiftItemComponent` the app's
/// own gift screens use (Send Gift's catalog, the upgrade variants grid, the profile grid).
struct ShadowgramGiftGridItem: Equatable {
    let id: String
    let subject: GiftItemComponent.Subject
    let peer: GiftItemComponent.Peer?
    let title: String?
    let ribbon: GiftItemComponent.Ribbon?
    let isSelected: Bool

    init(id: String, subject: GiftItemComponent.Subject, peer: GiftItemComponent.Peer? = nil, title: String? = nil, ribbon: GiftItemComponent.Ribbon? = nil, isSelected: Bool = false) {
        self.id = id
        self.subject = subject
        self.peer = peer
        self.title = title
        self.ribbon = ribbon
        self.isSelected = isSelected
    }
}

/// How the grid's cells are drawn: the Send Gift catalog (tall cells with a price), the upgrade
/// variants picker (attribute previews with their rarity), or profile-style cells.
enum ShadowgramGiftGridStyle {
    case catalog
    case attributes
    case profile
}

private final class ShadowgramGiftGridNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let style: ShadowgramGiftGridStyle
    private let emptyText: String
    private let footerText: String?
    private let selected: (ShadowgramGiftGridItem) -> Void

    private var presentationData: PresentationData
    private let scrollView = UIScrollView()
    private var itemViews: [String: ComponentView<Empty>] = [:]
    private let emptyView = ComponentView<Empty>()
    private let footerView = ComponentView<Empty>()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    private var items: [ShadowgramGiftGridItem]?
    private var validLayout: (ContainerViewLayout, CGFloat)?

    init(context: AccountContext, presentationData: PresentationData, style: ShadowgramGiftGridStyle, emptyText: String, footerText: String?, selected: @escaping (ShadowgramGiftGridItem) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.style = style
        self.emptyText = emptyText
        self.footerText = footerText
        self.selected = selected

        super.init()

        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
    }

    override func didLoad() {
        super.didLoad()

        self.scrollView.delegate = self
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.showsVerticalScrollIndicator = true
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.view.addSubview(self.scrollView)

        self.activityIndicator.color = self.presentationData.theme.list.itemSecondaryTextColor
        self.view.addSubview(self.activityIndicator)
        self.activityIndicator.startAnimating()
    }

    func updateItems(_ items: [ShadowgramGiftGridItem]?) {
        let isFirst = self.items == nil
        self.items = items
        self.updateLayout(transition: isFirst ? .immediate : .easeInOut(duration: 0.25))
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        self.validLayout = (layout, navigationBarHeight)
        self.updateLayout(transition: .immediate)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateLayout(transition: .immediate)
    }

    private func updateLayout(transition: ComponentTransition) {
        guard let (layout, navigationBarHeight) = self.validLayout, self.isNodeLoaded else {
            return
        }
        let theme = self.presentationData.theme
        let strings = self.presentationData.strings

        self.scrollView.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.activityIndicator.center = CGPoint(x: layout.size.width / 2.0, y: navigationBarHeight + 80.0)
        self.activityIndicator.isHidden = self.items != nil

        let sideInset: CGFloat = max(16.0, max(layout.safeInsets.left, layout.safeInsets.right) + 16.0)
        let spacing: CGFloat = 10.0
        let columns: Int = layout.size.width > 480.0 ? 5 : 3
        let itemWidth = floor((layout.size.width - sideInset * 2.0 - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let itemHeight: CGFloat
        let mode: GiftItemComponent.Mode
        switch self.style {
        case .catalog:
            itemHeight = 154.0
            mode = .generic
        case .attributes:
            itemHeight = 126.0
            mode = .upgradePreview
        case .profile:
            itemHeight = itemWidth
            mode = .profile
        }

        let items = self.items ?? []
        let topInset = navigationBarHeight + 16.0
        let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -200.0)
        var validIds = Set<String>()

        for (index, item) in items.enumerated() {
            let row = index / columns
            let column = index % columns
            let frame = CGRect(x: sideInset + CGFloat(column) * (itemWidth + spacing), y: topInset + CGFloat(row) * (itemHeight + spacing), width: itemWidth, height: itemHeight)
            if !visibleBounds.intersects(frame) {
                continue
            }
            validIds.insert(item.id)

            var itemTransition = transition
            let itemView: ComponentView<Empty>
            if let current = self.itemViews[item.id] {
                itemView = current
            } else {
                itemView = ComponentView()
                self.itemViews[item.id] = itemView
                itemTransition = .immediate
            }
            let _ = itemView.update(
                transition: itemTransition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(GiftItemComponent(
                        context: self.context,
                        style: .glass,
                        theme: theme,
                        strings: strings,
                        peer: item.peer,
                        subject: item.subject,
                        title: item.title,
                        ribbon: item.ribbon,
                        isSelected: item.isSelected,
                        mode: mode
                    )),
                    effectAlignment: .center,
                    action: { [weak self] in
                        self?.selected(item)
                    },
                    animateAlpha: false
                )),
                environment: {},
                containerSize: frame.size
            )
            if let view = itemView.view {
                if view.superview == nil {
                    self.scrollView.addSubview(view)
                    if !transition.animation.isImmediate {
                        view.layer.animateScale(from: 0.01, to: 1.0, duration: 0.25)
                        view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                }
                itemTransition.setFrame(view: view, frame: frame)
            }
        }

        for (id, itemView) in self.itemViews where !validIds.contains(id) {
            self.itemViews.removeValue(forKey: id)
            if let view = itemView.view {
                if !transition.animation.isImmediate {
                    view.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                    view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                        view.removeFromSuperview()
                    })
                } else {
                    view.removeFromSuperview()
                }
            }
        }

        let rows = (items.count + columns - 1) / columns
        var contentHeight = topInset + CGFloat(rows) * (itemHeight + spacing)

        let textWidth = layout.size.width - sideInset * 2.0
        let emptySize = self.emptyView.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: self.emptyText, font: Font.regular(15.0), textColor: theme.list.itemSecondaryTextColor)),
                horizontalAlignment: .center,
                maximumNumberOfLines: 0
            )),
            environment: {},
            containerSize: CGSize(width: textWidth, height: 200.0)
        )
        if let view = self.emptyView.view {
            if view.superview == nil {
                self.scrollView.addSubview(view)
            }
            view.isHidden = self.items == nil || !items.isEmpty
            view.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - emptySize.width) / 2.0), y: topInset + 60.0), size: emptySize)
        }

        if let footerText = self.footerText, !items.isEmpty {
            let footerSize = self.footerView.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: footerText, font: Font.regular(13.0), textColor: theme.list.freeTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: 200.0)
            )
            if let view = self.footerView.view {
                if view.superview == nil {
                    self.scrollView.addSubview(view)
                }
                view.isHidden = false
                view.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - footerSize.width) / 2.0), y: contentHeight + 6.0), size: footerSize)
            }
            contentHeight += footerSize.height + 12.0
        } else {
            self.footerView.view?.isHidden = true
        }

        contentHeight += max(16.0, layout.intrinsicInsets.bottom)
        if self.scrollView.contentSize.height != contentHeight || self.scrollView.contentSize.width != layout.size.width {
            self.scrollView.contentSize = CGSize(width: layout.size.width, height: contentHeight)
        }
    }
}

/// A screen with a grid of gifts to pick from, in the app's own gift cells.
final class ShadowgramGiftGridController: ViewController {
    private let context: AccountContext
    private let style: ShadowgramGiftGridStyle
    private let emptyText: String
    private let footerText: String?
    private let items: Signal<[ShadowgramGiftGridItem]?, NoError>
    private let selected: (ShadowgramGiftGridController, ShadowgramGiftGridItem) -> Void
    private var itemsDisposable: Disposable?
    private var presentationData: PresentationData

    private var gridNode: ShadowgramGiftGridNode {
        return self.displayNode as! ShadowgramGiftGridNode
    }

    init(context: AccountContext, title: String, style: ShadowgramGiftGridStyle, emptyText: String, footerText: String? = nil, items: Signal<[ShadowgramGiftGridItem]?, NoError>, selected: @escaping (ShadowgramGiftGridController, ShadowgramGiftGridItem) -> Void) {
        self.context = context
        self.style = style
        self.emptyText = emptyText
        self.footerText = footerText
        self.items = items
        self.selected = selected
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.title = title
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.itemsDisposable?.dispose()
    }

    override func loadDisplayNode() {
        self.displayNode = ShadowgramGiftGridNode(context: self.context, presentationData: self.presentationData, style: self.style, emptyText: self.emptyText, footerText: self.footerText, selected: { [weak self] item in
            guard let self else {
                return
            }
            self.selected(self, item)
        })
        self.displayNodeDidLoad()

        self.itemsDisposable = (self.items
        |> deliverOnMainQueue).start(next: { [weak self] items in
            self?.gridNode.updateItems(items)
        })
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.gridNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }
}
