import SwiftUI

/// Панель активного таймера, отображаемая в нижней части экрана.
struct ActiveTimerPanel: View {
    @EnvironmentObject private var timerManager: TimerManager
    @State private var isVisible = false
    
    var body: some View {
        if let timer = timerManager.activeTimer, !timerManager.isTimerPanelHidden {
            TimerContainer {
                HStack(spacing: 12) {
                    // Иконка таймера
                    Image(systemName: "timer")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.accentPurple)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(timer.recipeTitle)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color("BrandTextColor"))
                            .lineLimit(1)
                        
                        Text(timer.stepAction)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Время
                    Text(timer.timeString)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(timer.isRunning ? AppColors.accentPink : .secondary)
                        .monospacedDigit()
                    
                    // Кнопки управления
                    HStack(spacing: 8) {
                        Button {
                            timerManager.togglePause()
                        } label: {
                            Image(systemName: timer.isRunning ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppColors.accentPurple)
                        }
                        
                        Button {
                            timerManager.reset()
                        } label: {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Крестик закрытия
                    Button {
                        timerManager.closePanel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                withAnimation(.spring()) {
                    isVisible = true
                }
            }
        }
    }
}

/// Модификатор для добавления панели активного таймера к любому View.
/// Панель отображается поверх контента внизу экрана, кроме страницы таймеров.
struct ActiveTimerPanelModifier: ViewModifier {
    @EnvironmentObject private var timerManager: TimerManager
    /// Флаг, указывающий, что текущий экран является экраном таймеров (панель скрыта).
    var isTimerScreen: Bool = false
    
    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            
            if !isTimerScreen, timerManager.activeTimer != nil, !timerManager.isTimerPanelHidden {
                ActiveTimerPanel()
                    .transition(.move(edge: .bottom))
            }
        }
    }
}

extension View {
    /// Добавляет панель активного таймера внизу экрана, если таймер запущен.
    /// - Parameter isTimerScreen: Установите `true`, если текущий экран является экраном таймеров (панель скрыта).
    func withActiveTimerPanel(isTimerScreen: Bool = false) -> some View {
        modifier(ActiveTimerPanelModifier(isTimerScreen: isTimerScreen))
    }
}
