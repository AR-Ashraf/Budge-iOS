import Foundation
import UIKit

/// Disk + `UserDefaults` cache for the signed-in user's profile photo so avatars avoid repeated network loads.
/// Invalidates when the remote `photoURL` string changes.
enum ProfilePhotoCache {
    private static let defaultsPrefix = "profile_photo_remote_url_v1_"
    private static let subfolderName = "ProfilePhotos"

    private static var folderURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(subfolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func fileURL(uid: String) -> URL {
        folderURL.appendingPathComponent("\(uid).img", isDirectory: false)
    }

    private static func remoteURLKey(uid: String) -> String {
        defaultsPrefix + uid
    }

    /// Loads from disk only when the stored fingerprint matches the current remote URL.
    static func cachedImageIfFresh(for uid: String, remoteURL: URL?) -> UIImage? {
        guard let remoteURL else { return nil }
        guard UserDefaults.standard.string(forKey: remoteURLKey(uid: uid)) == remoteURL.absoluteString else {
            return nil
        }
        let url = fileURL(uid: uid)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return UIImage(data: data)
    }

    /// Persists raw image bytes and records which remote URL they correspond to.
    static func store(_ data: Data, uid: String, remoteFingerprint: String) throws {
        try data.write(to: fileURL(uid: uid), options: .atomic)
        UserDefaults.standard.set(remoteFingerprint, forKey: remoteURLKey(uid: uid))
    }

    /// Loads cache if fresh; otherwise downloads once, saves, and returns the image.
    static func loadOrFetch(uid: String, remoteURL: URL?) async -> UIImage? {
        guard let remoteURL else {
            clear(for: uid)
            return nil
        }
        if let cached = cachedImageIfFresh(for: uid, remoteURL: remoteURL) {
            return cached
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            guard !data.isEmpty else { return nil }
            try store(data, uid: uid, remoteFingerprint: remoteURL.absoluteString)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    static func clear(for uid: String) {
        try? FileManager.default.removeItem(at: fileURL(uid: uid))
        UserDefaults.standard.removeObject(forKey: remoteURLKey(uid: uid))
    }
}
