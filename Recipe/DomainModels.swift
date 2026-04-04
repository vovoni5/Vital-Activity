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

/// Ингредиент рецепта с названием, количеством и единицей измерения.
struct Ingredient: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    /// Количество в выбранной единице измерения.
    var quantity: Double
    /// Единица измерения количества.
    var unit: QuantityUnit
    
    /// Количество в граммах (вычисляемое свойство для обратной совместимости).
    var grams: Double {
        get {
            switch unit {
            case .grams:
                return quantity
            case .tbsp:
                return UnitConverter.tbspToGrams(quantity)
            case .pieces:
                return UnitConverter.piecesToGrams(quantity)
            }
        }
        set {
            // При установке граммов пересчитываем quantity в текущей unit
            switch unit {
            case .grams:
                quantity = newValue
            case .tbsp:
                quantity = UnitConverter.gramsToTbsp(newValue)
            case .pieces:
                quantity = UnitConverter.gramsToPieces(newValue)
            }
        }
    }
    
    init(id: UUID = UUID(), name: String, quantity: Double, unit: QuantityUnit) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }
    
    /// Инициализатор для обратной совместимости со старыми данными (только граммы).
    init(id: UUID = UUID(), name: String, grams: Double) {
        self.id = id
        self.name = name
        self.quantity = grams
        self.unit = .grams
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit, grams
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        
        // Пытаемся декодировать quantity и unit (новый формат)
        if let quantity = try? container.decode(Double.self, forKey: .quantity),
           let unitRaw = try? container.decode(String.self, forKey: .unit),
           let unit = QuantityUnit(rawValue: unitRaw) {
            self.quantity = quantity
            self.unit = unit
        } else {
            // Старый формат: только граммы
            let grams = try container.decode(Double.self, forKey: .grams)
            self.quantity = grams
            self.unit = .grams
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unit.rawValue, forKey: .unit)
        // Для обратной совместимости также кодируем grams
        try container.encode(grams, forKey: .grams)
    }
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

extension String {
    /// Обрезает ссылку для отображения, оставляя только первую строку (до первого перевода строки) и ограничивая длину.
    /// Если ссылка многострочная, возвращается только первая строка.
    /// Если длина превышает maxLength, добавляется многоточие.
    func truncatedLink(maxLength: Int = 50) -> String {
        // Убираем пробелы и переносы строк по краям
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        // Берем первую строку
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        // Если длина превышает maxLength, обрезаем и добавляем многоточие
        if firstLine.count > maxLength {
            let index = firstLine.index(firstLine.startIndex, offsetBy: maxLength - 3)
            return String(firstLine[..<index]) + "..."
        }
        return firstLine
    }
}

