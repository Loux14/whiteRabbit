import SwiftUI

struct ConversationListView: View {

    @EnvironmentObject var appState: AppState

    @State private var newContact = ""
    @State private var showNewChat = false
    @State private var showSwitcher = false
    @State private var path = NavigationPath()

    var contacts: [String] {
        appState.conversations.keys.sorted {
            let a = appState.conversations[$0]?.last?.timestamp ?? .distantPast
            let b = appState.conversations[$1]?.last?.timestamp ?? .distantPast
            return a > b
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.background.ignoresSafeArea()

                List {
                    ForEach(contacts, id: \.self) { contact in
                        NavigationLink(value: contact) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(contact)
                                        .font(Theme.fontMono.weight(.semibold))
                                        .foregroundStyle(Theme.primary)
                                    if let last = appState.conversations[contact]?.last {
                                        Text(last.text)
                                            .font(Theme.fontMonoSmall)
                                            .foregroundStyle(Theme.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if let count = appState.unreadCounts[contact], count > 0 {
                                    Text("\(count)")
                                        .font(Theme.fontMonoSmall.bold())
                                        .foregroundStyle(Theme.background)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Theme.primary)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Theme.background)
                    }
                    .onDelete { indexSet in
                        indexSet.map { contacts[$0] }.forEach {
                            appState.conversations.removeValue(forKey: $0)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationDestination(for: String.self) { contact in
                ChatView(contact: contact)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSwitcher = true } label: {
                        let hasOtherUnread = !appState.profileUnreadCounts.isEmpty
                        ZStack(alignment: .topTrailing) {
                            AvatarView(index: appState.activeProfile?.avatarIndex ?? 0, size: 28)
                            if hasOtherUnread {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 9, height: 9)
                                    .offset(x: 3, y: -3)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("< \(appState.pseudo) >")
                        .font(Theme.fontMono.bold())
                        .foregroundStyle(Color.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showSwitcher) {
                AccountSwitcherView()
                    .environmentObject(appState)
            }
            .alert("Find new contact", isPresented: $showNewChat) {
                TextField("username", text: $newContact)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Start") {
                    let contact = newContact.trimmingCharacters(in: .whitespaces)
                    if !contact.isEmpty {
                        appState.conversations[contact] = appState.conversations[contact] ?? []
                        path.append(contact)
                    }
                    newContact = ""
                }
                Button("Cancel", role: .cancel) { newContact = "" }
            }
        }
    }
}
