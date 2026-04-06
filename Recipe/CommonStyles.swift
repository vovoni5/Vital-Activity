import SwiftUI

// MARK: - Общие стили

/// Стиль для основного заголовка с градиентным текста.
/// Применяет градиент от акцентного фиолетового к розовому.
struct PrimaryTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        let gradient = LinearGradient(
            colors: [AppColors.accentPurple, AppColors.accentPink],
            startPoint: .leading,
            endPoint: .trailing
        )

        return content
            .font(.custom(AppFonts.subtitle, size: 32, relativeTo: .title))
            .foregroundColor(.clear)
            .overlay(
                gradient.mask(
                    content
                        .font(.custom(AppFonts.subtitle, size: 32, relativeTo: .title))
                )
            )
            .multilineTextAlignment(.center)
    }
}

/// Стиль для вторичного текста.
/// Использует шрифт Optima и цвет textSecondary.
struct SecondaryTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom(AppFonts.subtitle, size: 16, relativeTo: .body))
            .foregroundColor(AppColors.textSecondary)
            .multilineTextAlignment(.center)
    }
}

/// Стиль для названия рецепта с градиентом.
/// Полупрозрачный градиент для карточек рецептов.
struct RecipeNameTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        let gradient = LinearGradient(
            colors: [AppColors.accentPink.opacity(0.0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        return content
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundColor(Color("BrandTextColor"))
            .overlay(
                gradient.mask(
                    content
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                )
            )
            .multilineTextAlignment(.center)
    }
}

/// Стиль для красивого текста с тенью.
/// Использует шрифт Apple Chancery и цвет cardBackground.
struct BeautifulTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        let gradient = LinearGradient(
            colors: [AppColors.cardBackground],
            startPoint: .leading,
            endPoint: .trailing
        )

        return content
            .font(.custom(AppFonts.apple, size: 30,  relativeTo: .title))
            .foregroundColor(.clear)
            .overlay(
                gradient.mask(
                    content
                        .font(.custom(AppFonts.apple, size: 30, relativeTo: .title))
                )
            )
            .multilineTextAlignment(.center)
            .shadow(color: Color.black.opacity(0.3), radius: 1, x: 1, y: 1)
    }
}

// MARK: - Анимации появления

/// Модификатор для плавного появления экрана.
/// Плавное изменение прозрачности и смещения.
struct ScreenAppearModifier: ViewModifier {
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.easeOut(duration: 0.35), value: isVisible)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35)) {
                    isVisible = true
                }
            }
            .onDisappear {
                withAnimation(.easeOut(duration: 0.25)) {
                    isVisible = false
                }
            }
    }
}

/// Модификатор для плавного появления текста.
/// Легкое масштабирование и изменение прозрачности.
struct TextAppearModifier: ViewModifier {
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.9)
            .offset(y: isVisible ? 0 : 10)
            .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.5), value: isVisible)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation {
                        isVisible = true
                    }
                }
            }
    }
}

// MARK: - Компоненты

/// Стиль кнопки в виде капсулы с градиентом.
/// Реагирует на нажатие анимацией масштаба и тени.
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let gradient = LinearGradient(
            colors: [
                AppColors.accentPurple,
                AppColors.accentPink
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        return configuration.label
            .font(.custom(AppFonts.title, size: 18, relativeTo: .body))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                gradient.opacity(0.6)
            )
            .cornerRadius(26)
            .shadow(color: AppColors.textPrimary.opacity(configuration.isPressed ? 0.08 : 0.4),
                    radius: configuration.isPressed ? 4 : 4,
                    x: 4,
                    y: configuration.isPressed ? 2 : 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// Стиль поля ввода с градиентной обводкой.
/// Белый фон с тонкой градиентной рамкой.
struct GradientInputFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        let gradient = LinearGradient(
            colors: [
                AppColors.accentPurple,
                AppColors.accentPink
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        return content
            .glassEffect(.regular.tint(.white.opacity(0.8)), in: .rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(gradient.opacity(0.3), lineWidth: 1.4)
            )
            .cornerRadius(18)
    }
}

/// Контейнер для карточек с закругленными углами, фоном и тенью.
/// Используется для визуального выделения блоков контента.
struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity)
            .glassEffect(.clear.tint(.white.opacity(0.0)), in: .rect(cornerRadius: 24))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 4, y: 2)
            .contentShape(Rectangle())
    }
}

/// Контейнер для таймеров с единым стилем (белый фон, тень, закругления).
struct TimerContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.tint(.orange.opacity(0.0)), in: .rect(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 4, y: 4)
    }
}

// MARK: - Расширения View

extension View {
    /// Применяет стиль основного заголовка.
    func primaryTitle() -> some View {
        modifier(PrimaryTitleStyle())
    }
    
    /// Применяет красивый стиль текста.
    func beautifultextstyle() -> some View {
        modifier(BeautifulTextStyle())
    }

    /// Применяет стиль вторичного текста.
    func secondaryText() -> some View {
        modifier(SecondaryTextStyle())
    }

    /// Применяет стиль названия рецепта.
    func recipeNameTitle() -> some View {
        modifier(RecipeNameTitleStyle())
    }

    /// Применяет анимацию появления экрана.
    func screenAppear() -> some View {
        modifier(ScreenAppearModifier())
    }

    /// Применяет анимацию появления текста.
    func animatedText() -> some View {
        modifier(TextAppearModifier())
    }

    /// Применяет стиль поля ввода с градиентной обводкой.
    func gradientInputField() -> some View {
        modifier(GradientInputFieldStyle())
    }
    
    /// Оборачивает контент в контейнер таймера (белый фон, тень, закругления).
    func timerContainer() -> some View {
        TimerContainer { self }
    }
}

