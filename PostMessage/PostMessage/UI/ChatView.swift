import SwiftUI

struct ChatView: View {

    @EnvironmentObject var appState: AppState
    let contact: String

    @State private var input = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var messages: [ChatMessage] {
        appState.conversations[contact] ?? []
    }

    var body: some View {
        ZStack {
            Theme.backgroundChat.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                                let showDate = index == 0 ||
                                    !Calendar.current.isDate(msg.timestamp,
                                                             inSameDayAs: messages[index - 1].timestamp)
                                if showDate {
                                    DateSeparator(date: msg.timestamp)
                                }
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal)
                        .padding(.vertical)
                    }
                    .onAppear {
                        proxy.scrollTo("bottom")
                        appState.markRead(contact)
                        appState.activeConversation = contact
                    }
                    .onDisappear {
                        appState.activeConversation = nil
                    }
                    .onChange(of: messages.count) { _, _ in
                        proxy.scrollTo("bottom")
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(Theme.fontMonoSmall)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Divider().background(Theme.border)

                HStack(spacing: 12) {
                    TextField("", text: $input, prompt: Text("message...").foregroundColor(Theme.textSecondary),
                              axis: .vertical)
                        .font(Theme.fontMono)
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: isSending ? "circle" : "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Theme.primary)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
                .padding()
                .background(Theme.background)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton(hasOtherUnread: !appState.profileUnreadCounts.isEmpty)
            }
            ToolbarItem(placement: .principal) {
                Text(contact)
                    .font(Theme.fontMono.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        isSending = true
        errorMessage = nil
        do {
            try await appState.send(text, to: contact)
        } catch {
            errorMessage = "error: \(error.localizedDescription)"
        }
        isSending = false
    }
}

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var hasOtherUnread: Bool = false

    var body: some View {
        Button {
            dismiss()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                if hasOtherUnread {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 9, height: 9)
                        .offset(x: 6, y: -4)
                }
            }
        }
    }
}

struct DateSeparator: View {
    let date: Date

    var label: String {
        if Calendar.current.isDateInToday(date)     { return "today" }
        if Calendar.current.isDateInYesterday(date) { return "yesterday" }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    var body: some View {
        Text("── \(label) ──")
            .font(Theme.fontMonoSmall)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 2) {
            HStack {
                if message.isOutgoing { Spacer(minLength: 60) }
                Text(message.text)
                    .font(Theme.fontMono)
                    .foregroundStyle(message.isOutgoing ? Theme.bubbleOutText : Theme.bubbleInText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.isOutgoing ? Theme.bubbleOut : Theme.bubbleIn)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(message.isOutgoing ? Theme.primaryDim : Theme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                if !message.isOutgoing { Spacer(minLength: 60) }
            }
            Text(message.timestamp.formatted(.dateTime.hour().minute()))
                .font(Theme.fontMonoSmall)
                .foregroundStyle(Theme.textSecondary)
                .padding(message.isOutgoing ? .trailing : .leading, 4)
        }
    }
}
