import SwiftUI
import CoreData

struct MenuPlannerListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MealPlanEntity.name, ascending: true)],
        animation: .default
    )
    private var plans: FetchedResults<MealPlanEntity>

    @State private var showAddPlan = false
    @State private var pendingDelete: MealPlanEntity?
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            AppGradientBackground().ignoresSafeArea()

            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("Планировщик меню")
                        .primaryTitle()
                        .animatedText()
                    Text("Создавайте дневные рационы как плейлисты")
                        .secondaryText()
                        .animatedText()
                }
                .padding(.top, 18)

                List {
                    ForEach(plans, id: \.objectID) { plan in
                        NavigationLink {
                            MealPlanDetailView(plan: plan)
                        } label: {
                            CardContainer {
                                Text(plan.name ?? "")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDelete = plan
                                showDeleteConfirm = true
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                            .foregroundColor(AppColors.swipeActionText)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                    }

                    if plans.isEmpty {
                        CardContainer {
                            VStack(spacing: 8) {
                                Text("Рационов пока нет")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                                Text("Нажмите +, чтобы создать первый рацион")
                                    .secondaryText()
                                    .animatedText()
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .padding(.bottom, 24)
                .screenAppear()
                .background(Color.clear)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddPlan = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showAddPlan) {
            AddMealPlanSheet { name in
                let plan = MealPlanEntity(context: viewContext)
                plan.id = UUID()
                plan.name = name
                plan.recipeIDs = []
                save()
            }
        }
        .alert("Удалить рацион?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) {
                if let pendingDelete {
                    viewContext.delete(pendingDelete)
                    save()
                }
                self.pendingDelete = nil
            }
            Button("Отмена", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Все связи внутри рациона будут удалены.")
        }
        .withActiveTimerPanel(isTimerScreen: false)
    }

    private func save() {
        do { try viewContext.save() } catch {
            ErrorHandler.handleCoreDataError(error, message: "Не удалось сохранить изменения в планировщике меню")
        }
    }
}

private struct AddMealPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    let onCreate: (String) -> Void

    var body: some View {
        ZStack {
            AppGradientBackground().ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Новый рацион")
                    .primaryTitle()
                    .animatedText()
                    .padding(.top, 18)

                CardContainer {
                    VStack(spacing: 10) {
                        Text("Название")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)

                        TextField("", text: $name)
                            .textFieldStyle(.plain)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .gradientInputField()
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Отмена")
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(PillButtonStyle())

                    Button {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onCreate(trimmed)
                        dismiss()
                    } label: {
                        Text("Создать")
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(PillButtonStyle())
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.horizontal, 16)
            .screenAppear()
        }
    }
}

struct MealPlanDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var plan: MealPlanEntity

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecipeEntity.title, ascending: true)],
        animation: .default
    )
    private var allRecipes: FetchedResults<RecipeEntity>

    @State private var showAddRecipePicker = false
    @State private var pendingRemoveRecipeID: UUID?
    @State private var showRemoveConfirm = false
    @State private var nameText: String = ""

    private var planRecipes: [RecipeEntity] {
        let ids = Set(plan.recipeIDs)
        return allRecipes.filter { recipe in
            if let id = recipe.id {
                return ids.contains(id)
            } else {
                return false
            }
        }
    }

    var body: some View {
        ZStack {
            AppGradientBackground().ignoresSafeArea()

            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    TextField("", text: $nameText)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .onSubmit {
                            commitName()
                        }
                        .primaryTitle()
                        .animatedText()
                }
                .padding(.top, 18)
                .padding(.horizontal, 16)

                Button {
                    showAddRecipePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Добавить рецепт")
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                .buttonStyle(PillButtonStyle())
                .frame(maxWidth: 260)
                .padding(.horizontal, 16)

                List {
                    ForEach(planRecipes, id: \.objectID) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
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
                        .contentShape(Rectangle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingRemoveRecipeID = recipe.id
                                showRemoveConfirm = true
                            } label: {
                                Label("Убрать", systemImage: "minus.circle")
                            }
                            .foregroundColor(AppColors.swipeActionText)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                    }

                    if planRecipes.isEmpty {
                        CardContainer {
                            VStack(spacing: 8) {
                                Text("Список пуст")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                                Text("Добавьте рецепты с помощью кнопки выше")
                                    .secondaryText()
                                    .animatedText()
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .padding(.bottom, 24)
                .screenAppear()
                .background(Color.clear)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            nameText = plan.name ?? ""
        }
        .onDisappear {
            commitName()
        }
        .sheet(isPresented: $showAddRecipePicker) {
            RecipePickerSheet(
                title: "Добавить в рацион",
                recipes: Array(allRecipes),
                alreadySelectedIDs: Set(plan.recipeIDs)
            ) { picked in
                if let pickedID = picked.id, !plan.recipeIDs.contains(pickedID) {
                    plan.recipeIDs = plan.recipeIDs + [pickedID]
                    save()
                }
            }
        }
        .alert("Удалить из рациона?", isPresented: $showRemoveConfirm) {
            Button("Удалить", role: .destructive) {
                if let id = pendingRemoveRecipeID {
                    plan.recipeIDs = plan.recipeIDs.filter { $0 != id }
                    save()
                }
                pendingRemoveRecipeID = nil
            }
            Button("Отмена", role: .cancel) {
                pendingRemoveRecipeID = nil
            }
        } message: {
            Text("Рецепт останется в базе, удалится только из этого рациона.")
        }
    }

    private func commitName() {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != plan.name {
            plan.name = trimmed
            save()
        }
    }

    private func save() {
        do { try viewContext.save() } catch {
            ErrorHandler.handleCoreDataError(error, message: "Не удалось сохранить изменения в планировщике меню")
        }
    }
}

private struct RecipePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let recipes: [RecipeEntity]
    let alreadySelectedIDs: Set<UUID>
    let onPick: (RecipeEntity) -> Void

    var body: some View {
        ZStack {
            AppGradientBackground().ignoresSafeArea()

            VStack(spacing: 14) {
                Text(title)
                    .primaryTitle()
                    .animatedText()
                    .padding(.top, 18)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(recipes, id: \.objectID) { recipe in
                            let isDisabled: Bool = {
                                if let id = recipe.id {
                                    return alreadySelectedIDs.contains(id)
                                } else {
                                    return false
                                }
                            }()
                            Button {
                                guard !isDisabled else { return }
                                onPick(recipe)
                                dismiss()
                            } label: {
                                CardContainer {
                                    VStack(spacing: 6) {
                                        Text(recipe.title ?? "")
                                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                                            .foregroundColor(Color("BrandTextColor"))
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .multilineTextAlignment(.center)
                                        if isDisabled {
                                            Text("Уже добавлено")
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(AppColors.textSecondary)
                                                .frame(maxWidth: .infinity)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isDisabled)
                            .opacity(isDisabled ? 0.7 : 1)
                        }

                        if recipes.isEmpty {
                            CardContainer {
                                Text("В базе рецептов пока нет записей")
                                    .secondaryText()
                                    .animatedText()
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .screenAppear()
                }

                Button {
                    dismiss()
                } label: {
                    Text("Закрыть")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(PillButtonStyle())
                .frame(maxWidth: 220)
                .padding(.bottom, 18)
            }
        }
    }
}

