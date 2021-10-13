//
//  Lookup.swift
//  Dartmouth Directory
//
//  Created by Jordan Mann on 10/11/21.
//

import Contacts
import Foundation
import UIKit

struct Lookup: Codable {
    public static func copy(_ text: String) {
        UIPasteboard.general.setValue(text, forPasteboardType: "public.plain-text")
    }

    private static func open(_ address: String) {
        UIApplication.shared.open(URL(string: address)!)
    }

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

        private var cnAddress: CNPostalAddress? {
            guard hinmanNo != nil else { return nil }
            let address = CNMutablePostalAddress()
            address.state = "NH"
            address.city = "Hanover"
            address.country = "United States"
            address.postalCode = "03755"
            address.street = "\(hinmanNo!) Hinman"
            return address
        }

        public var address: String? {
            CNPostalAddressFormatter().string(for: cnAddress)
        }

        public var hinmanNo: Int? {
            guard let addr = dcHinmanaddr else { return nil }
            guard let match = (try? NSRegularExpression(
                pattern: "^HB\\s(\\d{4})$"
            ))?.firstMatch(in: addr, options: [], range: NSRange(location: 0, length: addr.utf16.count))?.range(at: 1) else { return nil }
            guard let range = Range(match, in: addr) else { return nil }
            return Int(addr[range])
        }

        public func asContact() -> CNMutableContact {
            let contact = CNMutableContact()

            // Store the profile picture as data
            let image = UIImage(named: "Pine")
            contact.imageData = image?.jpegData(compressionQuality: 1.0)

            contact.givenName = displayName

            if dcDeptclass != nil {
                contact.jobTitle = "\(dcDeptclass!) at Dartmouth"
            }

            contact.emailAddresses = [CNLabeledValue(label: eduPersonPrimaryAffiliation == "Student" ? CNLabelSchool : CNLabelWork, value: mail as NSString)]

            if cnAddress != nil {
                contact.postalAddresses = [CNLabeledValue<CNPostalAddress>(label: CNLabelSchool, value: cnAddress!)]
            }

            if telephoneNumber != nil {
                contact.phoneNumbers = [CNLabeledValue(
                    label: CNLabelPhoneNumberMain,
                    value: CNPhoneNumber(stringValue: telephoneNumber!)
                )]
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

        public func compose() {
            Lookup.open("mailto:\(mail)")
        }

        public func call() {
            Lookup.open("tel:\(telephoneNumber!)") // TODO: err necessary?
        }

        public static func composeAll(_ users: [User]) {
            Lookup.open("mailto:\(users.map { $0.mail }.joined(separator: ","))")
        }

        public static func copyAll(_ users: [User]) {
            Lookup.copy(users.map { $0.mail }.joined(separator: ","))
        }
    }

    public enum LookupError: Error {
        case emptySearch, invalidSearch, fetchError, parseError, cancelError
    }

    public static func perform(for search: String) async throws -> [User] {
        if search == "" { throw LookupError.emptySearch }
        do {
            guard let url = URL(string: "https://api-lookup.dartmouth.edu/v1/lookup?q=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&includeAlum=false&field=uid&field=displayName&field=eduPersonPrimaryAffiliation&field=mail&field=eduPersonNickname&field=dcDeptclass&field=dcAffiliation&field=telephoneNumber&field=dcHinmanaddr") else { throw LookupError.invalidSearch }

            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))

            let json: Lookup = try JSONDecoder().decode(Lookup.self, from: data)
            return json.users
        }
        catch let error as LookupError {
            throw error
        }
        catch is DecodingError {
            throw LookupError.parseError
        }
        catch {
            if (error as NSError).domain == NSURLErrorDomain, (error as NSError).code == NSURLErrorCancelled {
                throw LookupError.cancelError
            }
            print("error in lookup: \n\t\(error)\n\t\(error)")
            throw error
        }
    }
}
