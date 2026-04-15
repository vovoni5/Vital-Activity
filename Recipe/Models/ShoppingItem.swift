import Foundation
import CoreData

// MARK: - ShoppingItem Model
struct ShoppingItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var quantity: Double
    var unit: QuantityUnit
    var isPurchased: Bool
    var category: String?
    
    init(id: UUID = UUID(), name: String, quantity: Double, unit: QuantityUnit, isPurchased: Bool = false, category: String? = nil) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.isPurchased = isPurchased
        self.category = category
    }
    
    init(from ingredient: Ingredient, category: String? = nil) {
        self.id = UUID()
        self.name = ingredient.name
        self.quantity = ingredient.quantity
        self.unit = ingredient.unit
        self.isPurchased = false
        self.category = category
    }
    
    var formattedQuantity: String {
        let formatted = UnitConverter.formatQuantity(quantity)
        return "\(formatted) \(unit.rawValue)"
    }
}

// MARK: - ShoppingItemEntity Extension
extension ShoppingItemEntity {
    var toShoppingItem: ShoppingItem? {
        guard let id = id, let name = name, let unitRaw = unit, let unit = QuantityUnit(rawValue: unitRaw) else {
            return nil
        }
        return ShoppingItem(
            id: id,
            name: name,
            quantity: quantity,
            unit: unit,
            isPurchased: isPurchased,
            category: category
        )
    }
    
    func update(from item: ShoppingItem) {
        id = item.id
        name = item.name
        quantity = item.quantity
        unit = item.unit.rawValue
        isPurchased = item.isPurchased
        category = item.category
    }
}

// MARK: - IngredientCategory
enum IngredientCategory: String, CaseIterable {
    case vegetables = "Овощи"
    case fruits = "Фрукты"
    case dairy = "Молочные продукты"
    case meat = "Мясо и птица"
    case fish = "Рыба и морепродукты"
    case grains = "Крупы и злаки"
    case spices = "Специи и приправы"
    case oils = "Масла и жиры"
    case sweets = "Сладости"
    case beverages = "Напитки"
    case other = "Прочее"
        
    static func categorize(_ ingredientName: String) -> IngredientCategory {
        let lowercased = ingredientName.lowercased()
        
        if lowercased.contains("помидор") || lowercased.contains("огурец") || lowercased.contains("морковь") ||
           lowercased.contains("картофель") || lowercased.contains("лук") || lowercased.contains("чеснок") ||
           lowercased.contains("перец") || lowercased.contains("капуста") || lowercased.contains("салат") {
            return .vegetables
        } else if lowercased.contains("яблоко") || lowercased.contains("банан") || lowercased.contains("апельсин") ||
                  lowercased.contains("лимон") || lowercased.contains("груша") || lowercased.contains("виноград") {
            return .fruits
        } else if lowercased.contains("молоко") || lowercased.contains("сыр") || lowercased.contains("творог") ||
                  lowercased.contains("йогурт") || lowercased.contains("сметана") || lowercased.contains("кефир") {
            return .dairy
        } else if lowercased.contains("куриц") || lowercased.contains("говядин") || lowercased.contains("свинин") ||
                  lowercased.contains("индейк") || lowercased.contains("фарш") || lowercased.contains("колбас") {
            return .meat
        } else if lowercased.contains("рыба") || lowercased.contains("лосось") || lowercased.contains("тунец") ||
                  lowercased.contains("креветк") || lowercased.contains("кальмар") || lowercased.contains("икра") {
            return .fish
        } else if lowercased.contains("рис") || lowercased.contains("гречк") || lowercased.contains("овес") ||
                  lowercased.contains("макарон") || lowercased.contains("хлеб") || lowercased.contains("мука") {
            return .grains
        } else if lowercased.contains("соль") || lowercased.contains("перец") || lowercased.contains("паприка") ||
                  lowercased.contains("кориандр") || lowercased.contains("лавровый") || lowercased.contains("укроп") ||
                  lowercased.contains("петрушка") || lowercased.contains("базилик") {
            return .spices
        } else if lowercased.contains("масло") || lowercased.contains("жир") || lowercased.contains("маргарин") {
            return .oils
        } else if lowercased.contains("сахар") || lowercased.contains("шоколад") || lowercased.contains("мед") ||
                  lowercased.contains("варенье") || lowercased.contains("печенье") || lowercased.contains("конфет") {
            return .sweets
        } else if lowercased.contains("вода") || lowercased.contains("сок") || lowercased.contains("чай") ||
                  lowercased.contains("кофе") || lowercased.contains("газировка") {
            return .beverages
        } else {
            return .other
        }
    }
}
???
