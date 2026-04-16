import SwiftUI
import Combine
import UserNotifications
import CoreData

/// Менеджер для работы с локальными уведомлениями о готовности шагов приготовления.
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private init() {
        updateAuthorizationStatus()
    }
    
    /// Запрашивает разрешение на отправку уведомлений.
    /// Должен вызываться при первом запуске приложения.
    func requestAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Ошибка при запросе разрешения на уведомления: \(error.localizedDescription)")
                }
                self.updateAuthorizationStatus()
                completion(granted)
            }
        }
    }
    
    /// Проверяет, разрешены ли уведомления.
    func checkAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                let isAuthorized = settings.authorizationStatus == .authorized
                completion(isAuthorized)
            }
        }
    }
    
    /// Обновляет статус авторизации.
    private func updateAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    /// Создает и планирует уведомление о готовности шага.
    /// - Parameters:
    ///   - stepAction: Описание действия шага (например, "Варить макароны")
    ///   - recipeTitle: Название рецепта
    ///   - durationSeconds: Длительность шага в секундах
    ///   - stepID: Уникальный идентификатор шага
    ///   - recipeID: Идентификатор рецепта (NSManagedObjectID)
    ///   - completion: Замыкание с результатом (успех/ошибка)
    func scheduleStepNotification(
        stepAction: String,
        recipeTitle: String,
        durationSeconds: Int,
        stepID: UUID,
        recipeID: NSManagedObjectID,
        completion: @escaping (Bool) -> Void = { _ in }
    ) {
        checkAuthorizationStatus { isAuthorized in
            guard isAuthorized else {
                print("Уведомления не разрешены. Пропускаем планирование.")
                completion(false)
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "Шаг готов!"
            content.body = "«\(stepAction)» завершён. Пора переходить к следующему этапу приготовления «\(recipeTitle)»."
            content.sound = .default
            content.userInfo = [
                "stepID": stepID.uuidString,
                "recipeID": recipeID.uriRepresentation().absoluteString,
                "type": "stepCompletion"
            ]
            
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(durationSeconds),
                repeats: false
            )
            
            let identifier = self.notificationIdentifier(for: stepID, recipeID: recipeID)
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Ошибка при планировании уведомления: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("Уведомление запланировано: \(identifier) через \(durationSeconds) секунд")
                        
                        // Для длинных таймеров (>1 часа) сохраняем информацию для резервного механизма
                        if durationSeconds > 3600 {
                            self.saveTimerBackupInfo(
                                stepID: stepID,
                                recipeID: recipeID,
                                endTime: Date().addingTimeInterval(TimeInterval(durationSeconds)),
                                stepAction: stepAction,
                                recipeTitle: recipeTitle
                            )
                        }
                        
                        completion(true)
                    }
                }
            }
        }
    }
    
    /// Отменяет запланированное уведомление для указанного шага.
    func cancelStepNotification(stepID: UUID, recipeID: NSManagedObjectID) {
        let identifier = notificationIdentifier(for: stepID, recipeID: recipeID)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("Уведомление отменено: \(identifier)")
        
        // Удаляем резервную информацию, если есть
        removeTimerBackupInfo(stepID: stepID)
    }
    
    /// Отменяет все уведомления, связанные с рецептом.
    func cancelAllNotificationsForRecipe(recipeID: NSManagedObjectID) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let recipeIDString = recipeID.uriRepresentation().absoluteString
            let identifiersToRemove = requests.filter { request in
                if let userInfoRecipeID = request.content.userInfo["recipeID"] as? String {
                    return userInfoRecipeID == recipeIDString
                }
                return false
            }.map { $0.identifier }
            
            if !identifiersToRemove.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                print("Отменены все уведомления для рецепта: \(identifiersToRemove.count) шт.")
            }
        }
    }
    
    /// Отменяет все запланированные уведомления приложения.
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("Все уведомления отменены")
    }
    
    /// Генерирует уникальный идентификатор уведомления.
    private func notificationIdentifier(for stepID: UUID, recipeID: NSManagedObjectID) -> String {
        let recipeIDString = recipeID.uriRepresentation().absoluteString
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return "step_\(stepID.uuidString)_recipe_\(recipeIDString)"
    }
    
    // MARK: - Резервный механизм для длинных таймеров
    
    private let backupUserDefaultsKey = "timerBackupInfo"
    
    /// Сохраняет информацию о таймере для восстановления в случае потери уведомления.
    private func saveTimerBackupInfo(
        stepID: UUID,
        recipeID: NSManagedObjectID,
        endTime: Date,
        stepAction: String,
        recipeTitle: String
    ) {
        var backupInfo = UserDefaults.standard.dictionary(forKey: backupUserDefaultsKey) ?? [:]
        
        let info: [String: Any] = [
            "stepID": stepID.uuidString,
            "recipeID": recipeID.uriRepresentation().absoluteString,
            "endTime": endTime.timeIntervalSince1970,
            "stepAction": stepAction,
            "recipeTitle": recipeTitle,
            "savedAt": Date().timeIntervalSince1970
        ]
        
        backupInfo[stepID.uuidString] = info
        UserDefaults.standard.set(backupInfo, forKey: backupUserDefaultsKey)
    }
    
    /// Удаляет резервную информацию о таймере.
    private func removeTimerBackupInfo(stepID: UUID) {
        var backupInfo = UserDefaults.standard.dictionary(forKey: backupUserDefaultsKey) ?? [:]
        backupInfo.removeValue(forKey: stepID.uuidString)
        UserDefaults.standard.set(backupInfo, forKey: backupUserDefaultsKey)
    }
    
    /// Проверяет, не должен ли был сработать какой-либо таймер, и показывает напоминание.
    /// Должен вызываться при запуске приложения.
    func checkMissedTimers(completion: @escaping ([(stepAction: String, recipeTitle: String)]) -> Void) {
        let backupInfo = UserDefaults.standard.dictionary(forKey: backupUserDefaultsKey) ?? [:]
        let now = Date()
        var missedTimers: [(String, String)] = []
        
        for (_, value) in backupInfo {
            guard let info = value as? [String: Any],
                  let endTimeInterval = info["endTime"] as? TimeInterval,
                  let stepAction = info["stepAction"] as? String,
                  let recipeTitle = info["recipeTitle"] as? String else {
                continue
            }
            
            let endTime = Date(timeIntervalSince1970: endTimeInterval)
            if endTime <= now {
                missedTimers.append((stepAction, recipeTitle))
            }
        }
        
        completion(missedTimers)
    }
    
    /// Очищает все резервные данные.
    func clearAllBackupInfo() {
        UserDefaults.standard.removeObject(forKey: backupUserDefaultsKey)
    }
    
    // MARK: - Вспомогательные методы
    
    /// Показывает список всех запланированных уведомлений (для отладки).
    func listPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests)
            }
        }
    }
}