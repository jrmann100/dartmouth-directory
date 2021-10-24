//
//  Dartmouth Directory.swift
//  Dartmouth Directory
//
//  Created by Jordan Mann on 10/4/21.
//

import SwiftUI

struct UserListHeaderView: View {
    @EnvironmentObject var state: SearchStateModel

    var body: some View {
        HStack {
            if state.rawUsers.count >= 50 {
                Label("Limited to 50 results.", systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
            } else {
                // FIXME: is this language intuitive?
                Text(
                    state.lookupState == .results ?
                        "Showing \(state.usersExcludingSelected.count) of \(state.rawUsers.count) result"
                        + (state.rawUsers.count != 1 ? "s" : "")
                        + (state.users.count != state.rawUsers.count ? " (filtered)" : "")
//                            + (usersExcludingSelected.count != users.count ? ", excluding \(users.count - usersExcludingSelected.count) selected" : "")
                        : state.lookupState.rawValue
                )
            }
        }
    }
}

struct SearchHeaderView: View {
    @EnvironmentObject var state: SearchStateModel
    @FocusState var focused: Bool
    var body: some View {
        HStack {
            Text("Lookup")
            TextField("Search...", text: $state.search)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .frame(maxWidth: nil)
                .focused($focused)
                .submitLabel(.done)
            Button { state.search = "" } label: { Label("Clear Search", systemImage: "xmark.circle.fill").labelStyle(.iconOnly) }.tint(.gray)
        }
        HStack {
            if state.filterKind == .year {
                Picker("Class", selection: $state.filterClass) {
                    ForEach(currentClasses, id: \.self) {
                        Text("'\($0 % 1000)").tag($0 % 1000)
                    }
                }
                .pickerStyle(.segmented)
            }

            Picker("Kind", selection: $state.filterKind) {
                if state.filterKind != .year {
                    Text("Class").tag(UserFilter.year)
                    Text("Student").tag(UserFilter.student)
                    Text("Staff").tag(UserFilter.staff)
                }
                Text(state.filterKind == .year ? "More" : "All").tag(UserFilter.all)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: state.filterKind == .year ? 50 : .infinity)
        }
        .animation(.default, value: state.filterKind)
    }
    // TODO: selection is not currently displaying correctly.
//            ToolbarItem(placement: .navigationBarTrailing) {
//                EditButton()
//            }
}

enum UserFilter: String {
    case year = "Year"
    case student = "Student"
    case staff = "Staff"
    case all = "All"
}

enum LookupState: String {
    case new = "Search by name or email"
    case searching = "Searching..."
    case results = ""
    case none = "No results"
    case error = "Error while searching"
}

// Get the next 4 graduating years as 2-digit years.
var currentClasses: [Int] {
    let calendar = Calendar.current
    //  Some June 12
    let someGraduation = DateComponents(month: 6, day: 12)
    // The year of next June 12
    let nextGraduationYear = calendar.dateComponents([.year], from: calendar.nextDate(after: Date(), matching: someGraduation, matchingPolicy: .nextTime)!).year!
    // The 2-digit years of the next 4 June 12's.
    return (nextGraduationYear ... nextGraduationYear + 3).map { $0 % 1000 }
}

class SearchStateModel: ObservableObject {
    // The search string.
    @Published var search: String = ""
    // The last search made. Lets us avoid duplicate API calls.
    @Published var lastSearch: String = ""
    // The list of users given by the API.
    @Published var rawUsers: [Lookup.User] = []
    // A list of users selected by the user.
    @Published var selected: [Lookup.User] = []
    // A list of users "highlighted" by the user in edit mode.
//    @State private var subSelection = Set<String>()
    // The current kind of user being filtered for.
    @Published var filterKind: UserFilter = .all
    // The current student class being filtered for, as a 2-digit year. // TODO: alumni?
    @Published var filterClass: Int = currentClasses.first!
    // The
    @Published var lookupState: LookupState = .new

    var users: [Lookup.User] {
        rawUsers.filter { user in
            switch filterKind {
            case .year: return user.dcDeptclass == "'\(filterClass)" // todo
            case .student: return user.eduPersonPrimaryAffiliation == "Student"
            case .staff: return user.eduPersonPrimaryAffiliation != "Student"
            case .all: return true
            }
        }
    }

    var usersExcludingSelected: [Lookup.User] {
        users.filter { !selected.contains($0) }
    }


    // TODO: confirm this decorator is being used correctly.
    // re: https://www.raywenderlich.com/25013447-async-await-in-swiftui
    @MainActor
    func lookup(_ dirty: Bool = false) async {
        if search == lastSearch, !dirty { return }
        lastSearch = search

        rawUsers = []

        if search == "" { lookupState = .new; return }

        lookupState = .searching
        do {
            rawUsers = try await Lookup.perform(for: search)
            lookupState = .results
        } catch Lookup.LookupError.cancelError {
            // The user is still typing...
        } catch {
            lookupState = .error
        }

        if lookupState == .results, rawUsers.count == 0 { lookupState = .none }
    }
}

struct ContentView: View {
    @StateObject var state = SearchStateModel()
    @FocusState private var focused: Bool

    @State private var filtersShown: Bool = true
    var body: some View {
        NavigationView {
            VStack {
                SearchHeaderView(focused: _focused)
                    .environmentObject(state)
                    .padding(.horizontal, 20)
                List {
                    SelectedItemsView(selected: $state.selected)
                    Section {
                        ForEach(state.usersExcludingSelected) { user in
                            UserListItemView(user: user).modifier(UserSwipeViewModifier(user: user, selected: $state.selected))
                        }
                    } header: {
                        UserListHeaderView()
                            .environmentObject(state)
                    }
                }
                .listStyle(.insetGrouped)
                .animation(.default, value: state.users)
                .animation(.default, value: state.selected)
            }
            .refreshable {
                await state.lookup(true)
            }
            .task(id: state.search) {
                await state.lookup()
            }
            .task(id: state.filterKind) {
                await state.lookup()
            }
            .navigationTitle("Lookup")
            .navigationBarHidden(true)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    focused = true
                }
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
