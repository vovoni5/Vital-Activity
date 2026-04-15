import Foundation

// MARK: - RecipeCategory
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

    // Значение для хранения в Core Data (без локализации)
    var storageValue: String {
        switch self {
        case .all: return "Все"
        default: return rawValue
        }
    }
}

// MARK: - Ingredient
struct Ingredient: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var quantity: Double
    var unit: QuantityUnit
    
    // Вычисляемое свойство для работы в граммах (обратная совместимость)
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
            // Пересчет граммов в текущую единицу измерения
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
    
    // Инициализатор для обратной совместимости (только граммы)
    init(id: UUID = UUID(), name: String, grams: Double) {
        self.id = id
        self.name = name
        self.quantity = grams
        self.unit = .grams
    }
    
    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit, grams
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        
        // Декодирование нового формата (quantity + unit) или старого (grams)
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

// MARK: - CookingStep
struct CookingStep: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var action: String
    var minutes: Int
}

// MARK: - QuantityUnit
enum QuantityUnit: String, CaseIterable, Identifiable, Codable {
    case grams = "г"
    case tbsp = "ст. л."
    case pieces = "шт"

    var id: String { rawValue }
}

// MARK: - UnitConverter
enum UnitConverter {
    // Коэффициенты конвертации
    static let gramsPerTbsp: Double = 15.0
    static let gramsPerPiece: Double = 50.0

    static func gramsToTbsp(_ grams: Double) -> Double {
        grams / gramsPerTbsp
    }

    static func tbspToGrams(_ tbsp: Double) -> Double {
        tbsp * gramsPerTbsp
    }

    static func gramsToPieces(_ grams: Double) -> Double {
        grams / gramsPerPiece
    }

    static func piecesToGrams(_ pieces: Double) -> Double {
        pieces * gramsPerPiece
    }

    // Форматирование количества для отображения
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

// MARK: - String Extension
extension String {
    // Обрезка ссылки для отображения (первая строка, ограничение длины)
    func truncatedLink(maxLength: Int = 50) -> String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        if firstLine.count > maxLength {
            let index = firstLine.index(firstLine.startIndex, offsetBy: maxLength - 3)
            return String(firstLine[..<index]) + "..."
        }
        return firstLine
    }
}
