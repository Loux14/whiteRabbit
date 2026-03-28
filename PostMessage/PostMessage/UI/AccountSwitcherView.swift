import SwiftUI

struct AccountSwitcherView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showRegister = false
    @State private var editingProfile: UserProfile? = nil
    @State private var editingAvatarIndex = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                List {
                    ForEach(appState.profiles) { profile in
                        HStack(spacing: 12) {
                            AvatarView(index: profile.avatarIndex, size: 40)
                            Text(profile.pseudo)
                                .font(Theme.fontMono)
                                .foregroundStyle(Theme.primary)
                            Spacer()
                            if profile.id == appState.activeProfileId {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.primary)
                                    .font(Theme.fontMonoSmall)
                            } else if let count = appState.profileUnreadCounts[profile.id], count > 0 {
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task {
                                await appState.switchTo(profile)
                                dismiss()
                            }
                        }
                        .onLongPressGesture {
                            editingAvatarIndex = profile.avatarIndex
                            editingProfile = profile
                        }
                        .listRowBackground(Theme.background)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await appState.deleteProfile(profile) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("accounts")
                        .font(Theme.fontMono.bold())
                        .foregroundStyle(Theme.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showRegister = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
        }
        .sheet(item: $editingProfile) { profile in
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("choose avatar")
                        .font(Theme.fontMono.bold())
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                    AvatarPickerView(selected: $editingAvatarIndex)

                    Button {
                        appState.updateAvatar(for: profile.id, avatarIndex: editingAvatarIndex)
                        editingProfile = nil
                    } label: {
                        Text("> confirm")
                            .font(Theme.fontMono.bold())
                            .foregroundStyle(Theme.background)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showRegister) {
            RegisterView(isModal: true)
                .environmentObject(appState)
                .onDisappear {
                    if appState.isRegistered { dismiss() }
                }
        }
    }
}
