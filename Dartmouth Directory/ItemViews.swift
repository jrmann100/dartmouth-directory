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
            Button {
                user.compose()
            } label: {
                Label("Send Email", systemImage: "envelope.fill")
            }

            if user.telephoneNumber != nil {
                Button {
                    user.call()
                } label: {
                    Label("Call", systemImage: "phone.fill.arrow.up.right")
                }
            }
            Button {
                Lookup.copy(user.mail)
            } label: {
                Label("Copy Email", systemImage: "envelope")
            }
            if user.telephoneNumber != nil {
                Button {
                    Lookup.copy(user.telephoneNumber!)
                } label: {
                    Label("Copy Phone", systemImage: "phone")
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
    var body: some View {
        Section {
            ForEach(selected) { user in
                UserListItemView(user: user)

                    .swipeActions(edge: .leading) {
                        Button { user.compose() } label: { Image(systemName: "envelope.fill") }.tint(.blue)
                        if (user.telephoneNumber != nil){ Button { user.call() } label: { Image(systemName: "phone.fill") }.tint(.green) }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { selected.remove(at: selected.firstIndex(of: user)!) } label: { Image(systemName: "text.badge.minus") }
                    }
            }
        } header: {
            HStack {
                Text("\(selected.count) Selected")
                Menu {
                    Button {
                        Lookup.User.composeAll(selected)
                    } label: { Label("Mail All", systemImage: "envelope.fill") }.textCase(.none)
                    Button {
                        Lookup.User.copyAll(selected)
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
