//
//  RecipeApp.swift
//  Recipe
//
//  Created by Владимир Косачев on 11.03.2026.
//

/// Главная точка входа приложения.
///
/// Содержит:
/// - Инициализацию Core Data стека (PersistenceController)
/// - Настройку глобальных цветов интерфейса (акцентный цвет для навигации, текстовых полей)
/// - Корневой View (ContentView) с передачей контекста Core Data
///
/// Файл: RecipeApp.swift
/// Модуль: Recipe
///

import SwiftUI
import CoreData

@main
struct RecipeApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        let accent = UIColor(red: 0.47, green: 0.20, blue: 0.95, alpha: 1.0)
        UINavigationBar.appearance().tintColor = accent
        UIBarButtonItem.appearance().tintColor = accent
        // Устанавливаем цвет курсора в текстовых полях
        UITextField.appearance().tintColor = accent
        UITextView.appearance().tintColor = accent
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
