import SwiftUI
import CoreData
import UIKit

/// Детальный просмотр рецепта с ингредиентами, шагами и кнопкой запуска таймера.
struct RecipeDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var recipe: RecipeEntity

    @State private var showEditSheet = false

    var body: some View {
        ZStack {
            AppGradientBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    // Заголовок, ссылка и описание рецепта
                    VStack(spacing: 8) {
                        Text(recipe.title ?? "")
                            .primaryTitle()
                            .animatedText()
                            .accessibilityLabel("Название рецепта: \(recipe.title ?? "")")
                            .accessibilityAddTraits(.isHeader)

                        if let link = recipe.link, !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let displayText = link.truncatedLink(maxLength: 50)
                            // Пытаемся создать URL из строки, добавляем схему при необходимости
                            let url: URL? = {
                                if let url = URL(string: link) {
                                    return url
                                }
                                if !link.lowercased().hasPrefix("http://") && !link.lowercased().hasPrefix("https://") {
                                    return URL(string: "https://" + link)
                                }
                                return nil
                            }()
                            
                            Button {
                                if let url = url {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text(displayText)
                                    .font(Font(UIFont(name: AppFonts.subtitle, size: 16) ?? UIFont.systemFont(ofSize: 16)))
                                    .foregroundColor(.blue)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.plain)
                            .animatedText()
                            .accessibilityLabel("Ссылка на рецепт: \(link)")
                        }

                        if let desc = recipe.detailsText, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(desc)
                                .font(Font(UIFont(name: AppFonts.subtitle, size: 16) ?? UIFont.systemFont(ofSize: 16)))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .animatedText()
                                .accessibilityLabel("Описание рецепта: \(desc)")
                        }
                    }
                    .padding(.top, 18)
                    .accessibilityElement(children: .contain)

                    // Карточка ингредиентов
                    CardContainer {
                        VStack(spacing: 12) {
                            Text("Ингредиенты")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                                .accessibilityLabel("Ингредиенты")
                                .accessibilityAddTraits(.isHeader)

                            if recipe.ingredients.isEmpty {
                                Text("Добавьте ингредиенты в режиме редактирования")
                                    .secondaryText()
                                    .animatedText()
                                    .accessibilityLabel("Добавьте ингредиенты в режиме редактирования")
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(recipe.ingredients) { ing in
                                        IngredientReadOnlyRow(ingredient: ing)
                                    }
                                }
                                .accessibilityElement(children: .contain)
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)

                    // Карточка шагов с таймерами
                    CardContainer {
                        VStack(spacing: 12) {
                            Text("Таймер действий")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                                .accessibilityLabel("Таймер действий")
                                .accessibilityAddTraits(.isHeader)

                            if recipe.steps.isEmpty {
                                Text("Добавьте действия и время — тогда появятся таймеры")
                                    .secondaryText()
                                    .animatedText()
                                    .accessibilityLabel("Добавьте действия и время — тогда появятся таймеры")
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(recipe.steps) { step in
                                        StepReadOnlyRow(step: step)
                                    }
                                }
                                .accessibilityElement(children: .contain)
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)

                    // Кнопка запуска таймера приготовления
                    Button {
                        showTimer(for: recipe)
                    } label: {
                        Text("Приготовить")
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(PillButtonStyle())
                    .frame(maxWidth: 260)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                    .accessibilityLabel("Приготовить")
                    .accessibilityHint("Запускает таймеры для шагов приготовления этого рецепта")
                }
                .padding(.horizontal, 16)
                .screenAppear()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showEditSheet = true
                    }
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel("Редактировать рецепт")
                .accessibilityHint("Открывает форму редактирования этого рецепта")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddOrEditRecipeSheet(mode: .edit(existing: recipe)) { draft in
                recipe.title = draft.title
                recipe.link = draft.link
                recipe.detailsText = draft.detailsText
                recipe.category = draft.category.rawValue
                recipe.ingredients = draft.ingredients
                recipe.steps = draft.steps
                save()
            }
        }
    }

    /// Сохраняет изменения рецепта в Core Data.
    private func save() {
        do {
            try viewContext.save()
        } catch {
            ErrorHandler.handleCoreDataError(error, message: "Не удалось сохранить изменения рецепта")
        }
    }

    /// Отправляет уведомление для открытия таймера приготовления данного рецепта.
    private func showTimer(for recipe: RecipeEntity) {
        NotificationCenter.default.post(
            name: .openRecipeTimer,
            object: nil,
            userInfo: ["recipeObjectID": recipe.objectID]
        )
    }
}

/// Строка ингредиента в режиме чтения с отображением сохранённой единицы измерения.
private struct IngredientReadOnlyRow: View {
    let ingredient: Ingredient

    var body: some View {
        VStack(spacing: 10) {
            Text(ingredient.name)
                .recipeNameTitle()
                .accessibilityLabel("Ингредиент: \(ingredient.name)")

            Text(displayQuantity)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Количество: \(displayQuantity)")

            // Кнопка отображения единицы измерения (неактивна)
            Button {
                // Ничего не делаем — переключение отключено
            } label: {
                Text(ingredient.unit.rawValue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 90, height: 36, alignment: .center)
                    .multilineTextAlignment(.center)
                    .background(
                        LinearGradient(
                            colors: [AppColors.accentPurple, AppColors.accentPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityLabel("Единица измерения: \(ingredient.unit.rawValue)")
            .accessibilityHint("Переключение единиц измерения отключено в режиме просмотра")
        }
        .padding(.vertical, 6)
        .glassEffect(.clear.tint(.white.opacity(0.05)), in: .rect(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.09), radius: 3, x: -4, y: 4)
        .accessibilityElement(children: .contain)
    }

    /// Отображаемое количество в сохранённой единице измерения.
    private var displayQuantity: String {
        let formatted = UnitConverter.formatQuantity(ingredient.quantity, maxFractionDigits: 2)
        return "\(formatted) \(ingredient.unit.rawValue)"
    }
}

/// Строка шага приготовления в режиме чтения.
private struct StepReadOnlyRow: View {
    let step: CookingStep

    var body: some View {
        VStack(spacing: 6) {
            Text(step.action)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Действие: \(step.action)")

            Text("\(step.minutes) мин")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Время: \(step.minutes) минут")
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .glassEffect(.clear.tint(.white.opacity(0.6)), in: .rect(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.09), radius: 3, x: -4, y: 4)
        .accessibilityElement(children: .contain)
    }
}

extension Notification.Name {
    /// Уведомление для открытия таймера рецепта.
    static let openRecipeTimer = Notification.Name("openRecipeTimer")
}
