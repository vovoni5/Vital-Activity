import SwiftUI

struct RecipeDraft: Equatable {
    var title: String = ""
    var detailsText: String = ""
    var category: RecipeCategory = .breakfast
    var ingredients: [Ingredient] = []
    var steps: [CookingStep] = []
}

enum AddEditMode {
    case create
    case edit(existing: RecipeEntity)
}

struct AddOrEditRecipeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: AddEditMode
    let onSave: (RecipeDraft) -> Void

    @State private var draft: RecipeDraft

    init(mode: AddEditMode, onSave: @escaping (RecipeDraft) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _draft = State(initialValue: RecipeDraft())
        case .edit(let existing):
            var cat: RecipeCategory = .breakfast
            if let found = RecipeCategory.allCases.first(where: { $0.rawValue == existing.category }) {
                cat = found
            }
            _draft = State(initialValue: RecipeDraft(
                title: existing.title ?? "",
                detailsText: existing.detailsText ?? "",
                category: cat,
                ingredients: existing.ingredients,
                steps: existing.steps
            ))
        }
    }

    var body: some View {
        ZStack {
            AppGradientBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    Text(modeTitle)
                        .primaryTitle()
                        .animatedText()
                        .padding(.top, 18)

                    CardContainer {
                        VStack(spacing: 12) {
                            CenteredField(title: "Название", text: $draft.title)
                            CenteredField(title: "Описание/Ссылка", text: $draft.detailsText, axis: .vertical)

                            VStack(spacing: 8) {
                                Text("Категория")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .multilineTextAlignment(.center)

                                Picker("Категория", selection: $draft.category) {
                                    ForEach(RecipeCategory.allCases.filter { $0 != .all }) { cat in
                                        Text(cat.rawValue).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }

                    CardContainer {
                        VStack(spacing: 12) {
                            Text("Ингредиенты")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)

                            ForEach($draft.ingredients) { $ing in
                                IngredientEditorRow(ingredient: $ing)
                            }

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    draft.ingredients.append(Ingredient(name: "", grams: 0))
                                }
                            } label: {
                                Text("Добавить ингредиент")
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                            }
                            .buttonStyle(PillButtonStyle())
                        }
                    }

                    CardContainer {
                        VStack(spacing: 12) {
                            Text("Таймер действий")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)

                            ForEach($draft.steps) { $step in
                                StepEditorRow(step: $step)
                            }
                            

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    draft.steps.append(CookingStep(action: "", minutes: 1))
                                }
                            } label: {
                                Text("Добавить действие")
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                            }
                            .buttonStyle(PillButtonStyle())
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Отмена")
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(PillButtonStyle())

                        Button {
                            onSave(cleaned(draft))
                            dismiss()
                        } label: {
                            Text("Сохранить")
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(PillButtonStyle())
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
                .screenAppear()
            }
        }
    }

    private var modeTitle: String {
        switch mode {
        case .create: return "Новый рецепт"
        case .edit: return "Редактирование"
        }
    }

    private func cleaned(_ input: RecipeDraft) -> RecipeDraft {
        var out = input
        out.title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        out.detailsText = input.detailsText.trimmingCharacters(in: .whitespacesAndNewlines)
        out.ingredients = input.ingredients
            .map { Ingredient(id: $0.id, name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), grams: max(0, $0.grams)) }
            .filter { !$0.name.isEmpty }
        out.steps = input.steps
            .map { CookingStep(id: $0.id, action: $0.action.trimmingCharacters(in: .whitespacesAndNewlines), minutes: max(1, $0.minutes)) }
            .filter { !$0.action.isEmpty }
        return out
    }
}

private struct CenteredField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            TextField("", text: $text, axis: axis)
                .textFieldStyle(.plain)
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .gradientInputField()
        }
    }
}

private struct IngredientEditorRow: View {
    @Binding var ingredient: Ingredient
    @State private var unit: QuantityUnit = .grams
    @State private var quantityText: String = ""

    var body: some View {
        VStack(spacing: 10) {
            TextField("", text: $ingredient.name, prompt: Text("Название ингредиента").foregroundColor(AppColors.textPole))
                .textFieldStyle(.plain)
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .gradientInputField()

            HStack(spacing: 10) {
                TextField("", text: Binding(
                    get: { quantityText.isEmpty ? formattedDefault : quantityText },
                    set: { quantityText = $0 }
                ), prompt: Text("Кол-во").foregroundColor(AppColors.textPole))
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .gradientInputField()

                Button {
                    toggleUnitAndConvert()
                } label: {
                    Text(unit.rawValue)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 44, alignment: .center)
                        .multilineTextAlignment(.center)
                        .background(
                            LinearGradient(
                                colors: [AppColors.accentPink, AppColors.accentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            unit = .grams
            quantityText = ""
        }
        .onChange(of: quantityText) { _, newValue in
            if let value = parse(newValue) {
                ingredient.grams = unit == .grams ? value : UnitConverter.tbspToGrams(value)
            }
        }
    }

    private var formattedDefault: String {
        let base = ingredient.grams
        let value: Double
        switch unit {
        case .grams:
            value = base
        case .tbsp:
            value = UnitConverter.gramsToTbsp(base)
        case .pieces:
            value = UnitConverter.gramsToPieces(base)
        }
        if value == 0 { return "" }
        return format(value)
    }

    private func toggleUnitAndConvert() {
        let currentValue: Double
        if let parsed = parse(quantityText.isEmpty ? formattedDefault : quantityText) {
            currentValue = parsed
        } else {
            // берём значение из хранимых граммов
            switch unit {
            case .grams:
                currentValue = ingredient.grams
            case .tbsp:
                currentValue = UnitConverter.gramsToTbsp(ingredient.grams)
            case .pieces:
                currentValue = UnitConverter.gramsToPieces(ingredient.grams)
            }
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            // цикл: граммы → ложки → штуки → граммы
            switch unit {
            case .grams:
                unit = .tbsp
                quantityText = format(UnitConverter.gramsToTbsp(ingredient.grams))
            case .tbsp:
                unit = .pieces
                let grams = UnitConverter.tbspToGrams(currentValue)
                quantityText = format(UnitConverter.gramsToPieces(grams))
            case .pieces:
                unit = .grams
                let grams = UnitConverter.piecesToGrams(currentValue)
                quantityText = format(grams)
            }
        }

        if let value = parse(quantityText) {
            switch unit {
            case .grams:
                ingredient.grams = value
            case .tbsp:
                ingredient.grams = UnitConverter.tbspToGrams(value)
            case .pieces:
                ingredient.grams = UnitConverter.piecesToGrams(value)
            }
        }
    }

    private func parse(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    private func format(_ v: Double) -> String {
        let rounded = (v * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(rounded)
    }
}

private struct StepEditorRow: View {
    @Binding var step: CookingStep
    @State private var minutesText: String = ""

    var body: some View {
        VStack(spacing: 10) {
            TextField("", text: $step.action, prompt: Text("Опишите действие").foregroundColor(AppColors.textPole))
                .textFieldStyle(.plain)
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .gradientInputField()
            
            Text("Время в минутах")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            TextField("", text: Binding(
                get: { minutesText.isEmpty ? (step.minutes > 0 ? "\(step.minutes)" : "") : minutesText },
                set: { minutesText = $0 }
            ))
            .keyboardType(.numberPad)
            .textFieldStyle(.plain)
            .foregroundColor(AppColors.textPrimary)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .gradientInputField()
            .onChange(of: minutesText) { _, newValue in
                if let value = Int(newValue), value > 0 {
                    step.minutes = value
                }
            }
        }
    }
}

#Preview {
    AddOrEditRecipeSheet(mode: .create) { _ in }
}

