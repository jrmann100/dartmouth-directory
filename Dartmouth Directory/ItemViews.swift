//
//  ItemViews.swift
//  Dartmouth Directory
//
//  Created by Jordan Mann on 10/11/21.
//

import SwiftUI

struct UserView: View {
    let user: Lookup.User
    var body: some View {
        ContactView(user.asContact()).padding(.horizontal, 20)
    }
}

struct UserListItemView: View {
    let user: Lookup.User
    var body: some View {
        NavigationLink {
            UserView(user: user)
                .navigationTitle(user.displayName)
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            HStack {
                Text(user.displayName + ",").fontWeight(.medium)
                Text(user.dcDeptclass ?? "").fontWeight(.light)
            }
            .lineLimit(1)
        }
        .contextMenu {
            if user.mail != nil {
                Button {
                    try! user.compose() // TODO: change this to a static method.
                } label: {
                    Label("Send Email", systemImage: "envelope.fill")
                }
            }

            if user.telephoneNumber != nil {
                Button {
                    user.call()
                } label: {
                    Label("Call", systemImage: "phone.fill.arrow.up.right")
                }
            }
            if user.address != nil {
                Button {
                    Lookup.copy(user.address!)
                } label: {
                    Label("Copy Hinman", systemImage: "tray")
                }
            }
            // TODO: save contact?
        }
    }
}

struct SelectedItemsView: View {
    @Binding var selected: [Lookup.User]
    @State private var expanded: Bool = true

    var body: some View {
        if selected.count > 0 {
            Section {
                DisclosureGroup(expanded || selected.count == 1 ? "\(selected.count) selected" : "\(selected.first?.displayName ?? "") & \(selected.count - 1) more", isExpanded: $expanded) {
                    ForEach(selected) { user in
                        UserListItemView(user: user).modifier(SelectedSwipeViewModifier(user: user, selected: $selected))
                    }
                    // TODO: don't think I can make this work in Swift's page structure.
//                    .onMove { indexSet, index in
//                        selected.move(fromOffsets: indexSet, toOffset: index)
//                    }
                }
            } header: {
                HStack {
                    Menu {
                        Button {
                            try! Lookup.User.composeAll(selected)
                        } label: { Label("Mail All", systemImage: "envelope.fill") }.textCase(.none)
                        Button {
                            try! Lookup.User.copyAll(selected)
                        } label: { Label("Copy Addresses", systemImage: "doc.on.doc.fill") }.textCase(.none)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        selected.removeAll()
                    } label: {
                        Label("Clear", systemImage: "trash").tint(Color.orange)
                    }
                }
            }
        }
    }
}

struct UserSwipeViewModifier: ViewModifier {
    let user: Lookup.User
    @Binding var selected: [Lookup.User]
    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading) {
                if user.mail != nil {
                    Button { selected.append(user) } label: { Image(systemName: "text.badge.plus") }.tint(.green)
                } else {
                    Button {} label: { Image(systemName: "text.badge.xmark") }
                }
            }
            .swipeActions(edge: .trailing) {
                if user.mail != nil { Button { try! user.compose() } label: { Image(systemName: "envelope.fill") }.tint(.blue) }
                if user.telephoneNumber != nil { Button { user.call() } label: { Image(systemName: "phone.fill") }.tint(.green) }
                if user.mail == nil && user.telephoneNumber == nil { Button {} label: { Image(systemName: "person.fill.xmark").tint(.orange) }} // TODO: replicate around
            }
    }
}

struct SelectedSwipeViewModifier: ViewModifier {
    let user: Lookup.User
    @Binding var selected: [Lookup.User]
    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading) {
                if user.mail != nil { Button { try! user.compose() } label: { Image(systemName: "envelope.fill") }.tint(.blue) }
                if user.telephoneNumber != nil { Button { user.call() } label: { Image(systemName: "phone.fill") }.tint(.green) }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { selected.remove(at: selected.firstIndex(of: user)!) } label: { Image(systemName: "text.badge.minus") }
            }
    }
}
