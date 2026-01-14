//
//  WebSocketManager.swift
//  numeri
//
//  Created by Sharbel Homa on 7/4/25.
//

import Foundation
import Combine

class WebSocketManager: ObservableObject {
    private let accessToken: String
    private var webSocketTask: URLSessionWebSocketTask?
    @Published private(set) var bids: SortedArray<OrderbookEntry> = SortedArray(keyGenerator: { "\($0.price)_\($0.side)" }, defaultAscending: false)
    @Published private(set) var offers: SortedArray<OrderbookEntry> = SortedArray(keyGenerator: { "\($0.price)_\($0.side)" }, defaultAscending: true)
    @Published private(set) var latencyMs: Int = 0
    @Published private(set) var orderbookSnapshot: OrderbookSnapshot = OrderbookSnapshot(bids: [], offers: [], timestamp: Date(), latencyMs: 0)
    private var lookupTable: [String: OrderbookEntry] = [:]
    private var hasReceivedSnapshot = false
    private var productId: String = "BTC-USD"
    private var lastMessageReceiveTime: Date?
    
    private let processingQueue = DispatchQueue(label: "com.numeri.websocket.processing", qos: .userInitiated)
    
    private var backgroundBids: SortedArray<OrderbookEntry> = SortedArray(keyGenerator: { "\($0.price)_\($0.side)" }, defaultAscending: false)
    private var backgroundOffers: SortedArray<OrderbookEntry> = SortedArray(keyGenerator: { "\($0.price)_\($0.side)" }, defaultAscending: true)
    
    private var lastUIUpdateTime: Date = Date()
    private let uiUpdateInterval: TimeInterval = 0.1
    private var pendingBids: SortedArray<OrderbookEntry>?
    private var pendingOffers: SortedArray<OrderbookEntry>?
    private var pendingUpdateWorkItem: DispatchWorkItem?
    
    private let maxOrderbookEntries = 100
    
    init(accessToken: String, productId: String = "BTC-USD") {
        self.accessToken = accessToken
        self.productId = productId
        connect()
    }
    
    private func connect() {
        guard let url = URL(string: "wss://advanced-trade-ws.coinbase.com") else {
            print("WebSocket error: Invalid URL for wss://advanced-trade-ws.coinbase.com")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, webSocketTask?.state == .running else {
                print("WebSocket not connected, retrying in 5 seconds")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.connect()
                }
                return
            }
            subscribe()
            receiveMessages()
        }
    }
    
    private func subscribe() {
        guard !accessToken.isEmpty else {
            print("WebSocket error: No access token available")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.connect()
            }
            return
        }
        
        let subscribeMessage: [String: Any] = [
            "type": "subscribe",
            "product_ids": [productId],
            "channel": "level2"
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: subscribeMessage)
            let message = URLSessionWebSocketTask.Message.data(jsonData)
            webSocketTask?.send(message) { error in
                if let error = error {
                    print("Error sending message: \(error)")
                }
            }
            print("Message sent to subscribe")
        } catch {
            print("Json Serialization Error subscribing: \(error)")
        }
    }
    
    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self?.handleMessage(data: data)
                case .string(let string):
                    if let data = string.data(using: .utf8) {
                        self?.handleMessage(data: data)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessages()
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.connect()
                }
            }
        }
    }
        
    private func handleMessage(data: Data) {
        let receiveTime = Date()
        
        do {
            let decoder = JSONDecoder()
            let message = try decoder.decode(OrderbookMessage.self, from: data)
            
            if let type = message.type, type == "error" {
                print("WebSocket error message: \(message.message ?? "Unknown error")")
                return
            }
            
            if message.channel == "subscriptions" {
                print("Subscription confirmed: \(String(data: data, encoding: .utf8) ?? "Unknown")")
                return
            }
            
            guard let events = message.events else {
                return
            }
            
            lastMessageReceiveTime = receiveTime
            
            for event in events {
                if event.subscriptions != nil {
                    print("✅ Subscription confirmed for: \(event.subscriptions?.level2 ?? [])")
                    continue
                }
                
                guard let updates = event.updates else {
                    print("⚠️ Event has no updates: type=\(event.type ?? "unknown")")
                    continue
                }
                
                let orderbookEntries = updates.map { update in
                    OrderbookEntry(
                        price: Double(update.priceLevel) ?? 0.0,
                        quantity: Double(update.newQuantity) ?? 0.0,
                        side: update.side,
                        timestamp: update.eventTime
                    )
                }
                
                processingQueue.async { [weak self] in
                    guard let self else { return }
                    if event.type == "snapshot" {
                        print("📸 Snapshot received with \(orderbookEntries.count) entries - processing...")
                        let startTime = Date()
                        self.hasReceivedSnapshot = true
                        let (newBids, newOffers) = self.processSnapshot(updates: orderbookEntries)
                        let processingTime = Date().timeIntervalSince(startTime)
                        print("📊 Processed snapshot in \(String(format: "%.3f", processingTime))s: \(newBids.count) bids, \(newOffers.count) offers")
                        self.backgroundBids = newBids
                        self.backgroundOffers = newOffers
                        let latency = self.calculateLatency()
                        DispatchQueue.main.async {
                            let now = Date()
                            self.bids = newBids
                            self.offers = newOffers
                            self.latencyMs = latency
                            // Update atomic snapshot for metrics calculator
                            self.orderbookSnapshot = OrderbookSnapshot(
                                bids: newBids.getElements(),
                                offers: newOffers.getElements(),
                                timestamp: now,
                                latencyMs: latency
                            )
                            print("✅ UI updated with snapshot data")
                        }
                    } else if event.type == "update" {
                        let (newBids, newOffers) = self.processUpdate(updates: orderbookEntries)
                        let bidCount = newBids.count
                        let offerCount = newOffers.count
                        
                        self.backgroundBids = newBids
                        self.backgroundOffers = newOffers
                        
                        if !self.hasReceivedSnapshot {
                            if bidCount > 0 || offerCount > 0 {
                                print("📝 Update before snapshot: \(bidCount) bids, \(offerCount) offers - updating UI immediately")
                                let latency = self.calculateLatency()
                                DispatchQueue.main.async {
                                    let now = Date()
                                    self.bids = newBids
                                    self.offers = newOffers
                                    self.latencyMs = latency
                                    // Update atomic snapshot for metrics calculator
                                    self.orderbookSnapshot = OrderbookSnapshot(
                                        bids: newBids.getElements(),
                                        offers: newOffers.getElements(),
                                        timestamp: now,
                                        latencyMs: latency
                                    )
                                    print("✅ UI updated with \(bidCount) bids, \(offerCount) offers")
                                }
                            } else {
                                print("⚠️ Update processed but resulted in empty arrays")
                            }
                        } else {
                            self.scheduleUIUpdate(bids: newBids, offers: newOffers)
                        }
                    }
                }
                
                if !hasReceivedSnapshot {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                        guard let self, !self.hasReceivedSnapshot else { return }
                        print("No snapshot received, resubscribing")
                        self.subscribe()
                    }
                }
            }
        } catch {
            print("Decode error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw message: \(jsonString)")
            }
        }
    }
        
    private func processSnapshot(updates: [OrderbookEntry]) -> (SortedArray<OrderbookEntry>, SortedArray<OrderbookEntry>) {
        lookupTable.removeAll()
        
        let validUpdates = updates.filter { $0.quantity > 0 }
        var bidsList: [OrderbookEntry] = []
        var offersList: [OrderbookEntry] = []
        
        for update in validUpdates {
            let key = "\(update.price)_\(update.side)"
            lookupTable[key] = update
            let sideLower = update.side.lowercased()
            if sideLower == "bid" {
                bidsList.append(update)
            } else if sideLower == "offer" || sideLower == "ask" {
                offersList.append(update)
            } else {
                print("⚠️ Unknown side value: '\(update.side)' for price \(update.price)")
            }
        }
        
        bidsList.sort { $0.price > $1.price }
        offersList.sort { $0.price < $1.price }
        
        let topBids = Array(bidsList.prefix(maxOrderbookEntries))
        let topOffers = Array(offersList.prefix(maxOrderbookEntries))
        
        // Use sorted initialization with key generator - O(n) instead of O(n²) insertion
        let keyGenerator: (OrderbookEntry) -> String = { "\($0.price)_\($0.side)" }
        let newBids = SortedArray<OrderbookEntry>(sortedElements: topBids, keyGenerator: keyGenerator, defaultAscending: false)
        let newOffers = SortedArray<OrderbookEntry>(sortedElements: topOffers, keyGenerator: keyGenerator, defaultAscending: true)
        
        return (newBids, newOffers)
    }
    
    private func processUpdate(updates: [OrderbookEntry]) -> (SortedArray<OrderbookEntry>, SortedArray<OrderbookEntry>) {
        var updatedBids = backgroundBids
        var updatedOffers = backgroundOffers
        
        for update in updates {
            let key = "\(update.price)_\(update.side)"
            let sideLower = update.side.lowercased()
            if update.quantity == 0 {
                lookupTable.removeValue(forKey: key)
                // O(1) removal using key instead of O(n) linear search
                if sideLower == "bid" {
                    updatedBids.remove(key: key)
                } else if sideLower == "offer" || sideLower == "ask" {
                    updatedOffers.remove(key: key)
                }
            } else {
                // O(1) update using key instead of O(n) remove + O(n) insert
                if sideLower == "bid" {
                    updatedBids.update(update)
                } else if sideLower == "offer" || sideLower == "ask" {
                    updatedOffers.update(update)
                }
                lookupTable[key] = update
            }
        }
        
        updatedBids = limitSize(updatedBids, maxEntries: maxOrderbookEntries, isBids: true)
        updatedOffers = limitSize(updatedOffers, maxEntries: maxOrderbookEntries, isBids: false)
        
        return (updatedBids, updatedOffers)
    }
    
    private func scheduleUIUpdate(bids: SortedArray<OrderbookEntry>, offers: SortedArray<OrderbookEntry>) {
        // Capture values to avoid accessing properties after potential deallocation
        let capturedBids = bids
        let capturedOffers = offers
        
        pendingUpdateWorkItem?.cancel()
        
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUIUpdateTime)
        
        let latency: Int
        if let receiveTime = lastMessageReceiveTime {
            latency = Int((now.timeIntervalSince(receiveTime)) * 1000)
        } else {
            latency = 0
        }
        
        if timeSinceLastUpdate >= uiUpdateInterval {
            lastUIUpdateTime = now
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.bids = capturedBids
                self.offers = capturedOffers
                self.latencyMs = latency
                // Update atomic snapshot for metrics calculator
                self.orderbookSnapshot = OrderbookSnapshot(
                    bids: capturedBids.getElements(),
                    offers: capturedOffers.getElements(),
                    timestamp: now,
                    latencyMs: latency
                )
                self.pendingBids = nil
                self.pendingOffers = nil
                self.pendingUpdateWorkItem = nil
            }
        } else {
            let delay = uiUpdateInterval - timeSinceLastUpdate
            pendingBids = capturedBids
            pendingOffers = capturedOffers
            
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                // Use captured values instead of accessing properties
                let updateTime = Date()
                self.lastUIUpdateTime = updateTime
                self.bids = capturedBids
                self.offers = capturedOffers
                self.latencyMs = latency
                // Update atomic snapshot for metrics calculator
                self.orderbookSnapshot = OrderbookSnapshot(
                    bids: capturedBids.getElements(),
                    offers: capturedOffers.getElements(),
                    timestamp: updateTime,
                    latencyMs: latency
                )
                self.pendingBids = nil
                self.pendingOffers = nil
                self.pendingUpdateWorkItem = nil
            }
            pendingUpdateWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
    
    private func limitSize(_ array: SortedArray<OrderbookEntry>, maxEntries: Int, isBids: Bool) -> SortedArray<OrderbookEntry> {
        let elements = array.getElements()
        guard elements.count > maxEntries else { return array }
        
        let limitedElements = Array(elements.prefix(maxEntries))
        let keyGenerator: (OrderbookEntry) -> String = { "\($0.price)_\($0.side)" }
        return SortedArray<OrderbookEntry>(sortedElements: limitedElements, keyGenerator: keyGenerator, defaultAscending: !isBids)
    }
    
    private func calculateLatency() -> Int {
        guard let receiveTime = lastMessageReceiveTime else { return 0 }
        return Int((Date().timeIntervalSince(receiveTime)) * 1000)
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        bids.removeAll()
        offers.removeAll()
        lookupTable.removeAll()
        hasReceivedSnapshot = false
        backgroundBids.removeAll()
        backgroundOffers.removeAll()
        pendingBids = nil
        pendingOffers = nil
        pendingUpdateWorkItem?.cancel()
        pendingUpdateWorkItem = nil
    }
    
    deinit {
        disconnect()
    }
}

