//
//  SortedArray.swift
//  numeri
//
//  Created by Sharbel Homa on 7/27/25.
//

import Foundation
import Combine

/// Efficient orderbook data structure using Dictionary for O(1) updates
/// Sorts lazily on read (O(n log n) for ~100 entries is very fast)
struct SortedArray<Element: Comparable & Identifiable & Equatable>: Equatable {
    private var storage: [String: Element] = [:]
    
    private var cachedElements: [Element]?
    private var cachedAscending: Bool?
    
    private let keyGenerator: (Element) -> String
    
    private let defaultAscending: Bool
    
    /// Initialize with a key generator function and default sort order
    /// For OrderbookEntry, this should be: { "\($0.price)_\($0.side)" }
    init(keyGenerator: @escaping (Element) -> String, defaultAscending: Bool = true) {
        self.keyGenerator = keyGenerator
        self.defaultAscending = defaultAscending
    }
    
    /// Initialize with default key generator (uses id)
    init(defaultAscending: Bool = true) {
        self.keyGenerator = { "\($0.id)" }
        self.defaultAscending = defaultAscending
    }
    
    /// Initialize from an already-sorted array
    init(sortedElements: [Element], keyGenerator: @escaping (Element) -> String, defaultAscending: Bool = true) {
        self.keyGenerator = keyGenerator
        self.defaultAscending = defaultAscending
        for element in sortedElements {
            storage[keyGenerator(element)] = element
        }
        self.cachedElements = sortedElements
        self.cachedAscending = defaultAscending
    }
    
    /// Initialize from sorted array with default key generator
    init(sortedElements: [Element], defaultAscending: Bool = true) {
        self.keyGenerator = { "\($0.id)" }
        self.defaultAscending = defaultAscending
        for element in sortedElements {
            storage[keyGenerator(element)] = element
        }
        self.cachedElements = sortedElements
        self.cachedAscending = defaultAscending
    }
    
    static func == (lhs: SortedArray, rhs: SortedArray) -> Bool {
        lhs.storage == rhs.storage
    }
    
    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }
    
    /// Get sorted elements - O(n log n) but cached after first call
    /// For ~100 entries, this is very fast (~700 operations)
    /// If no parameter is provided, uses the default sort order
    func getElements(ascending: Bool? = nil) -> [Element] {
        let sortAscending = ascending ?? defaultAscending
        
        if let cached = cachedElements, cachedAscending == sortAscending {
            return cached
        }
        
        let sorted = storage.values.sorted(by: sortAscending ? (<) : (>))
        // Note: We can't mutate cachedElements here since this is not mutating
        // The cache will be invalidated on next mutation anyway
        return sorted
    }
    
    /// Update or insert an element - O(1) operation
    mutating func update(_ element: Element) {
        let key = keyGenerator(element)
        storage[key] = element
        invalidateCache()
    }
    
    /// Insert an element (alias for update) - O(1)
    mutating func insert(_ element: Element, ascending: Bool = true) {
        update(element)
    }
    
    /// Remove element by key - O(1)
    mutating func remove(key: String) {
        storage.removeValue(forKey: key)
        invalidateCache()
    }
    
    /// Remove elements matching predicate - O(n) but only iterates once
    mutating func remove(where predicate: (Element) -> Bool) {
        let keysToRemove = storage.values
            .filter(predicate)
            .map { keyGenerator($0) }
        for key in keysToRemove {
            storage.removeValue(forKey: key)
        }
        if !keysToRemove.isEmpty {
            invalidateCache()
        }
    }
    
    /// Get element by key - O(1)
    func get(key: String) -> Element? {
        storage[key]
    }
    
    /// Check if element exists - O(1)
    func contains(key: String) -> Bool {
        storage[key] != nil
    }
    
    /// Remove all elements - O(1)
    mutating func removeAll() {
        storage.removeAll()
        invalidateCache()
    }
    
    /// Invalidate the cache (called on mutations)
    private mutating func invalidateCache() {
        cachedElements = nil
        cachedAscending = nil
    }
    
    /// Get all keys - O(n)
    func getAllKeys() -> [String] {
        Array(storage.keys)
    }
}
