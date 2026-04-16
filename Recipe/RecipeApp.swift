import SwiftUI
import CoreData
import UserNotifications
import UIKit

@main
struct RecipeApp: App {
    // Зависимости
    let persistenceController = PersistenceController.shared
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var notificationManager = NotificationManager.shared

    init() {
        // Настройка акцентного цвета (фиолетовый)
        let accent = UIColor(red: 0.47, green: 0.20, blue: 0.95, alpha: 1.0)
        UIView.appearance().tintColor = accent
        UINavigationBar.appearance().tintColor = accent
        UIBarButtonItem.appearance().tintColor = accent
        UITextField.appearance().tintColor = accent
        UITextView.appearance().tintColor = accent
        
        // Запрос разрешения на уведомления при первом запуске
        requestNotificationPermission()
        
        // Настройка обработчика нажатия на уведомление
        setupNotificationDelegate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(timerManager)
                .environmentObject(notificationManager)
                .onAppear {
                    // Проверка пропущенных таймеров при запуске
                    checkMissedTimers()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Проверка пропущенных таймеров при возвращении на передний план
                    checkMissedTimers()
                }
        }
    }
    
    private func requestNotificationPermission() {
        // Проверяем, запрашивали ли уже разрешение
        let hasRequestedKey = "hasRequestedNotificationPermission"
        let hasRequested = UserDefaults.standard.bool(forKey: hasRequestedKey)
        
        if !hasRequested {
            // Запрашиваем разрешение с небольшой задержкой, чтобы не блокировать запуск
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                notificationManager.requestAuthorization { granted in
                    if granted {
                        print("Разрешение на уведомления получено")
                    } else {
                        print("Пользователь отказал в разрешении на уведомления")
                    }
                    UserDefaults.standard.set(true, forKey: hasRequestedKey)
                }
            }
        }
    }
    
    private func setupNotificationDelegate() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared
    }
    
    private func checkMissedTimers() {
        notificationManager.checkMissedTimers { missedTimers in
            if !missedTimers.isEmpty {
                print("Обнаружены пропущенные таймеры: \(missedTimers)")
                // Здесь можно показать алерт пользователю
                // Например: "Вы пропустили завершение шага 'Варить макароны' в рецепте 'Паста карбонара'"
            }
        }
    }
}

// Делегат для обработки нажатия на уведомление
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let stepIDString = userInfo["stepID"] as? String,
           let stepID = UUID(uuidString: stepIDString),
           let recipeIDString = userInfo["recipeID"] as? String,
           let recipeIDURL = URL(string: recipeIDString),
           let type = userInfo["type"] as? String,
           type == "stepCompletion" {
            
            // Открываем экран рецепта с активным шагом
            openRecipeWithStep(recipeIDURL: recipeIDURL, stepID: stepID)
        }
        
        completionHandler()
    }
    
    private func openRecipeWithStep(recipeIDURL: URL, stepID: UUID) {
        // Здесь должна быть логика навигации к конкретному рецепту и шагу
        // В реальном приложении можно использовать Deep Linking или NotificationCenter
        print("Нажато уведомление: рецепт \(recipeIDURL), шаг \(stepID)")
        
        // Отправляем уведомление через NotificationCenter для обработки в UI
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenRecipeFromNotification"),
            object: nil,
            userInfo: ["recipeIDURL": recipeIDURL, "stepID": stepID]
        )
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Показываем уведомление даже когда приложение активно
        completionHandler([.banner, .sound, .badge])
    }
}
