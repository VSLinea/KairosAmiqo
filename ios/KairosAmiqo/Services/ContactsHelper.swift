import Foundation
import Contacts

/// Lightweight contact info for participants (before conversion to PlanParticipant)
struct ContactInfo: Identifiable {
    let id = UUID()
    let name: String
    let email: String?
    let phone: String?
}

/// Helper for accessing iOS Contacts framework
/// Provides just-in-time permission requests and contact fetching
@MainActor
class ContactsHelper {
    private let store = CNContactStore()
    
    /// Request contacts permission with just-in-time prompt
    /// - Returns: true if granted, false if denied
    func requestPermission() async -> Bool {
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            print("❌ Contacts permission error: \(error)")
            return false
        }
    }
    
    /// Check current authorization status without prompting
    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }
    
    /// Fetch all contacts from user's address book
    /// - Returns: Array of ContactInfo (caller converts to PlanParticipant)
    func fetchContacts() async throws -> [ContactInfo] {
        // Check permission first
        guard authorizationStatus == .authorized else {
            throw ContactsError.notAuthorized
        }
        
        // Define keys to fetch
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keys)
        var contacts: [ContactInfo] = []
        
        try store.enumerateContacts(with: request) { contact, _ in
            // Convert CNContact to ContactInfo
            let fullName = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            
            guard !fullName.isEmpty else { return } // Skip contacts without names
            
            // Get first phone number or email
            let phone = contact.phoneNumbers.first?.value.stringValue
            let email = contact.emailAddresses.first?.value as String?
            
            // Must have at least one contact method
            guard phone != nil || email != nil else { return }
            
            let contactInfo = ContactInfo(
                name: fullName,
                email: email,
                phone: phone
            )
            
            contacts.append(contactInfo)
        }
        
        return contacts.sorted { $0.name < $1.name }
    }
    
    /// Search contacts by name
    /// - Parameter query: Search string
    /// - Returns: Filtered array of contacts
    func searchContacts(query: String) async throws -> [ContactInfo] {
        let allContacts = try await fetchContacts()
        
        guard !query.isEmpty else { return allContacts }
        
        return allContacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(query) ||
            contact.email?.localizedCaseInsensitiveContains(query) == true ||
            contact.phone?.localizedCaseInsensitiveContains(query) == true
        }
    }
}

enum ContactsError: Error {
    case notAuthorized
    case fetchFailed
}
