import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Image("logo_rabbit")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
        }
    }
}
