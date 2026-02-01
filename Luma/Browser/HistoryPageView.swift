// Luma MVP - History Page (luma://history)
import SwiftUI

/// Displays unified browsing and chat history in a timeline view.
/// Accessible via luma://history special URL.
struct HistoryPageView: View {
    @ObservedObject var historyManager = HistoryManager.shared
    @State private var selectedTimeframe: HistoryManager.ClearTimeframe = .allTime
    @State private var searchQuery: String = ""
    @State private var showClearConfirmation: Bool = false
    @State private var clearTimeframe: HistoryManager.ClearTimeframe = .allTime
    
    private let bgColor = Color(white: 0.11)
    private let cardBg = Color(white: 0.15)
    private let textPrimary = Color(white: 0.9)
    private let textSecondary = Color(white: 0.6)
    private let accentColor = Color.blue
    
    var filteredEvents: [HistoryEvent] {
        let events = searchQuery.isEmpty
            ? historyManager.getHistory(for: selectedTimeframe)
            : historyManager.searchHistory(query: searchQuery)
        return events
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("History")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(textPrimary)
                        Text("\(filteredEvents.count) events")
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Search and filters
                HStack(spacing: 12) {
                    // Search
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                        TextField("Search history...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .foregroundColor(textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Timeframe picker
                    Picker("", selection: $selectedTimeframe) {
                        Text("Today").tag(HistoryManager.ClearTimeframe.today)
                        Text("This Week").tag(HistoryManager.ClearTimeframe.thisWeek)
                        Text("Last 30 Days").tag(HistoryManager.ClearTimeframe.last30Days)
                        Text("All Time").tag(HistoryManager.ClearTimeframe.allTime)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 360)
                    
                    // Clear button
                    Menu {
                        Button("Clear Individual Item...") { }
                            .disabled(true)
                        Divider()
                        Button("Clear Today") {
                            clearTimeframe = .today
                            showClearConfirmation = true
                        }
                        Button("Clear This Week") {
                            clearTimeframe = .thisWeek
                            showClearConfirmation = true
                        }
                        Button("Clear Last 30 Days") {
                            clearTimeframe = .last30Days
                            showClearConfirmation = true
                        }
                        Divider()
                        Button("Clear All History", role: .destructive) {
                            clearTimeframe = .allTime
                            showClearConfirmation = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text("Clear")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(bgColor)
            
            Divider()
                .opacity(0.2)
            
            // Timeline
            if filteredEvents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(groupedByDate.keys.sorted(by: >), id: \.self) { date in
                            VStack(alignment: .leading, spacing: 8) {
                                // Date header
                                Text(formatDate(date))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 8)
                                
                                // Events for this date
                                ForEach(groupedByDate[date] ?? []) { event in
                                    eventCard(event)
                                        .padding(.horizontal, 24)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bgColor)
        .alert("Clear History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                historyManager.clearHistory(timeframe: clearTimeframe)
            }
        } message: {
            Text(clearMessage(for: clearTimeframe))
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(textSecondary.opacity(0.5))
            Text("No history found")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textSecondary)
            if !searchQuery.isEmpty {
                Text("Try a different search query")
                    .font(.system(size: 13))
                    .foregroundColor(textSecondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func eventCard(_ event: HistoryEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: event.type == .pageVisit ? "safari" : "bubble.left.and.bubble.right")
                .font(.system(size: 16))
                .foregroundColor(event.type == .pageVisit ? accentColor : Color.purple)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(event.type == .pageVisit ? accentColor.opacity(0.1) : Color.purple.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 6) {
                // Title/description
                if event.type == .pageVisit {
                    Text(event.pageTitle ?? "Untitled")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textPrimary)
                    if let url = event.url {
                        Text(url)
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Chat Conversation")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textPrimary)
                    if let messages = event.chatMessages, !messages.isEmpty {
                        Text(messages.first?.text ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                            .lineLimit(2)
                    }
                    if let summary = event.conversationSummary {
                        Text(summary)
                            .font(.system(size: 11))
                            .foregroundColor(textSecondary.opacity(0.8))
                            .padding(8)
                            .background(cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(.top, 4)
                    }
                }
                
                // Timestamp
                Text(formatTime(event.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(textSecondary.opacity(0.7))
            }
            
            Spacer()
            
            // Delete button
            Button(action: {
                historyManager.clearIndividualEvent(event.id)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(textSecondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .opacity(0.0)
            .onHover { hovering in
                // Would show on hover
            }
        }
        .padding(12)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    private var groupedByDate: [Date: [HistoryEvent]] {
        let calendar = Calendar.current
        var grouped: [Date: [HistoryEvent]] = [:]
        
        for event in filteredEvents {
            let dateKey = calendar.startOfDay(for: event.timestamp)
            if grouped[dateKey] == nil {
                grouped[dateKey] = []
            }
            grouped[dateKey]?.append(event)
        }
        
        return grouped
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func clearMessage(for timeframe: HistoryManager.ClearTimeframe) -> String {
        switch timeframe {
        case .today:
            return "This will clear all history from today."
        case .thisWeek:
            return "This will clear all history from the past 7 days."
        case .last30Days:
            return "This will clear all history from the past 30 days."
        case .allTime:
            return "This will permanently delete all browsing and chat history."
        }
    }
}
