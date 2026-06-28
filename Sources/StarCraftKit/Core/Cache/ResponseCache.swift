import Foundation
import Logging

/// Thread-safe response cache that stores the raw response bytes.
///
/// Caching the original bytes (rather than re-encoding the decoded model) means the
/// cache never has to round-trip dates through an encoder, so a cached value always
/// decodes identically to a fresh network response.
public actor ResponseCache {
    private struct CacheEntry {
        let data: Data
        let headers: [String: String]
        let expiryDate: Date

        var isExpired: Bool {
            Date() > expiryDate
        }
    }

    private var cache: [String: CacheEntry] = [:]
    private let maxCacheSize: Int
    private let logger: Logger

    private var hitCount = 0
    private var missCount = 0

    public init(
        maxCacheSize: Int = 100,
        logger: Logger = Logger(label: "StarCraftKit.ResponseCache")
    ) {
        self.maxCacheSize = maxCacheSize
        self.logger = logger
    }

    /// Fetch cached raw response bytes if present and unexpired.
    public func data(for key: String) -> (data: Data, headers: [String: String])? {
        guard let entry = cache[key], !entry.isExpired else {
            missCount += 1
            logger.debug("Cache miss for key: \(key)")
            if cache[key]?.isExpired == true {
                cache.removeValue(forKey: key)
            }
            return nil
        }
        hitCount += 1
        logger.debug("Cache hit for key: \(key)")
        return (entry.data, entry.headers)
    }

    /// Store raw response bytes for the given key.
    public func store(
        _ data: Data,
        headers: [String: String],
        for key: String,
        ttl: TimeInterval
    ) {
        let expiryDate = Date().addingTimeInterval(ttl)
        cache[key] = CacheEntry(data: data, headers: headers, expiryDate: expiryDate)
        logger.debug("Cached response for key: \(key), TTL: \(ttl)s")
        evictIfNeeded()
    }

    /// Clear expired entries.
    public func clearExpired() {
        let before = cache.count
        cache = cache.filter { !$0.value.isExpired }
        let removed = before - cache.count
        if removed > 0 {
            logger.info("Removed \(removed) expired cache entries")
        }
    }

    /// Clear all cache entries.
    public func clearAll() {
        cache.removeAll()
        logger.info("Cleared all cache entries")
    }

    /// Current cache statistics.
    public func getStatistics() -> CacheStatistics {
        CacheStatistics(
            hitCount: hitCount,
            missCount: missCount,
            currentSize: cache.count,
            hitRate: hitCount > 0 ? Double(hitCount) / Double(hitCount + missCount) : 0
        )
    }

    private func evictIfNeeded() {
        guard cache.count > maxCacheSize else { return }

        let sortedEntries = cache.sorted { $0.value.expiryDate < $1.value.expiryDate }
        let entriesToRemove = sortedEntries.prefix(cache.count - maxCacheSize)
        for (key, _) in entriesToRemove {
            cache.removeValue(forKey: key)
        }
        logger.debug("Evicted \(entriesToRemove.count) cache entries")
    }
}

/// Cache statistics
public struct CacheStatistics: Sendable {
    public let hitCount: Int
    public let missCount: Int
    public let currentSize: Int
    public let hitRate: Double
}
