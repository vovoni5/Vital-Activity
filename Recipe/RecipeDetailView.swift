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
                    // Заголовок и описание рецепта
                    VStack(spacing: 8) {
                        Text(recipe.title ?? "")
                            .primaryTitle()
                            .animatedText()
                            .accessibilityLabel("Название рецепта: \(recipe.title ?? "")")
                            .accessibilityAddTraits(.isHeader)

                        if let desc = recipe.detailsText, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            TextWithLinks(
                                text: desc,
                                uiFont: UIFont(name: AppFonts.subtitle, size: 16) ?? UIFont.systemFont(ofSize: 16),
                                color: AppColors.textSecondary,
                                alignment: .center
                            )
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
                                .foregroundColor(AppColors.textPrimary)
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
                                .foregroundColor(AppColors.textPrimary)
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

/// Строка ингредиента в режиме чтения с переключением единиц измерения.
private struct IngredientReadOnlyRow: View {
    let ingredient: Ingredient
    @State private var unit: QuantityUnit = .grams

    var body: some View {
        VStack(spacing: 10) {
            Text(ingredient.name)
                .recipeNameTitle()
                .accessibilityLabel("Ингредиент: \(ingredient.name)")

            Text(displayQuantity)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Количество: \(displayQuantity)")

            // Кнопка переключения единиц измерения
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    switch unit {
                    case .grams:
                        unit = .tbsp
                    case .tbsp:
                        unit = .pieces
                    case .pieces:
                        unit = .grams
                    }
                }
            } label: {
                Text(unit.rawValue)
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
            .accessibilityLabel("Переключить единицу измерения")
            .accessibilityHint("Переключает между граммами, столовыми ложками и штуками")
        }
        .padding(.vertical, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .background(Color.white.opacity(0.45))
        .cornerRadius(18)
        .accessibilityElement(children: .contain)
    }

    /// Отображаемое количество в выбранной единице измерения.
    private var displayQuantity: String {
        let value: Double
        switch unit {
        case .grams:
            value = ingredient.grams
        case .tbsp:
            value = UnitConverter.gramsToTbsp(ingredient.grams)
        case .pieces:
            value = UnitConverter.gramsToPieces(ingredient.grams)
        }
        let formatted = UnitConverter.formatQuantity(value, maxFractionDigits: 2)
        return "\(formatted) \(unit.rawValue)"
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
        .background(Color.white.opacity(0.45))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

extension Notification.Name {
    /// Уведомление для открытия таймера рецепта.
    static let openRecipeTimer = Notification.Name("openRecipeTimer")
}
