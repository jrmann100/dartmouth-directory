//
//  Dartmouth Directory.swift
//  Dartmouth Directory
//
//  Created by Jordan Mann on 10/4/21.
//

import SwiftUI

public struct Lookup: Codable {
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
    }
}

struct ContentView: View {
    @State var search: String
    @State var users: [Lookup.User]

    init() {
        _search = .init(initialValue: "Jordan")
        _users = .init(initialValue: [])
    }

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

    //                Picker(selection: .constant(1), label: Text("Picker"), content: {
    //                    Text("'25s").tag(1)
    //                    Text("Undergraduate").tag(2)
    //                })
    //                    .pickerStyle(SegmentedPickerStyle())

    private enum Field: Int, Hashable {
        case text
    }

    @FocusState private var focusedField: Field?

    // https://stackoverflow.com/q/58200555/9068081
    struct ClearButton: ViewModifier {
        @Binding var text: String
        var focused: Bool

        public func body(content: Content) -> some View {
            HStack {
                content

                if !text.isEmpty && focused {
                    Button {
                        text = ""
                    }
                    label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(UIColor.opaqueSeparator))
                    }
                }
            }
        }
    }

    struct UserView: View {
        let user: Lookup.User
        var body: some View {
            VStack(alignment: .leading) {
                if user.dcDeptclass != nil {
                    Text(user.dcDeptclass!)
                }

                Text(user.mail)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding()
        }
    }

    struct UserListItemView: View {
        func copy(_ text: String) {
            UIPasteboard.general.setValue(text, forPasteboardType: "public.plain-text")
        }

        let user: Lookup.User
        var body: some View {
            NavigationLink {
                UserView(user: user)
                    .navigationTitle(user.displayName)
            } label: {
                HStack {
                    Text(user.displayName + ",").fontWeight(.medium)
                    Text(user.dcDeptclass ?? "").fontWeight(.light)
                }
                .lineLimit(1)
            }
            .contextMenu {
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
                Button {
                    print("save contact")
                } label: {
                    Label("Save contact", systemImage: "person.crop.circle.badge.plus")
                }
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
//                Spacer().frame(height: 20)
                List {
//                    Section {
//                        TextField("Name", text: $search)
//
//                            .font(.headline)
//                            .submitLabel(.search)
//                            .focused($focusedField, equals: .text)
//                            .modifier(ClearButton(text: $search, focused: focusedField == .text))
//                            .minimumScaleFactor(0.75)
//                            .onAppear {
//                                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { focusedField = .text }
//                            }
//                    }
                    Section {
                        ForEach(users) { user in
                            UserListItemView(user: user)
                        }
                    } header: { Text("results") }
                }
                .listStyle(.insetGrouped)
                .animation(.default, value: users)
                .refreshable {
                    users = await lookup(search)
                }
                .task(id: search) {
                    users = await lookup(search)
                }
                .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name")
            }.navigationTitle("Lookup")
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
