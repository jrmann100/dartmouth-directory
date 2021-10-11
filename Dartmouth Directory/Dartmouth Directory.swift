//
//  Dartmouth Directory.swift
//  Dartmouth Directory
//
//  Created by Jordan Mann on 10/4/21.
//

import Contacts
import ContactsUI
import SwiftUI

// https://github.com/judomat/CNContactViewController-debug/blob/main/CNContactViewController-debug/CNContactViewController.swift
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
        // todo: these don't seem to do anything
        controller.allowsEditing = false
        controller.allowsActions = false

        return controller
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    func updateUIViewController(_ uiViewController: CNContactViewController, context: Context) {}
}

struct Lookup: Codable {
    public let truncated: Bool
    public let users: [User]

    public struct User: Codable, Identifiable, Equatable {
        public let dcAffiliation: String
        public let dcDeptclass: String?
        public let dcHinmanaddr: String?
        public let displayName: String
        public let eduPersonNickname: String?
        public let eduPersonPrimaryAffiliation: String
        public let mail: String
        public let telephoneNumber: String?
        public let uid: String
        public var id: String { uid }

        public var hinmanNo: Int? {
            guard let addr = dcHinmanaddr else { return nil }
            guard let match = (try? NSRegularExpression(
                pattern: "^HB\\s(\\d{4})$"
            ))?.firstMatch(in: addr, options: [], range: NSRange(location: 0, length: addr.utf16.count))?.range(at: 1) else {return nil}
                guard let range = Range(match, in: addr) else { return nil}
                return Int(addr[range])
        }
        
        public func asContact() -> CNMutableContact {
            let contact = CNMutableContact()

            // Store the profile picture as data
            let image = UIImage(named: "Pine")
            contact.imageData = image?.jpegData(compressionQuality: 1.0)

            contact.givenName = displayName

            if dcDeptclass != nil {
                contact.jobTitle = dcDeptclass!
            }

            contact.emailAddresses = [CNLabeledValue(label: eduPersonPrimaryAffiliation == "Student" ? CNLabelSchool : CNLabelWork, value: mail as NSString)]
            
            if hinmanNo != nil {
                let address = CNMutablePostalAddress()
                address.state = "NH"
                address.city = "Hanover"
                address.country = "United States"
                address.postalCode = "03755"
                address.street = "\(hinmanNo!) Hinman"
                
                contact.postalAddresses = [CNLabeledValue<CNPostalAddress>(label:CNLabelSchool, value:address)]
            }

            if telephoneNumber != nil {
                contact.phoneNumbers = [CNLabeledValue(
                    label: CNLabelPhoneNumberMain,
                    value: CNPhoneNumber(stringValue: telephoneNumber!))]
            }

            if eduPersonNickname != nil {
                contact.nickname = eduPersonNickname!
            }
            
            contact.note = "Dartmouth ID: \(uid)"

            return contact

//            // Save the newly created contact
//            let store = CNContactStore()
//            let saveRequest = CNSaveRequest()
//            saveRequest.add(contact, toContainerWithIdentifier: nil)
//
//            do {
//                try store.execute(saveRequest)
//            } catch {
//                print("Saving contact failed, error: \(error)")
//                // Handle the error
//            }
        }
    }
}

struct ContentView: View {
    @State var search: String = "Jordan"
    @State var lastSearch: String = ""
    @State var users: [Lookup.User] = []
    @State var selected: [Lookup.User] = []

    func lookup(_ search: String) async -> [Lookup.User] {
        if search == "" { return [] }
        do {
            let request = URLRequest(url: URL(string: "https://api-lookup.dartmouth.edu/v1/lookup?q=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&includeAlum=false&field=uid&field=displayName&field=eduPersonPrimaryAffiliation&field=mail&field=eduPersonNickname&field=dcDeptclass&field=dcAffiliation&field=telephoneNumber&field=dcHinmanaddr")!)

            let (data, _) = try await URLSession.shared.data(for: request)

            let json: Lookup = try! JSONDecoder().decode(Lookup.self, from: data)
            return json.users
        } catch {
            return []
        }
    }

    private enum Field: Int, Hashable {
        case text
    }

    @FocusState private var focusedField: Field?

    struct UserView: View {
        let user: Lookup.User
        var body: some View {
            ContactView(user.asContact())
        }
    }

    
    static func mail(_ address: String) {
        UIApplication.shared.open(URL(string: "mailto:\(address)")!)
    }
    
    static func copy(_ text: String) {
        UIPasteboard.general.setValue(text, forPasteboardType: "public.plain-text")
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
                    mail(user.mail)
                } label: {
                    Label("Send email", systemImage: "square.and.pencil")
                }
                Button {
                    copy(user.mail)
                } label: {
                    Label("Copy email address", systemImage: "envelope.fill")
                }
                if user.dcHinmanaddr != nil {
                    Button {
                        copy(user.dcHinmanaddr!) // TODO: replace with computed hinman
                    } label: {
                        Label("Copy mail address", systemImage: "tray.fill")
                    }
                }
// todo: save contact?
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
                            Button (role: .destructive) { selected.remove(at: selected.firstIndex(of: user)!); return } label: { Image(systemName: "text.badge.plus") }
                        }
                        .swipeActions(edge: .trailing) {
                            Button (role: .destructive) { selected.remove(at: selected.firstIndex(of: user)!); return } label: { Image(systemName: "text.badge.plus") }
                        }
                }
            } header: {
                HStack {
                Label("Selected", systemImage: "text")
                Menu {
                    Button { print("1") } label: {Label("1", systemImage: "text")}
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up" )
                }
                }
            }

        }
    }

    var body: some View {
        NavigationView {
            VStack {
                if (users.count == 0) { Text("No results") } // todo: enum for stateZ
                List {
                    if (selected.count > 0) {
                        SelectedItemsView(selected: $selected)
                    }
                    ForEach(users.filter {!selected.contains($0)}) { user in
                        UserListItemView(user: user)
                            .swipeActions(edge: .leading) {
                                Button { selected.append(user) } label: { Image(systemName: "text.badge.plus") }.tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button { ContentView.mail(user.mail) } label: { Image(systemName: "envelope.fill") }.tint(.blue)
                            }
                    }
                }
                .listStyle(.insetGrouped)
                .animation(.default, value: users)
                .animation(.default, value: selected) // todo ?
            }
            .navigationTitle("Lookup")
            .refreshable {
                users = []
                users = await lookup(search)
            }
            .task(id: search) {
                if search == lastSearch { return }
                lastSearch = search
                users = []
                users = await lookup(search)
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name")
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
