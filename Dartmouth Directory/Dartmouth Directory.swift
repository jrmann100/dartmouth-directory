//
//  Dartmouth Directory.swift
//  Dartmouth Directory
//
//  Created by Jordan Mann on 10/4/21.
//

import SwiftUI

struct ContentView: View {
    @State private var search: String = "Jordan"
    @State private var lastSearch: String = ""
    @State private var users: [Lookup.User] = []
    @State private var selected: [Lookup.User] = []
    private var usersExcludingSelected: [Lookup.User] {
        users.filter { !selected.contains($0) }
    }

    private enum LookupState: String {
        case new = "Search by name or email"
        case searching = "Searching..."
        case results = ""
        case none = "No results"
        case error = "Error while searching"
    }

    @State private var state: LookupState = .new

    private func lookup(_ dirty: Bool = false) async {
        if search == lastSearch && !dirty { return }
        lastSearch = search

        users = []

        if search == "" { state = .new; return }

        state = .searching
        do {
            users = try await Lookup.perform(for: search)
            state = .results
        } catch Lookup.LookupError.cancelError {
            // The user is still typing...
        } catch {
            state = .error
        }

        if state == .results && users.count == 0 { state = .none }
    }

    @State private var filtersShown: Bool = true
    var body: some View {
        NavigationView {
            VStack { // TODO: I would like it if you could scroll away the searchable() and filters, but it seems like the filters make the header stick.
                DisclosureGroup(isExpanded: $filtersShown) {
                    // TODO: filter reset necessary?
                    Picker(selection: .constant(25)) {
                        Text("'25").tag(25)
                        Text("Student").tag(1) // TODO: enum
                        Text("Staff").tag(2)
                        Text("All").tag(4)
                    } label: {
                        Text("TODO: label")
                    }
                    .pickerStyle(.segmented)
                } label: {
                    Label("Filter Search", systemImage: "line.3.horizontal.decrease.circle").padding(.bottom, 10)
                }
                .padding(.horizontal, 20)
                List {
                    if selected.count > 0 {
                        SelectedItemsView(selected: $selected)
                    }
                    Section {
                        ForEach(usersExcludingSelected) { user in
                            UserListItemView(user: user)
                                .swipeActions(edge: .leading) {
                                    Button { selected.append(user) } label: { Image(systemName: "text.badge.plus") }.tint(.green)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button { user.compose() } label: { Image(systemName: "envelope.fill") }.tint(.blue)
                                    if user.telephoneNumber != nil { Button { user.call() } label: { Image(systemName: "phone.fill") }.tint(.green) }
                                }
                        }
                    } header: {
                        // \(selected.isEmpty ? "" : ", excluding \(selected.count) selected") TODO: hide selected while searching. 2 lists?
                        HStack {
                            if users.count >= 50 {
                                Label("Limited to 50 results.", systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
                            } else {
                                Text(state == .results ? (
                                    "\(usersExcludingSelected.count) result"
                                        + (usersExcludingSelected.count != 1 ? "s" : "")
                                        + (usersExcludingSelected.count != users.count ? ", excluding \(users.count - usersExcludingSelected.count) selected" : "")
                                ) : state.rawValue)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .animation(.default, value: users)
                .animation(.default, value: selected)
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Name")
            .navigationTitle("Lookup")
            .refreshable {
                await lookup(true)
            }
            .task(id: search) {
                await lookup()
            }
        }
    }
}

@main
struct Dartmouth_DirectoryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
