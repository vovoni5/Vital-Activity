import SwiftUI

/// Черновик рецепта, используемый для создания или редактирования.
/// Содержит все поля, которые пользователь может редактировать в форме.
struct RecipeDraft: Equatable {
    var title: String = ""
    var link: String = ""
    var detailsText: String = ""
    var category: RecipeCategory = .all
    var ingredients: [Ingredient] = []
    var steps: [CookingStep] = []
}

/// Режим работы листа: создание нового рецепта или редактирование существующего.
enum AddEditMode {
    case create
    case edit(existing: RecipeEntity)
}

/// Лист для создания или редактирования рецепта.
/// Содержит форму с полями названия, описания, категории, ингредиентов и шагов с таймерами.
struct AddOrEditRecipeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: AddEditMode
    let onSave: (RecipeDraft) -> Void

    @State private var draft: RecipeDraft
    @State private var validationError: String?

    /// Инициализатор, подготавливающий черновик в зависимости от режима.
    /// - При создании используется пустой черновик.
    /// - При редактировании данные заполняются из переданного RecipeEntity.
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
                link: existing.link ?? "",
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
                            CenteredField(title: "Ссылка", text: $draft.link)
                            CenteredField(title: "Описание/Комментарий", text: $draft.detailsText, axis: .vertical)

                            VStack(spacing: 8) {
                                Text("Категория")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .multilineTextAlignment(.center)

                                Picker("Категория", selection: $draft.category) {
                                    ForEach(RecipeCategory.allCases) { cat in
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
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)

                            ForEach(Array(draft.ingredients.enumerated()), id: \.element.id) { index, ing in
                                IngredientEditorRow(ingredient: $draft.ingredients[index])
                                    .staggeredList(index: index, totalCount: draft.ingredients.count)
                            }

                            Button {
                                if draft.ingredients.count >= 50 {
                                    validationError = "Достигнут лимит ингредиентов (50)"
                                    return
                                }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    draft.ingredients.append(Ingredient(name: "", quantity: 0, unit: .grams))
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
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)

                            ForEach(Array(draft.steps.enumerated()), id: \.element.id) { index, step in
                                StepEditorRow(step: $draft.steps[index])
                                    .staggeredList(index: index, totalCount: draft.steps.count)
                            }
                            

                            Button {
                                if draft.steps.count >= 50 {
                                    validationError = "Достигнут лимит шагов (50)"
                                    return
                                }
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

                    if let error = validationError {
                        Text(error)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.accentPink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity)
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
                            let cleanedDraft = cleaned(draft)
                            if let error = validate(cleanedDraft) {
                                withAnimation {
                                    validationError = error
                                }
                                return
                            }
                            validationError = nil
                            print("AddOrEditRecipeSheet: сохранение рецепта '\(cleanedDraft.title)'")
                            onSave(cleanedDraft)
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
            .map { Ingredient(id: $0.id, name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), quantity: max(0, $0.quantity), unit: $0.unit) }
            .filter { !$0.name.isEmpty }
        out.steps = input.steps
            .map { CookingStep(id: $0.id, action: $0.action.trimmingCharacters(in: .whitespacesAndNewlines), minutes: max(1, $0.minutes)) }
            .filter { !$0.action.isEmpty }
        return out
    }

    private func validate(_ draft: RecipeDraft) -> String? {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return "Название рецепта не может быть пустым"
        }
        if trimmedTitle.count > 100 {
            return "Название слишком длинное (максимум 100 символов)"
        }
        if draft.ingredients.count > 50 {
            return "Слишком много ингредиентов (максимум 50)"
        }
        for ingredient in draft.ingredients {
            if ingredient.grams > 100_000 {
                return "Количество ингредиента \(ingredient.name) слишком большое (максимум 100 000 грамм)"
            }
        }
        if draft.steps.count > 50 {
            return "Слишком много шагов (максимум 50)"
        }
        for step in draft.steps {
            if step.minutes > 24 * 60 { // больше суток
                return "Время шага \(step.action) слишком большое (максимум 1440 минут)"
            }
        }
        return nil
    }
}

/// Поле ввода с центрированным заголовком и градиентной обводкой.
/// Используется для ввода названия рецепта, описания и других текстовых данных.
private struct CenteredField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
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
                .autocorrectionDisabled()
                .textInputAutocapitalization(.none)
                .textContentType(.none)
        }
    }
}

/// Строка редактирования ингредиента с возможностью переключения единиц измерения.
/// Позволяет ввести название и количество, а также переключаться между граммами, столовыми ложками и штуками.
private struct IngredientEditorRow: View {
    @Binding var ingredient: Ingredient
    @State private var unit: QuantityUnit
    @State private var quantityText: String = ""

    init(ingredient: Binding<Ingredient>) {
        self._ingredient = ingredient
        _unit = State(initialValue: ingredient.wrappedValue.unit)
    }

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
                .autocorrectionDisabled()
                .textInputAutocapitalization(.none)
                .textContentType(.none)

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
                .autocorrectionDisabled()
                .textInputAutocapitalization(.none)
                .textContentType(.none)

                Button {
                    toggleUnit()
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
            quantityText = ""
        }
        .onChange(of: quantityText) { _, newValue in
            if let value = parse(newValue) {
                // Сохраняем quantity в выбранной единице
                ingredient.quantity = value
                ingredient.unit = unit
            }
        }
        .onChange(of: ingredient.unit) { _, newUnit in
            // Если unit изменился извне (редко), синхронизируем
            unit = newUnit
        }
    }

    /// Отформатированное значение количества в текущей единице измерения.
    private var formattedDefault: String {
        let value = ingredient.unit == unit ? ingredient.quantity : convertedQuantity()
        if value == 0 { return "" }
        return format(value)
    }
    
    /// Конвертирует количество ингредиента в текущую единицу измерения.
    private func convertedQuantity() -> Double {
        let grams: Double
        switch ingredient.unit {
        case .grams:
            grams = ingredient.quantity
        case .tbsp:
            grams = UnitConverter.tbspToGrams(ingredient.quantity)
        case .pieces:
            grams = UnitConverter.piecesToGrams(ingredient.quantity)
        }
        switch unit {
        case .grams:
            return grams
        case .tbsp:
            return UnitConverter.gramsToTbsp(grams)
        case .pieces:
            return UnitConverter.gramsToPieces(grams)
        }
    }

    /// Переключает единицу измерения и конвертирует значение.
    private func toggleUnit() {
        let currentQuantity = parse(quantityText.isEmpty ? formattedDefault : quantityText) ?? ingredient.quantity
        let grams: Double
        switch unit {
        case .grams:
            grams = currentQuantity
        case .tbsp:
            grams = UnitConverter.tbspToGrams(currentQuantity)
        case .pieces:
            grams = UnitConverter.piecesToGrams(currentQuantity)
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            // цикл: граммы → ложки → штуки → граммы
            switch unit {
            case .grams:
                unit = .tbsp
            case .tbsp:
                unit = .pieces
            case .pieces:
                unit = .grams
            }
            
            // Вычисляем новое количество в новой единице
            let newQuantity: Double
            switch unit {
            case .grams:
                newQuantity = grams
            case .tbsp:
                newQuantity = UnitConverter.gramsToTbsp(grams)
            case .pieces:
                newQuantity = UnitConverter.gramsToPieces(grams)
            }
            quantityText = format(newQuantity)
            
            // Обновляем ингредиент
            ingredient.quantity = newQuantity
            ingredient.unit = unit
        }
    }

    /// Парсит строку в Double, заменяя запятую на точку.
    private func parse(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    /// Форматирует число в строку с ограничением дробных цифр.
    private func format(_ v: Double) -> String {
        UnitConverter.formatQuantity(v, maxFractionDigits: 2)
    }
}

/// Строка редактирования шага приготовления с полем действия и временем в минутах.
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
                .autocorrectionDisabled()
                .textInputAutocapitalization(.none)
                .textContentType(.none)
            
            Text("Время в минутах")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
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
            .autocorrectionDisabled()
            .textInputAutocapitalization(.none)
            .textContentType(.none)
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

