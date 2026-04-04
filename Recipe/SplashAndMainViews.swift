import SwiftUI

// MARK: - Splash

/// Экран заставки с анимированным логотипом и приветственным текстом.
struct SplashView: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            AppGradientBackground()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("vital_activity_Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .shadow(color: AppColors.accentPurple.opacity(0.4), radius: 25, x: 0, y: 0)
                    .scaleEffect(glow ? 1.03 : 0.97)
                    .animation(
                        .easeInOut(duration: 1.4)
                            .repeatForever(autoreverses: true),
                        value: glow
                    )

                Text("Приготовим вместе")
                    .primaryTitle()
                    .animatedText()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            glow = true
        }
    }
}

// MARK: - Главное меню

/// Главный экран меню с навигацией по основным разделам приложения.
struct MainMenuView: View {
    var body: some View {
        ZStack {
            AppGradientBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("Vital Activity")
                            .beautifultextstyle()
                            .animatedText()

                        Text("Ваш помощник в рецептах")
                            .primaryTitle()
                            .animatedText()
                    }
                    .padding(.top, 32)

                    VStack(spacing: 18) {
                        NavigationLink {
                            RecipesBaseView()
                        } label: {
                            Text("База рецептов")
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(PillButtonStyle())

                        NavigationLink {
                            MenuPlannerListView()
                        } label: {
                            Text("Планировщик меню")
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(PillButtonStyle())

                        NavigationLink {
                            CookingTimerRootView()
                        } label: {
                            Text("Таймер готовки")
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(PillButtonStyle())
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .screenAppear()
            }
        }
        .navigationBarHidden(true)
        .withActiveTimerPanel(isTimerScreen: false)
    }
}

#Preview {
    NavigationStack {
        MainMenuView()
    }
}

