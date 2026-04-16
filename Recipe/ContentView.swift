import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showSplash: Bool = true
    @State private var showMain: Bool = false
    @State private var pendingRecipeObjectID: NSManagedObjectID?
    @State private var notificationStepID: UUID?
    @State private var notificationRecipeIDURL: URL?

    var body: some View {
        ZStack {
            AppGradientBackground()

            if showSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale))
            }

            if showMain {
                NavigationStack {
                    MainMenuView()
                        .navigationDestination(
                            isPresented: Binding(
                                get: { pendingRecipeObjectID != nil },
                                set: { isActive in
                                    if !isActive {
                                        pendingRecipeObjectID = nil
                                        notificationStepID = nil
                                        notificationRecipeIDURL = nil
                                    }
                                }
                            )
                        ) {
                            destinationTimerView()
                        }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environment(\.managedObjectContext, viewContext)
        .ignoresSafeArea()
        .onAppear {
            // Анимация появления сплеш-экрана
            withAnimation(.easeOut(duration: 0.5)) {
                showSplash = true
            }

            // Через 2 секунды скрываем сплеш и показываем главное меню
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
                withAnimation(.easeInOut(duration: 0.5).delay(0.1)) {
                    showMain = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRecipeTimer)) { notif in
            // Обработка уведомления для открытия таймера рецепта
            if let id = notif.userInfo?["recipeObjectID"] as? NSManagedObjectID {
                pendingRecipeObjectID = id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenRecipeFromNotification"))) { notif in
            // Обработка нажатия на локальное уведомление
            if let recipeIDURL = notif.userInfo?["recipeIDURL"] as? URL,
               let stepID = notif.userInfo?["stepID"] as? UUID {
                notificationRecipeIDURL = recipeIDURL
                notificationStepID = stepID
                
                // Пытаемся получить NSManagedObjectID из URL
                if let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: recipeIDURL) {
                    pendingRecipeObjectID = objectID
                }
            }
        }
    }

    @ViewBuilder
    private func destinationTimerView() -> some View {
        if let objectID = pendingRecipeObjectID,
           let recipe = try? viewContext.existingObject(with: objectID) as? RecipeEntity {
            CookingTimerRecipeView(recipe: recipe, highlightStepID: notificationStepID)
        } else {
            EmptyView()
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
