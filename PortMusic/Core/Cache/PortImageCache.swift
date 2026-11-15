import Foundation
import UIKit
import CommonCrypto

public final class PortImageCache {
    public static let shared = PortImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskQueue = DispatchQueue(label: "com.portmusic.imagecache.disk", qos: .utility)
    private let fileManager = FileManager.default
    private let diskCacheURL: URL

    private let lock = NSLock()
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    private init() {
        memoryCache.totalCostLimit = 150 * 1024 * 1024 // 150 MB
        memoryCache.countLimit = 350

        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.diskCacheURL = cachesDirectory.appendingPathComponent("PortMusicCovers", isDirectory: true)

        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true, attributes: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
    }

    // MARK: - Synchronous L1 Memory Lookup
    public func imageFromMemory(for url: URL?) -> UIImage? {
        guard let url = url else { return nil }
        let key = url.absoluteString as NSString
        return memoryCache.object(forKey: key)
    }

    // MARK: - Primary Async Loading Pipeline
    public func loadImage(for url: URL?) async -> UIImage? {
        guard let url = url else { return nil }
        let urlString = url.absoluteString
        let key = urlString as NSString

        // 1. L1 Memory Cache Check
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        // 2. In-Flight Request Deduplication
        let existingTask: Task<UIImage?, Never>? = lock.withLock {
            if let task = inFlightTasks[urlString] {
                return task
            }
            let task = Task<UIImage?, Never> { [weak self] () -> UIImage? in
                guard let self = self else { return nil }
                return await self.fetchAndDecode(url: url)
            }
            inFlightTasks[urlString] = task
            return task
        }

        let result = await existingTask?.value

        lock.withLock {
            _ = inFlightTasks.removeValue(forKey: urlString)
        }

        return result
    }

    // MARK: - High-Speed Concurrent Prefetching
    public func prefetch(urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            // Run concurrent downloads in batches of 10
            let batchSize = 10
            var index = 0
            while index < urls.count {
                if Task.isCancelled { break }
                let chunk = Array(urls[index..<min(index + batchSize, urls.count)])
                await withTaskGroup(of: Void.self) { group in
                    for url in chunk {
                        group.addTask {
                            _ = await self.loadImage(for: url)
                        }
                    }
                }
                index += batchSize
            }
        }
    }

    // MARK: - Internal Disk & Network Fetch
    private func fetchAndDecode(url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString
        let diskURL = diskFilePath(for: url.absoluteString)

        // 1. Check L2 Disk Cache
        if fileManager.fileExists(atPath: diskURL.path),
           let data = try? Data(contentsOf: diskURL),
           let diskImage = UIImage(data: data) {
            let decoded = await diskImage.byPreparingForDisplay() ?? diskImage
            let cost = Int(decoded.size.width * decoded.size.height * 4)
            memoryCache.setObject(decoded, forKey: key, cost: cost)
            return decoded
        }

        // 2. Network Download
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let rawImage = UIImage(data: data) else {
                return nil
            }

            let decoded = await rawImage.byPreparingForDisplay() ?? rawImage
            let cost = Int(decoded.size.width * decoded.size.height * 4)
            memoryCache.setObject(decoded, forKey: key, cost: cost)

            // Save to L2 Disk in background
            diskQueue.async { [diskCacheURL = self.diskCacheURL, fileManager = self.fileManager] in
                if !fileManager.fileExists(atPath: diskCacheURL.path) {
                    try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true, attributes: nil)
                }
                try? data.write(to: diskURL, options: .atomic)
            }

            return decoded
        } catch {
            return nil
        }
    }

    // MARK: - Disk Path Computation (SHA-256)
    private func diskFilePath(for key: String) -> URL {
        let hash = sha256(key)
        return diskCacheURL.appendingPathComponent(hash)
    }

    private func sha256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "\(string.hashValue)" }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Cache Maintenance & Management
    public func clearAllCache() {
        memoryCache.removeAllObjects()
        diskQueue.sync {
            try? fileManager.removeItem(at: diskCacheURL)
            try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true, attributes: nil)
        }
    }

    public func calculateDiskCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for file in files {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    public func formattedDiskCacheSize() -> String {
        let bytes = calculateDiskCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
