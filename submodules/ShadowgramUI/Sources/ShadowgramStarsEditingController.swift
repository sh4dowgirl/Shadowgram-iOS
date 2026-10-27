import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext

/// "Stars Editing": presents the add/subtract/set/reset action sheet for the local Stars
/// balance display override, then one more plain alert with a number field for the three
/// operations that need a value. Deliberately plain UIKit alerts rather than the themed
/// Display ones - this is a utility, not a polished product surface, and it keeps the
/// implementation small and robust.
public func presentShadowgramStarsEditing(context: AccountContext, from controller: ViewController) {
    guard let starsContext = context.starsContext, !starsContext.ton else {
        return
    }
    let peerId = context.account.peerId

    func currentDisplayedValue(_ completion: @escaping (Int64) -> Void) {
        let _ = (starsContext.state
        |> take(1)).start(next: { state in
            completion(state?.balance.value ?? 0)
        })
    }

    func promptForNumber(title: String, message: String, initialValue: Int64?, completion: @escaping (Int64) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.keyboardType = .numberPad
            if let initialValue {
                textField.text = "\(initialValue)"
            }
            textField.placeholder = "0"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] _ in
            let text = alert?.textFields?.first?.text ?? ""
            guard let value = Int64(text.trimmingCharacters(in: .whitespacesAndNewlines)), value >= 0 else {
                return
            }
            completion(value)
        }))
        controller.present(alert, animated: true, completion: nil)
    }

    let sheet = UIAlertController(title: "Stars Editing", message: nil, preferredStyle: .actionSheet)
    sheet.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
        currentDisplayedValue { current in
            promptForNumber(title: "Add Stars", message: "Added to the current displayed value.", initialValue: nil, completion: { amount in
                shadowgramApplyStarsOverrideOperation(context: starsContext, peerId: peerId, currentDisplayedValue: current, operation: .add(amount))
            })
        }
    }))
    sheet.addAction(UIAlertAction(title: "Subtract", style: .default, handler: { _ in
        currentDisplayedValue { current in
            promptForNumber(title: "Subtract Stars", message: "Subtracted from the current displayed value.", initialValue: nil, completion: { amount in
                shadowgramApplyStarsOverrideOperation(context: starsContext, peerId: peerId, currentDisplayedValue: current, operation: .subtract(amount))
            })
        }
    }))
    sheet.addAction(UIAlertAction(title: "Set", style: .default, handler: { _ in
        currentDisplayedValue { current in
            promptForNumber(title: "Set Stars", message: "Replaces the displayed balance.", initialValue: current, completion: { amount in
                shadowgramApplyStarsOverrideOperation(context: starsContext, peerId: peerId, currentDisplayedValue: current, operation: .set(amount))
            })
        }
    }))
    sheet.addAction(UIAlertAction(title: "Reset to Real Value", style: .destructive, handler: { _ in
        currentDisplayedValue { current in
            shadowgramApplyStarsOverrideOperation(context: starsContext, peerId: peerId, currentDisplayedValue: current, operation: .reset)
        }
    }))
    sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    if let popover = sheet.popoverPresentationController {
        // iPad presents an action sheet as a popover and crashes without an anchor.
        popover.sourceView = controller.view
        popover.sourceRect = CGRect(origin: CGPoint(x: controller.view.bounds.midX, y: controller.view.bounds.midY), size: CGSize())
        popover.permittedArrowDirections = []
    }
    controller.present(sheet, animated: true, completion: nil)
}
