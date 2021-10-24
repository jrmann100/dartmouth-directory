//
//  Dartmouth Directory.swift
//  Dartmouth Directory
//
//  Created by Jordan Mann on 10/4/21.
//

import SwiftUI

private func currentClasses() -> ClosedRange<Int> {
    let calendar = Calendar.current
    let nextGraduation = DateComponents(month: 6, day: 12)
    let nextGraduatingClass = calendar.dateComponents([.year], from: calendar.nextDate(after: Date(), matching: nextGraduation, matchingPolicy: .nextTime)!).year!
    return nextGraduatingClass ... nextGraduatingClass + 3
}

struct ContentView: View {
    @State private var search: String = "Jordan"
    @State private var lastSearch: String = ""
    @State private var rawUsers: [Lookup.User] = []
    @State private var selected: [Lookup.User] = []
    @State private var subSelection = Set<String>()
    @State private var filterKind: UserFilter = .all
    @State private var filterClass: Int = currentClasses().first! % 1000

    private struct UserListHeaderView: View {
        @Binding var rawUsers: [Lookup.User]
        var users: [Lookup.User]
        var usersExcludingSelected: [Lookup.User]

        @Binding var state: LookupState
        var body: some View {
            HStack {
                if rawUsers.count >= 50 {
                    Label("Limited to 50 results.", systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
                } else {
                    Text(
                        state == .results ?
                            "Showing \(usersExcludingSelected.count) of \(rawUsers.count) result"
                            + (rawUsers.count != 1 ? "s" : "")
                            + (users.count != rawUsers.count ? " (filtered)" : "")
//                            + (usersExcludingSelected.count != users.count ? ", excluding \(users.count - usersExcludingSelected.count) selected" : "")
                            : state.rawValue
                    )
                }
            }
        }
    }

    private struct ContentToolbar: ToolbarContent {
        @Binding var search: String
        @Binding var filterKind: UserFilter
        @Binding var filterClass: Int
        var body: some ToolbarContent {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("Lookup")
            }
            ToolbarItem(placement: .principal) {
                TextField("Search...", text: $search)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .frame(maxWidth: nil)
                    // TODO: Since the search bar is out of the main view hierarchy, this is probably impossible.
//                    .focused($focused)
                    .submitLabel(.done)
            }
            ToolbarItemGroup(placement: .keyboard) {
                //                    } label: { Label("Filter Search", systemImage: "line.3.horizontal.decrease.circle") }
                HStack {
                    if filterKind == .year {
                        Picker("Class", selection: $filterClass) {
                            ForEach(currentClasses(), id: \.self) {
                                Text("'\($0 % 1000)").tag($0 % 1000)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Picker("Kind", selection: $filterKind) {
                        if filterKind != .year {
                            Text("Class").tag(UserFilter.year)
                            Text("Student").tag(UserFilter.student)
                            Text("Staff").tag(UserFilter.staff)
                        }
                        Text("All").tag(UserFilter.all)
                        // TODO: alums?
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: filterKind == .year ? 50 : .infinity)
                    // TODO: resizing looks a little janky.
                }.animation(.default, value: filterKind)
            }
            // TODO: selection is not currently displaying correctly.
//            ToolbarItem(placement: .navigationBarTrailing) {
//                EditButton()
//            }
        }
    }

    private enum UserFilter: String {
        case year = "Year"
        case student = "Student"
        case staff = "Staff"
        case all = "All"
    }

    private var users: [Lookup.User] {
        rawUsers.filter { user in
            switch filterKind {
            case .year: return user.dcDeptclass == "'\(filterClass)" // todo
            case .student: return user.eduPersonPrimaryAffiliation == "Student"
            case .staff: return user.eduPersonPrimaryAffiliation != "Student"
            case .all: return true
            }
        }
    }

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

        rawUsers = []

        if search == "" { state = .new; return }

        state = .searching
        do {
            rawUsers = try await Lookup.perform(for: search)
            state = .results
        } catch Lookup.LookupError.cancelError {
            // The user is still typing...
        } catch {
            state = .error
        }

        if state == .results && rawUsers.count == 0 { state = .none }
    }

    @State private var filtersShown: Bool = true
    var body: some View {
        NavigationView {
            VStack {
//                Text("header")
                    List(selection: $subSelection) {
                        SelectedItemsView(selected: $selected)
                        Section {
                            ForEach(usersExcludingSelected) { user in
                                UserListItemView(user: user).modifier(UserSwipeViewModifier(user: user, selected: $selected))
                            }
                        } header: {
                            UserListHeaderView(rawUsers: $rawUsers, users: users, usersExcludingSelected: usersExcludingSelected, state: $state)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .animation(.default, value: users)
                    .animation(.default, value: selected)
//                Text("footer")
                }
//            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Name")
            .toolbar { ContentToolbar(search: $search, filterKind: $filterKind, filterClass: $filterClass) }
            .refreshable {
                await lookup(true)
            }
            .task(id: search) {
                await lookup()
            }
            .task(id: filterKind) {
                await lookup()
            }
            .navigationTitle("Lookup")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: subSelection) {
                print($0)
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
