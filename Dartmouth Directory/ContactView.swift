//
//  ContactView.swift
//  Dartmouth Directory
//
//  Created by Jordan Mann on 10/11/21,
//  With credit to judomat on GitHub:
//  https://github.com/judomat/CNContactViewController-debug/blob/main/CNContactViewController-debug/CNContactViewController.swift
//

import Contacts
import ContactsUI
import Foundation
import SwiftUI

struct ContactView: UIViewControllerRepresentable {
    let contact: CNContact

    class Coordinator: NSObject, CNContactViewControllerDelegate {
        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {}
    }

    init(_ contact: CNContact) {
        self.contact = contact
    }

    func makeUIViewController(context: Context) -> CNContactViewController {
        let controller = CNContactViewController(forUnknownContact: contact)
        controller.delegate = context.coordinator
        // TODO: these don't seem to do anything
        controller.allowsEditing = false
        controller.allowsActions = false

        return controller
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    func updateUIViewController(_ uiViewController: CNContactViewController, context: Context) {}
}
