import Foundation

/// Категории рецептов, используемые для фильтрации и классификации.
enum RecipeCategory: String, CaseIterable, Identifiable {
    case all = "Все рецепты"
    case breakfast = "Завтраки"
    case soups = "Супы"
    case mains = "Основные блюда"
    case salads = "Салаты"
    case baking = "Выпечка"
    case desserts = "Десерты"
    case snacks = "Закуски"

    var id: String { rawValue }

    /// Значение для хранения в Core Data (без локализации).
    var storageValue: String {
        switch self {
        case .all: return "Все"
        default: return rawValue
        }
    }
}

/// Ингредиент рецепта с названием и количеством в граммах.
struct Ingredient: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    /// Значение хранится в граммах (база), конвертация только для отображения.
    var grams: Double
}

/// Шаг приготовления с описанием действия и временем в минутах.
struct CookingStep: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var action: String
    var minutes: Int
}

/// Единицы измерения количества ингредиентов.
enum QuantityUnit: String, CaseIterable, Identifiable {
    case grams = "г"
    case tbsp = "ст. л."
    case pieces = "шт"

    var id: String { rawValue }
}

/// Конвертер единиц измерения для ингредиентов.
enum UnitConverter {
    /// Универсальная бытовая конверсия: 1 столовая ложка ≈ 15 г.
    static let gramsPerTbsp: Double = 15.0

    /// Условная бытовая конверсия для штук (например, среднего продукта) — 1 шт ≈ 50 г.
    static let gramsPerPiece: Double = 50.0

    /// Конвертирует граммы в столовые ложки.
    static func gramsToTbsp(_ grams: Double) -> Double {
        grams / gramsPerTbsp
    }

    /// Конвертирует столовые ложки в граммы.
    static func tbspToGrams(_ tbsp: Double) -> Double {
        tbsp * gramsPerTbsp
    }

    /// Конвертирует граммы в штуки.
    static func gramsToPieces(_ grams: Double) -> Double {
        grams / gramsPerPiece
    }

    /// Конвертирует штуки в граммы.
    static func piecesToGrams(_ pieces: Double) -> Double {
        pieces * gramsPerPiece
    }

    /// Форматирует количество для отображения, убирая лишние нули.
    static func formatQuantity(_ value: Double, maxFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = ""
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

