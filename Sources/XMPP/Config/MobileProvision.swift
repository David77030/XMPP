//
//  MobileProvision.swift
//  XMPP
//
//  Created by Mickaël Rémond on 03/11/2018.
//  Copyright © 2018 ProcessOne. All rights reserved.
//

import Foundation
#if os(Linux)
import PlistCoder
#endif

/* Decode mobileprovision plist file

 Usage:
 
 1. To get mobileprovision data as embedded in your app:

 MobileProvision.read()

 2. To get mobile provision data from a file on disk:
 
 MobileProvision.read(from: "my.mobileprovision")
 
*/

struct MobileProvision: Codable {
    var name: String
    var appIDName: String
    var platform: [String]
    var isXcodeManaged: Bool? = false
    var creationDate: Date
    var expirationDate: Date
    var entitlements: Entitlements
    
    private enum CodingKeys : String, CodingKey {
        case name = "Name"
        case appIDName = "AppIDName"
        case platform = "Platform"
        case isXcodeManaged = "IsXcodeManaged"
        case creationDate = "CreationDate"
        case expirationDate = "ExpirationDate"
        case entitlements = "Entitlements"
    }
    
    // Sublevel: decode entitlements informations
    struct Entitlements: Codable {
        let keychainAccessGroups: [String]
        let getTaskAllow: Bool
        let apsEnvironment: Environment
        
        private enum CodingKeys: String, CodingKey {
            case keychainAccessGroups = "keychain-access-groups"
            case getTaskAllow = "get-task-allow"
            case apsEnvironment = "aps-environment"
        }
        
        enum Environment: String, Codable {
            case development, production, disabled
        }
        
        init(keychainAccessGroups: Array<String>, getTaskAllow: Bool, apsEnvironment: Environment) {
            self.keychainAccessGroups = keychainAccessGroups
            self.getTaskAllow = getTaskAllow
            self.apsEnvironment = apsEnvironment
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let keychainAccessGroups: [String] = (try? container.decode([String].self, forKey: .keychainAccessGroups)) ?? []
            let getTaskAllow: Bool = (try? container.decode(Bool.self, forKey: .getTaskAllow)) ?? false
            let apsEnvironment: Environment = (try? container.decode(Environment.self, forKey: .apsEnvironment)) ?? .disabled
            
            self.init(keychainAccessGroups: keychainAccessGroups, getTaskAllow: getTaskAllow, apsEnvironment: apsEnvironment)
        }
    }
}

// Factory methods
extension MobileProvision {
    // Read mobileprovision file embedded in app.
    static func read() -> MobileProvision? {
        let profilePath: String? = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision")
        guard let path = profilePath else { return nil }
        return read(from: path)
    }

    // Read a .mobileprovision file on disk
    static func read(from profilePath: String) -> MobileProvision? {
        guard let plistDataString = try? NSString.init(contentsOfFile: profilePath,
                                                       encoding: String.Encoding.isoLatin1.rawValue) else { return nil }
                
        // Skip binary part at the start of the mobile provisionning profile
        let scanner = Scanner(string: plistDataString as String)
        guard scanner.scanUpToWrap(string: "<plist") != nil else { return nil }
        
        // ... and extract plist until end of plist payload (skip the end binary part.
        guard let extractedPlist = scanner.scanUpToWrap(string: "</plist>") else { return nil }

        guard let plist = extractedPlist.appending("</plist>").data(using: .isoLatin1) else { return nil }
        
        let decoder = PropertyListDecoder()
        do {
            let provision = try decoder.decode(MobileProvision.self, from: plist)
            return provision
        } catch {
            // TODO: log / handle error
            return nil
        }
    }
}

// TODO: Remove extension when the is a way to implement scanUpTo in a cross-platform way.
// See: https://forums.swift.org/t/porting-code-to-linux-issue-with-scanner/18275
fileprivate extension Scanner {

    func scanUpToWrap(string: String) -> String? {
        #if canImport(Darwin)
        var result: NSString?
        guard scanUpTo(string, into: &result) != false else { return nil }
        return result as String?
        #else
        return scanUpToString(string)
        #endif
    }

}

