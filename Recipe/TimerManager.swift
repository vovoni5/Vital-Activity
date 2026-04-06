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
        }
        timerSubscription?.cancel()
        timerSubscription = nil
        // Не скрываем панель, чтобы отображать "Готово"
    }
    
    /// Переключает состояние паузы/возобновления активного таймера.
    func togglePause() {
        guard var timer = activeTimer else { return }
        timer.isRunning.toggle()
        activeTimer = timer
        timerStates[timer.stepID] = timer
        if timer.isRunning {
            startTimerIfNeeded()
        } else {
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
    }
    
    /// Закрывает панель таймера и сбрасывает таймер.
    func closePanel() {
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
            // Таймер завершился
            timer.isRunning = false
            activeTimer = timer
            timerStates[timer.stepID] = timer
            timerSubscription?.cancel()
            timerSubscription = nil
            // Воспроизвести звуковой сигнал
            playCompletionSound()
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
}