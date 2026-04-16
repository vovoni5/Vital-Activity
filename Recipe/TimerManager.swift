import SwiftUI
import Combine
import CoreData
import AudioToolbox

/// Глобальный менеджер для отслеживания активного таймера приготовления.
/// Позволяет отображать активный таймер в нижней панели на всех экранах, кроме экрана таймеров.
final class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    /// Активный таймер шага приготовления.
    @Published var activeTimer: ActiveTimer?
    
    /// Флаг, указывающий, что активный таймер должен быть скрыт (пользователь закрыл панель).
    @Published var isTimerPanelHidden = false
    
    /// Словарь состояний всех таймеров по stepID.
    @Published var timerStates: [UUID: ActiveTimer] = [:]
    
    /// Структура, описывающая активный таймер.
    struct ActiveTimer: Identifiable {
        let id = UUID()
        let recipeTitle: String
        let stepAction: String
        let totalSeconds: Int
        var remainingSeconds: Int
        var isRunning: Bool
        let stepID: UUID
        let recipeID: NSManagedObjectID
        
        /// Форматированное оставшееся время в формате "мм:сс".
        var timeString: String {
            let m = remainingSeconds / 60
            let s = remainingSeconds % 60
            return String(format: "%02d:%02d", m, s)
        }
        
        /// Прогресс от 0.0 до 1.0.
        var progress: Double {
            guard totalSeconds > 0 else { return 0.0 }
            return 1.0 - Double(remainingSeconds) / Double(totalSeconds)
        }
        
        /// Флаг завершения таймера.
        var isDone: Bool {
            remainingSeconds == 0
        }
    }
    
    private var timerSubscription: Cancellable?
    private var notificationManager = NotificationManager.shared
    
    private init() {}
    
    /// Запускает или обновляет активный таймер.
    func setActiveTimer(recipeTitle: String, stepAction: String, totalSeconds: Int, remainingSeconds: Int, isRunning: Bool, stepID: UUID, recipeID: NSManagedObjectID) {
        let timer = ActiveTimer(
            recipeTitle: recipeTitle,
            stepAction: stepAction,
            totalSeconds: totalSeconds,
            remainingSeconds: remainingSeconds,
            isRunning: isRunning,
            stepID: stepID,
            recipeID: recipeID
        )
        activeTimer = timer
        timerStates[stepID] = timer
        isTimerPanelHidden = false
        
        // Планируем уведомление, если таймер запущен
        if isRunning && remainingSeconds > 0 {
            scheduleNotification(for: timer)
        } else {
            // Отменяем уведомление, если таймер не запущен
            cancelNotification(for: stepID, recipeID: recipeID)
        }
        
        startTimerIfNeeded()
    }
    
    /// Обновляет состояние таймера в словаре (без изменения активного таймера).
    func updateTimerState(_ timer: ActiveTimer) {
        timerStates[timer.stepID] = timer
    }
    
    /// Возвращает сохранённое состояние таймера для указанного stepID.
    func getTimerState(for stepID: UUID) -> ActiveTimer? {
        return timerStates[stepID]
    }
    
    /// Останавливает активный таймер и скрывает панель.
    func stopAndHide() {
        if var timer = activeTimer {
            timer.isRunning = false
            timerStates[timer.stepID] = timer
            activeTimer = timer // обновляем, но не обнуляем
            
            // Отменяем уведомление при остановке
            cancelNotification(for: timer.stepID, recipeID: timer.recipeID)
        }
        timerSubscription?.cancel()
        timerSubscription = nil
        // Не скрываем панель, чтобы отображать "Готово"
    }
    
    /// Переключает состояние паузы/возобновления активного таймера.
    func togglePause() {
        guard var timer = activeTimer else { return }
        let wasRunning = timer.isRunning
        timer.isRunning.toggle()
        activeTimer = timer
        timerStates[timer.stepID] = timer
        
        if timer.isRunning {
            // Возобновление: планируем уведомление
            scheduleNotification(for: timer)
            startTimerIfNeeded()
        } else {
            // Пауза: отменяем уведомление
            cancelNotification(for: timer.stepID, recipeID: timer.recipeID)
            timerSubscription?.cancel()
            timerSubscription = nil
        }
    }
    
    /// Сбрасывает активный таймер до начального времени.
    func reset() {
        guard var timer = activeTimer else { return }
        timer.remainingSeconds = timer.totalSeconds
        timer.isRunning = false
        activeTimer = timer
        timerStates[timer.stepID] = timer
        timerSubscription?.cancel()
        timerSubscription = nil
        
        // Отменяем уведомление при сбросе
        cancelNotification(for: timer.stepID, recipeID: timer.recipeID)
    }
    
    /// Закрывает панель таймера и сбрасывает таймер.
    func closePanel() {
        // Отменяем уведомление перед сбросом
        if let timer = activeTimer {
            cancelNotification(for: timer.stepID, recipeID: timer.recipeID)
        }
        reset()
        isTimerPanelHidden = true
    }
    
    /// Запускает тикер, если таймер активен и работает.
    private func startTimerIfNeeded() {
        guard let timer = activeTimer, timer.isRunning, timer.remainingSeconds > 0 else {
            timerSubscription?.cancel()
            timerSubscription = nil
            return
        }
        
        if timerSubscription == nil {
            timerSubscription = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.tick()
                }
        }
    }
    
    /// Уменьшает оставшееся время на одну секунду.
    private func tick() {
        guard var timer = activeTimer, timer.isRunning, timer.remainingSeconds > 0 else {
            timerSubscription?.cancel()
            timerSubscription = nil
            return
        }
        
        timer.remainingSeconds -= 1
        activeTimer = timer
        timerStates[timer.stepID] = timer
        
        if timer.remainingSeconds <= 0 {
            // Таймер завершился естественным образом
            timer.isRunning = false
            activeTimer = timer
            timerStates[timer.stepID] = timer
            timerSubscription?.cancel()
            timerSubscription = nil
            
            // Воспроизвести звуковой сигнал
            playCompletionSound()
            
            // Уведомление сработает автоматически по запланированному времени
            // Не отменяем его, так как оно должно показаться пользователю
            print("Таймер завершился естественно, уведомление должно сработать")
        }
    }
    
    /// Воспроизводит звук завершения таймера.
    private func playCompletionSound() {
        let soundID: SystemSoundID = 1057
        AudioServicesPlaySystemSound(soundID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            AudioServicesPlaySystemSound(soundID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AudioServicesPlaySystemSound(soundID)
        }
    }
    
    // MARK: - Управление уведомлениями
    
    /// Планирует уведомление о завершении шага.
    private func scheduleNotification(for timer: ActiveTimer) {
        notificationManager.scheduleStepNotification(
            stepAction: timer.stepAction,
            recipeTitle: timer.recipeTitle,
            durationSeconds: timer.remainingSeconds,
            stepID: timer.stepID,
            recipeID: timer.recipeID
        ) { success in
            if success {
                print("Уведомление успешно запланировано для шага '\(timer.stepAction)'")
            } else {
                print("Не удалось запланировать уведомление для шага '\(timer.stepAction)'")
            }
        }
    }
    
    /// Отменяет уведомление для указанного шага.
    private func cancelNotification(for stepID: UUID, recipeID: NSManagedObjectID) {
        notificationManager.cancelStepNotification(stepID: stepID, recipeID: recipeID)
    }
    
    /// Отменяет все уведомления для активного таймера.
    func cancelActiveTimerNotification() {
        guard let timer = activeTimer else { return }
        cancelNotification(for: timer.stepID, recipeID: timer.recipeID)
    }
    
    /// Обновляет уведомление при паузе/возобновлении таймера.
    private func updateNotificationForTimerState(_ timer: ActiveTimer) {
        if timer.isRunning && timer.remainingSeconds > 0 {
            // Перепланируем уведомление с новым временем
            cancelNotification(for: timer.stepID, recipeID: timer.recipeID)
            scheduleNotification(for: timer)
        } else {
            // Отменяем уведомление
            cancelNotification(for: timer.stepID, recipeID: timer.recipeID)
        }
    }
    
    /// Вызывается при паузе таймера - отменяет уведомление.
    func pauseTimer() {
        guard var timer = activeTimer else { return }
        timer.isRunning = false
        activeTimer = timer
        timerStates[timer.stepID] = timer
        timerSubscription?.cancel()
        timerSubscription = nil
        
        // Отменяем уведомление при паузе
        cancelNotification(for: timer.stepID, recipeID: timer.recipeID)
    }
    
    /// Вызывается при возобновлении таймера - перепланирует уведомление.
    func resumeTimer() {
        guard var timer = activeTimer else { return }
        timer.isRunning = true
        activeTimer = timer
        timerStates[timer.stepID] = timer
        
        // Планируем новое уведомление
        scheduleNotification(for: timer)
        
        startTimerIfNeeded()
    }
}