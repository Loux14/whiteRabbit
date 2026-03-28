import SwiftUI

struct RegisterView: View {

    var isModal: Bool = false

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .username
    @State private var avatarIndex = 0
    @State private var pseudo = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private enum Step { case username, avatar }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.background.ignoresSafeArea()

            if isModal {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding()
                }
                .zIndex(1)
            }

            VStack(spacing: 24) {
                Spacer()

                Image("logo_rabbit")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)

                HStack(spacing: 0) {
                    Text("white")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(.white)
                    Text("Rabbit")
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .foregroundStyle(Theme.primary)
                }

                Text("post-quantum encrypted messaging")
                    .font(Theme.fontMonoCaption)
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                if step == .username {
                    usernameStep
                } else {
                    avatarStep
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Step 1: username

    @ViewBuilder
    private var usernameStep: some View {
        VStack(spacing: 12) {
            TextField("", text: $pseudo,
                      prompt: Text("username").foregroundColor(Theme.textSecondary))
                .font(Theme.fontMono)
                .foregroundStyle(Theme.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                step = .avatar
            } label: {
                Text("> next")
                    .font(Theme.fontMono.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.primary)
                    .foregroundStyle(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(pseudo.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
    }

    // MARK: - Step 2: avatar

    @ViewBuilder
    private var avatarStep: some View {
        VStack(spacing: 12) {
            AvatarPickerView(selected: $avatarIndex)

            if let error = errorMessage {
                Text(error)
                    .font(Theme.fontMonoSmall)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await register() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(Theme.background)
                    } else {
                        Text("> create account")
                            .font(Theme.fontMono.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.primary)
                .foregroundStyle(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isLoading)

            Button {
                step = .username
            } label: {
                Text("< back")
                    .font(Theme.fontMonoSmall)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Action

    private func register() async {
        isLoading = true
        errorMessage = nil
        do {
            try await appState.register(
                pseudo: pseudo.trimmingCharacters(in: .whitespaces),
                avatarIndex: avatarIndex
            )
            if isModal { dismiss() }
        } catch APIError.pseudoTaken {
            errorMessage = "username already taken."
        } catch {
            errorMessage = "error: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
