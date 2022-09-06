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

    public struct User: Codable, Identifiable, Equatable, Hashable {
        public let dcAffiliation: String
        public let dcDeptclass: String?
        public let dcHinmanaddr: String?
        public let displayName: String
        public let eduPersonNickname: String?
        public let eduPersonPrimaryAffiliation: String
        public let mail: String?
        public let telephoneNumber: String?
        public let uid: String
        public var id: String { uid }

        // TODO: is this necessary?
        public func hash(into hasher: inout Hasher) {
            hasher.combine(uid.hash)
        }

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

            // https://stackoverflow.com/a/42790186/9068081
            tryParseName: do {
                let regex = try NSRegularExpression(pattern: "^(?<first>[\\w'-]+)\\s(?<middle>[\\w'-\\.]+)?\\s?(?<last>[\\w'-]+)$")
                let result = regex.matches(in: displayName, range: NSMakeRange(0, displayName.utf16.count))
                if result.count == 0 { break tryParseName }

                let firstRange = Range(result[0].range(withName: "first"), in: displayName)
                let middleRange = Range(result[0].range(withName: "middle"), in: displayName)
                let lastRange = Range(result[0].range(withName: "last"), in: displayName)
                if firstRange != nil { contact.givenName = String(displayName[firstRange!]) }
                if middleRange != nil { contact.middleName = String(displayName[middleRange!]) } // todo what if missing
                if lastRange != nil { contact.familyName = String(displayName[lastRange!]) }
            }
            catch {}
            if contact.givenName == "" { // we broke or caught above
                contact.givenName = displayName
            }

            if dcDeptclass != nil {
                contact.jobTitle = "\(dcDeptclass!) at Dartmouth"
            }

            if mail != nil {
                contact.emailAddresses = [CNLabeledValue(label: eduPersonPrimaryAffiliation == "Student" ? CNLabelSchool : CNLabelWork, value: mail! as NSString)]
            }

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
            
// TODO: contact saving? I'd like AirDrop/download-like functionality.
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

        public func compose() throws {
            guard mail != nil else { throw LookupError.unhandledOptionalError }
            Lookup.open("mailto:\(mail!)")
        }

        public func call() throws {
            guard telephoneNumber != nil else { throw LookupError.unhandledOptionalError }
            Lookup.open("tel:\(telephoneNumber!)")
        }

        public static func composeAll(_ users: [User]) throws {
            guard users.filter({ $0.mail != nil }).count == users.count else { throw LookupError.unhandledOptionalError }
            Lookup.open("mailto:\(users.map { $0.mail! }.joined(separator: ","))")
        }

        public static func copyAll(_ users: [User]) throws {
            guard users.filter({ $0.mail != nil }).count == users.count else { throw LookupError.unhandledOptionalError }
            Lookup.copy(users.map { $0.mail! }.joined(separator: ","))
        }
    }

    public enum LookupError: Error {
        case emptySearchError, invalidSearchError, fetchError, parseError, cancelError, unhandledOptionalError
    }

    public static func perform(for search: String) async throws -> [User] {
        if search == "" { throw LookupError.emptySearchError }
        do {
            guard let url = URL(string: "https://api-lookup.dartmouth.edu/v1/lookup?q=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&includeAlum=false&field=uid&field=displayName&field=eduPersonPrimaryAffiliation&field=mail&field=eduPersonNickname&field=dcDeptclass&field=dcAffiliation&field=telephoneNumber&field=dcHinmanaddr") else { throw LookupError.invalidSearchError }

            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))

            let json: Lookup = try JSONDecoder().decode(Lookup.self, from: data)
            return json.users
        }
        catch let error as LookupError {
            throw error
        }
        catch let error as DecodingError {
            print(error)
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
