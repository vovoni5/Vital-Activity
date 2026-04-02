import Foundation
import CoreData

/// Утилиты для кодирования и декодирования данных в Core Data.
enum DataCoding {
    /// Кодирует значение в Data с помощью JSONEncoder.
    static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    /// Декодирует Data в значение указанного типа.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

extension RecipeEntity {
    /// Массив ингредиентов рецепта, сериализованный в ingredientsData.
    var ingredients: [Ingredient] {
        get { DataCoding.decode([Ingredient].self, from: ingredientsData) ?? [] }
        set { ingredientsData = DataCoding.encode(newValue) }
    }

    /// Массив шагов приготовления, сериализованный в stepsData.
    var steps: [CookingStep] {
        get { DataCoding.decode([CookingStep].self, from: stepsData) ?? [] }
        set { stepsData = DataCoding.encode(newValue) }
    }
}

extension MealPlanEntity {
    /// Массив идентификаторов рецептов, сериализованный в recipeIDsData.
    var recipeIDs: [UUID] {
        get { DataCoding.decode([UUID].self, from: recipeIDsData) ?? [] }
        set { recipeIDsData = DataCoding.encode(newValue) }
    }
}

