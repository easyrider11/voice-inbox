import Foundation

/// Where recorded audio lives on disk. Models store only the filename;
/// the container path changes between installs, so URLs are resolved here.
enum AudioStore {
    static func directory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appending(path: "Recordings", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(for filename: String) throws -> URL {
        try directory().appending(path: filename)
    }

    static func exists(_ filename: String) -> Bool {
        guard let url = try? url(for: filename) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    static func delete(_ filename: String) {
        guard let url = try? url(for: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
