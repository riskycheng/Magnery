import SwiftUI

struct EditMagnetSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var magnet: MagnetItem
    let onSave: () -> Void
    
    @State private var editedName: String
    @State private var editedNotes: String
    
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
                    TextField("", text: $editedName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary.opacity(0.3))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    TextField("", text: $editedNotes)
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        magnet.name = editedName
                        magnet.notes = editedNotes
                        onSave()
                    }) {
                        Text("保存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .clipShape(Capsule())
                    }
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
}
