import SwiftUI

struct EditMagnetSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: MagnetStore
    @Binding var magnet: MagnetItem
    let onSave: () -> Void
    
    @State private var editedName: String
    @State private var editedNotes: String
    @State private var isGeneratingNote: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name
        case notes
    }
    
    init(magnet: Binding<MagnetItem>, onSave: @escaping () -> Void) {
        self._magnet = magnet
        self.onSave = onSave
        _editedName = State(initialValue: magnet.wrappedValue.name)
        _editedNotes = State(initialValue: magnet.wrappedValue.notes)
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                if let image = ImageManager.shared.loadImage(filename: magnet.imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 60)
                }
                
                VStack(spacing: 16) {
                    TextField(magnet.name.isEmpty ? "名字" : magnet.name, text: $editedName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 40)
                        .focused($focusedField, equals: .name)
                        .onTapGesture {
                            focusedField = .name
                        }
                        .onChange(of: focusedField) { newValue in
                            if newValue == .name && !editedName.isEmpty {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                                }
                            }
                        }
                    
                    ZStack(alignment: .bottomTrailing) {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                                )
                            
                            TextEditor(text: $editedNotes)
                                .font(.body)
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(12)
                                .background(Color.clear)
                                .focused($focusedField, equals: .notes)
                                .onTapGesture {
                                    focusedField = .notes
                                }
                                .onChange(of: focusedField) { newValue in
                                    if newValue == .notes && !editedNotes.isEmpty {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                                        }
                                    }
                                }
                            
                            if editedNotes.isEmpty {
                                Text(magnet.notes.isEmpty ? "加一点描述，更加了解它" : magnet.notes)
                                    .font(.body)
                                    .foregroundColor(.secondary.opacity(0.3))
                                    .padding(.top, 20)
                                    .padding(.leading, 17)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(height: 120)
                        
                        if !editedName.isEmpty || !magnet.name.isEmpty {
                            Button(action: {
                                generateAINote()
                            }) {
                                if isGeneratingNote {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.orange)
                                } else {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(12)
                            .disabled(isGeneratingNote || (editedName.isEmpty && magnet.name.isEmpty))
                        }
                    }
                    .padding(.horizontal, 40)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        if !editedName.trimmingCharacters(in: .whitespaces).isEmpty {
                            magnet.name = editedName
                            magnet.notes = editedNotes
                            onSave()
                        }
                    }) {
                        Text("保存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(editedName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.black)
                            .clipShape(Capsule())
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 40)
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("取消")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private func generateAINote() {
        guard !editedName.isEmpty else { return }
        
        isGeneratingNote = true
        
        Task {
            do {
                let modelType = store.aiModel
                let generatedNotes = try await AIService.shared.generateCaption(
                    itemName: editedName,
                    location: magnet.location,
                    date: magnet.date,
                    image: ImageManager.shared.loadImage(filename: magnet.imagePath),
                    modelType: modelType
                )
                
                await MainActor.run {
                    self.editedNotes = generatedNotes
                    self.isGeneratingNote = false
                }
            } catch {
                print("❌ [EditMagnetSheet] Failed to generate notes: \(error)")
                await MainActor.run {
                    self.isGeneratingNote = false
                    // Fallback
                    self.editedNotes = "一个值得纪念的收藏品。"
                }
            }
        }
    }
}
