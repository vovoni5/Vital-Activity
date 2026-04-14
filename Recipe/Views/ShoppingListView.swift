import SwiftUI
import CoreData
import UIKit

/// Экран списка покупок.
struct ShoppingListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: ShoppingListViewModel
    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingExportConfirmationAlert = false
    @State private var showingExportSheet = false
    @State private var newItemName = ""
    @State private var newItemQuantity = ""
    @State private var selectedUnit: QuantityUnit = .grams
    @State private var selectedCategory: String = IngredientCategory.other.rawValue
    
    init() {
        let viewModel = ShoppingListViewModel(context: PersistenceController.shared.container.viewContext)
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppGradientBackground().ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView("Загрузка...")
                } else if viewModel.items.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("Список покупок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: viewModel.mergeDuplicates) {
                        Label("Объединить дубликаты", systemImage: "arrow.merge")
                            .font(.caption)
                    }
                    .disabled(viewModel.items.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showingExportConfirmationAlert = true }) {
                            Label("Поделиться", systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                        .disabled(viewModel.items.isEmpty)
                        
                        Menu {
                            Button(action: { showingAddSheet = true }) {
                                Label("Добавить вручную", systemImage: "plus")
                            }
                            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                                Label("Очистить список", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                addItemSheet
            }
            .alert("Очистить список?", isPresented: $showingDeleteAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Очистить", role: .destructive) {
                    viewModel.deleteAllItems()
                }
            } message: {
                Text("Все элементы списка покупок будут удалены. Это действие нельзя отменить.")
            }
            .alert("Поделиться списком покупок?", isPresented: $showingExportConfirmationAlert) {
                Button("Нет", role: .cancel) {}
                Button("Да") {
                    showingExportSheet = true
                }
            } message: {
                Text("Вы можете отправить список покупок в другие приложения, например в Заметки, Сообщения или Почту.")
            }
            .sheet(isPresented: $showingExportSheet) {
                ActivityView(activityItems: [generateShoppingListText()])
            }
            .onAppear {
                viewModel.loadItems()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "cart")
                .font(.system(size: 70))
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, 8)
            
            Text("Список покупок пуст")
                .primaryTitle()
                .multilineTextAlignment(.center)
            
            Text("Добавьте ингредиенты из рецептов или создайте элементы вручную.")
                .secondaryText()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingAddSheet = true }) {
                Label("Добавить элемент", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillButtonStyle())
            .frame(maxWidth: 220)
            .padding(.top, 16)
        }
        .padding(.horizontal, 24)
        .screenAppear()
    }
    
    private var listView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.sortedCategories.enumerated()), id: \.element) { categoryIndex, category in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(category)
                            .font(.custom(AppFonts.title, size: 20))
                            .secondaryText()
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                        
                        VStack(spacing: 8) {
                            ForEach(Array(viewModel.items(for: category).enumerated()), id: \.element.id) { itemIndex, item in
                                ShoppingItemRow(item: item) {
                                    viewModel.togglePurchased(for: item)
                                } onDelete: {
                                    viewModel.deleteItem(item)
                                }
                                .padding(.horizontal, 16)
                                .staggeredList(index: categoryIndex * 10 + itemIndex, totalCount: viewModel.items.count)
                            }
                            
                        }
                        .background(Color.clear)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                    }
                    .staggeredList(index: categoryIndex, totalCount: viewModel.sortedCategories.count)
                }
            }
            .padding(.vertical, 16)
        }
        .screenAppear()
    }
    
    private var addItemSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Новый элемент")) {
                    TextField("Название", text: $newItemName)
                    TextField("Количество", text: $newItemQuantity)
                        .keyboardType(.decimalPad)
                    Picker("Единица измерения", selection: $selectedUnit) {
                        ForEach(QuantityUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    Picker("Категория", selection: $selectedCategory) {
                        ForEach(IngredientCategory.allCases, id: \.rawValue) { category in
                            Text(category.rawValue).tag(category.rawValue)
                        }
                    }
                }
            }
            .navigationTitle("Добавить элемент")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        showingAddSheet = false
                        resetForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        addNewItem()
                    }
                    .disabled(newItemName.isEmpty || newItemQuantity.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Методы
    
    private func addNewItem() {
        guard let quantity = Double(newItemQuantity) else { return }
        viewModel.addItem(
            name: newItemName,
            quantity: quantity,
            unit: selectedUnit,
            category: selectedCategory
        )
        showingAddSheet = false
        resetForm()
    }
    
    private func resetForm() {
        newItemName = ""
        newItemQuantity = ""
        selectedUnit = .grams
        selectedCategory = IngredientCategory.other.rawValue
    }
    
    private func generateShoppingListText() -> String {
        var text = "Список покупок\n\n"
        for category in viewModel.sortedCategories {
            text += "\(category):\n"
            for item in viewModel.items(for: category) {
                let checkmark = item.isPurchased ? "✓" : "•"
                text += "\(checkmark) \(item.name) – \(item.formattedQuantity)\n"
            }
            text += "\n"
        }
        text += "Создано в приложении «Рецепты»"
        return text
    }
}

// MARK: - ActivityView для экспорта через UIActivityViewController
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Строка элемента списка покупок
private struct ShoppingItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isPurchased ? .green : AppColors.textSecondary)
                    .imageScale(.large)
                    .scaleEffect(item.isPurchased ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: item.isPurchased)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.custom(AppFonts.subtitle, size: 17))
                    .strikethrough(item.isPurchased, color: .secondary)
                    .foregroundColor(item.isPurchased ? .secondary : .primary)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: item.isPurchased)
                Text(item.formattedQuantity)
                    .font(.custom(AppFonts.numeric, size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .glassEffect(.clear)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: item.isPurchased)
    }
}

// MARK: - Preview
#Preview {
    ShoppingListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
