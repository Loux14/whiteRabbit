import SwiftUI

let avatarSymbols: [String] = [
    "terminal.fill", "lock.shield.fill", "eye.fill", "bolt.fill",
    "flame.fill", "antenna.radiowaves.left.and.right", "wifi", "globe",
    "0.circle.fill", "1.circle.fill", "2.circle.fill", "3.circle.fill",
    "shield.fill", "key.fill", "person.fill", "cpu.fill"
]

// MARK: - Picker grid (used in RegisterView)

struct AvatarPickerView: View {
    @Binding var selected: Int

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<avatarSymbols.count, id: \.self) { i in
                    Button { selected = i } label: {
                        Image(systemName: avatarSymbols[i])
                            .font(.system(size: 32))
                            .foregroundStyle(selected == i ? Theme.background : Theme.primary)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(selected == i ? Theme.primary : Theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selected == i ? Theme.primary : Theme.border)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .frame(height: 280)
        .background(Theme.background)
    }
}

// MARK: - Small avatar display (used in lists/toolbars)

struct AvatarView: View {
    let index: Int
    let size: CGFloat

    var body: some View {
        let r = size * 0.2
        return Image(systemName: avatarSymbols[index % avatarSymbols.count])
            .font(.system(size: size * 0.45))
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: r).stroke(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: r))
    }
}
