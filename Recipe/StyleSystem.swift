import SwiftUI

// MARK: - Цвета и шрифты

/// Цветовая палитра приложения.
struct AppColors {
    /// Акцентный розовый цвет.
    static let accentPink = Color(red: 0.95, green: 0.25, blue: 0.65)
    /// Акцентный фиолетовый цвет.
    static let accentPurple = Color(red: 0.47, green: 0.20, blue: 0.95)
    /// Мягкий белый с небольшой прозрачностью.
    static let softWhite = Color.white.opacity(0.95)
    /// Основной цвет текста.
    static let textPrimary = Color(red: 0.16, green: 0.11, blue: 0.25)
    /// Вторичный цвет текста.
    static let textSecondary = Color(red: 0.38, green: 0.32, blue: 0.52)
    /// Фон карточек.
    static let cardBackground = Color.white.opacity(0.96)
    /// Обводка карточек.
    static let cardStroke = Color.white.opacity(0.6)
    /// Цвет для полей ввода и декоративных элементов.
    static let textPole = Color(red: 0.80, green: 0.75, blue: 0.88)
    /// Цвет текста в действиях свайпа.
    static let swipeActionText = Color(red: 0.80, green: 0.75, blue: 0.88)
}

/// Шрифты, используемые в приложении.
enum AppFonts {
    /// Декоративный шрифт Apple Chancery.
    static let apple = "Apple Chancery"
    /// Шрифт для заголовков.
    static let title = "Montserrat Alternates"
    /// Шрифт для подзаголовков.
    static let subtitle = "Optima"
    /// Шрифт для кнопок.
    static let button = "Hero"
    /// Шрифт для чипов (категорий).
    static let chip = "Kreadon"
    /// Шрифт для числовых значений.
    static let numeric = "Geoform"
}

/// Фон с многослойным градиентом и текстурой.
/// Используется как фон для большинства экранов.
struct AppGradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.softWhite,
                    Color(red: 0.99, green: 0.88, blue: 1.0),
                    Color(red: 0.96, green: 0.78, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.accentPurple.opacity(0.55),
                    .clear
                ]),
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )

            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.accentPink.opacity(0.55),
                    .clear
                ]),
                center: .bottomLeading,
                startRadius: 60,
                endRadius: 420
            )
            Image("white-abstract-texture-background")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .opacity(0.1)
        }
        .background(Color.white)
    }
}
