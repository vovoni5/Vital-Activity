import SwiftUI
import CoreData
import AudioToolbox
import Combine

/// Корневой экран таймеров готовки.
/// Отображает список всех рецептов для выбора, после выбора открывается экран с таймерами шагов.
struct CookingTimerRootView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecipeEntity.title, ascending: true)],
        animation: .default
    )
    private var recipes: FetchedResults<RecipeEntity>

    var body: some View {
        ZStack {
            AppGradientBackground().ignoresSafeArea()

            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("Таймер готовки")
                        .primaryTitle()
                        .animatedText()
                    Text("Выберите рецепт — откроются таймеры по действиям")
                        .secondaryText()
                        .animatedText()
                }
                .padding(.top, 18)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(recipes.enumerated()), id: \.element.objectID) { index, recipe in
                            NavigationLink {
                                CookingTimerRecipeView(recipe: recipe)
                            } label: {
                                CardContainer {
                                    Text(recipe.title ?? "")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color("BrandTextColor"))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .buttonStyle(.plain)
                            .staggeredList(index: index, totalCount: recipes.count)
                        }

                        if recipes.isEmpty {
                            CardContainer {
                                VStack(spacing: 8) {
                                    Text("Нет рецептов")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .multilineTextAlignment(.center)
                                    Text("Сначала добавьте рецепты в базе")
                                        .secondaryText()
                                        .animatedText()
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .screenAppear()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .withActiveTimerPanel(isTimerScreen: false)
    }
}

/// Экран таймеров для конкретного рецепта.
/// Управляет состоянием таймеров для каждого шага приготовления, обновляет их каждую секунду и воспроизводит звук по завершении.
struct CookingTimerRecipeView: View {
    @ObservedObject var recipe: RecipeEntity
    @EnvironmentObject private var timerManager: TimerManager

    @State private var timers: [StepTimerState] = []
    @State private var timerSubscription: Cancellable?
    @State private var anyTimerRunning: Bool = false

    var body: some View {
        ZStack {
            AppGradientBackground().ignoresSafeArea()

            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text(recipe.title ?? "")
                        .primaryTitle()
                        .animatedText()
                    Text("Таймеры по действиям")
                        .secondaryText()
                        .animatedText()
                }
                .padding(.top, 18)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach($timers) { $timer in
                            StepTimerCard(
                                timer: $timer,
                                recipeTitle: recipe.title ?? "Рецепт",
                                recipeID: recipe.objectID,
                                onFinished: {
                                    playTripleBeep()
                                }
                            )
                            .onChange(of: timer.isRunning) { _, newValue in
                                updateTimerSubscription()
                            }
                        }

                        if timers.isEmpty {
                            CardContainer {
                                VStack(spacing: 8) {
                                    Text("Шагов нет")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor( .secondary)
                                        .frame(maxWidth: .infinity)
                                        .multilineTextAlignment(.center)
                                    Text("Добавьте действия и время в рецепте")
                                        .secondaryText()
                                        .animatedText()
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .screenAppear()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            resetTimers()
            updateTimerSubscription()
        }
        .onDisappear {
            timerSubscription?.cancel()
            timerSubscription = nil
        }
        .withActiveTimerPanel(isTimerScreen: true)
    }

    /// Сбрасывает таймеры на основе шагов рецепта.
    /// Восстанавливает сохранённое состояние из TimerManager, если оно есть.
    private func resetTimers() {
        timers = recipe.steps.map { step in
            if let saved = timerManager.getTimerState(for: step.id) {
                // Восстанавливаем состояние из сохранённого таймера
                return StepTimerState(
                    stepID: saved.stepID,
                    action: saved.stepAction,
                    totalSeconds: saved.totalSeconds,
                    remainingSeconds: saved.remainingSeconds,
                    isRunning: saved.isRunning,
                    isDone: saved.remainingSeconds <= 0
                )
            } else {
                // Создаём новый таймер с начальным состоянием
                return StepTimerState(stepID: step.id, action: step.action, totalSeconds: max(0, step.minutes) * 60)
            }
        }
    }

    /// Обновляет подписку на таймер в зависимости от того, есть ли запущенные таймеры.
    private func updateTimerSubscription() {
        let hasRunning = timers.contains { $0.isRunning && !$0.isDone }
        anyTimerRunning = hasRunning
        
        if hasRunning {
            if timerSubscription == nil {
                timerSubscription = Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        tickTimers()
                    }
            }
        } else {
            timerSubscription?.cancel()
            timerSubscription = nil
        }
    }

    /// Уменьшает оставшееся время у всех запущенных таймеров на одну секунду.
    private func tickTimers() {
        var anyStillRunning = false
        for idx in timers.indices {
            guard timers[idx].isRunning, !timers[idx].isDone else { continue }
            anyStillRunning = true
            timers[idx].remainingSeconds = max(0, timers[idx].remainingSeconds - 1)
            if timers[idx].remainingSeconds == 0 {
                timers[idx].isRunning = false
                timers[idx].isDone = true
                timers[idx].justFinishedToken = UUID()
            }
        }
        if !anyStillRunning {
            updateTimerSubscription()
        }
    }
}

/// Состояние таймера для одного шага приготовления.
/// Хранит идентификатор шага, действие, общее и оставшееся время, флаги запуска и завершения.
struct StepTimerState: Identifiable, Equatable {
    let id: UUID = UUID()
    let stepID: UUID
    var action: String
    var totalSeconds: Int
    var remainingSeconds: Int
    var isRunning: Bool
    var isDone: Bool
    var justFinishedToken: UUID?

    init(stepID: UUID, action: String, totalSeconds: Int) {
        self.stepID = stepID
        self.action = action
        self.totalSeconds = totalSeconds
        self.remainingSeconds = totalSeconds
        self.isRunning = false
        self.isDone = false
        self.justFinishedToken = nil
    }
    
    init(stepID: UUID, action: String, totalSeconds: Int, remainingSeconds: Int, isRunning: Bool, isDone: Bool) {
        self.stepID = stepID
        self.action = action
        self.totalSeconds = totalSeconds
        self.remainingSeconds = remainingSeconds
        self.isRunning = isRunning
        self.isDone = isDone
        self.justFinishedToken = nil
    }
}

/// Карточка таймера для отображения состояния одного шага.
/// Показывает действие, оставшееся время, две круглые кнопки управления (плей/пауза и сброс) и анимацию завершения.
private struct StepTimerCard: View {
    @Binding var timer: StepTimerState
    var recipeTitle: String
    var recipeID: NSManagedObjectID
    var onFinished: () -> Void
    @EnvironmentObject private var timerManager: TimerManager

    @State private var finishedPulse = false

    var body: some View {
        TimerContainer {
            VStack(spacing: 16) {
                Text(timer.action.isEmpty ? "Действие" : timer.action)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color("BrandTextColor"))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .animatedText()

                if timer.isDone {
                    Text("Готово!")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .scaleEffect(finishedPulse ? 1.03 : 0.98)
                        .opacity(finishedPulse ? 1.0 : 0.92)
                        .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: finishedPulse)
                        .onAppear { finishedPulse = true }
                        .transition(.opacity.combined(with: .scale))
                } else {
                    Text(timeString(timer.remainingSeconds))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(timer.isRunning ? AppColors.accentPink : .secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                        .transition(.opacity.combined(with: .scale))
                }

                // Две круглые кнопки
                HStack(spacing: 24) {
                    // Кнопка плей/пауза
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            if timer.isDone {
                                // При завершении таймера сбросить и запустить заново
                                resetTimer()
                                timer.isRunning = true
                                updateGlobalTimer()
                            } else {
                                timer.isRunning.toggle()
                                updateGlobalTimer()
                            }
                        }
                    } label: {
                        Image(systemName: timer.isDone ? "play.circle.fill" : (timer.isRunning ? "pause.circle.fill" : "play.circle.fill"))
                            .font(.system(size: 44))
                            .foregroundColor(timer.isDone ? .orange : AppColors.accentPurple)
                    }
                    .buttonStyle(.plain)

                    // Кнопка сброса
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            resetTimer()
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .disabled(timer.isDone && timer.remainingSeconds == timer.totalSeconds)
                }
                .padding(.top, 8)
            }
        }
        .onChange(of: timer.justFinishedToken) { _, newValue in
            if newValue != nil {
                withAnimation(.easeInOut(duration: 0.25)) {
                    // переход в состояние "Готово!" уже произошёл в родителе
                }
                onFinished()
                // Обновить глобальный таймер (остановить)
                timerManager.stopAndHide()
            }
        }
        .onChange(of: timer.isRunning) { _, newValue in
            updateGlobalTimer()
        }
        .onChange(of: timer.remainingSeconds) { _, newValue in
            updateGlobalTimer()
        }
    }

    /// Обновляет глобальный таймер в менеджере.
    private func updateGlobalTimer() {
        // Всегда обновляем состояние таймера в словаре
        let activeTimer = TimerManager.ActiveTimer(
            recipeTitle: recipeTitle,
            stepAction: timer.action,
            totalSeconds: timer.totalSeconds,
            remainingSeconds: timer.remainingSeconds,
            isRunning: timer.isRunning,
            stepID: timer.stepID,
            recipeID: recipeID
        )
        timerManager.updateTimerState(activeTimer)
        
        // Если таймер запущен и не завершён, устанавливаем его как активный в глобальном менеджере
        if timer.isRunning && !timer.isDone {
            timerManager.setActiveTimer(
                recipeTitle: recipeTitle,
                stepAction: timer.action,
                totalSeconds: timer.totalSeconds,
                remainingSeconds: timer.remainingSeconds,
                isRunning: true,
                stepID: timer.stepID,
                recipeID: recipeID
            )
        } else if timer.isDone || !timer.isRunning {
            // Если таймер остановлен или завершен, не обновляем глобальный активный таймер
            // (но состояние уже обновлено в словаре)
        }
    }

    /// Сбрасывает таймер в исходное состояние.
    private func resetTimer() {
        timer.remainingSeconds = timer.totalSeconds
        timer.isRunning = false
        timer.isDone = false
        timer.justFinishedToken = nil
        // Сбросить глобальный таймер, если этот таймер активен
        if timerManager.activeTimer?.stepID == timer.stepID {
            timerManager.reset()
        } else {
            // Обновить состояние в словаре
            updateGlobalTimer()
        }
    }

    /// Форматирует секунды в строку "мм:сс".
    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

/// Воспроизводит тройной звуковой сигнал при завершении таймера.
private func playTripleBeep() {
    let soundID: SystemSoundID = 1057
    AudioServicesPlaySystemSound(soundID)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
        AudioServicesPlaySystemSound(soundID)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        AudioServicesPlaySystemSound(soundID)
    }
}

#Preview {
    NavigationStack {
        CookingTimerRootView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

