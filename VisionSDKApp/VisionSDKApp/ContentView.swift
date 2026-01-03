//
//  ContentView.swift
//  VisionSDKApp
//
//  Created by Jian Cheng on 2026/1/3.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var processor = VisionProcessor()
    @State private var inputFolder: URL?
    @State private var outputFolder: URL?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Vision Object Segmentation Batch Tool")
                .font(.title)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Input Folder:")
                        .frame(width: 100, alignment: .leading)
                    Text(inputFolder?.path ?? "Not selected")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Select") {
                        selectFolder { url in
                            inputFolder = url
                        }
                    }
                }
                
                HStack {
                    Text("Output Folder:")
                        .frame(width: 100, alignment: .leading)
                    Text(outputFolder?.path ?? "Not selected")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Select") {
                        selectFolder { url in
                            outputFolder = url
                        }
                    }
                }
                
                Divider()
                
                Toggle("Generate 3D Models (Tencent Hunyuan)", isOn: $processor.generate3D)
                    .toggleStyle(.checkbox)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            if processor.isProcessing {
                VStack(spacing: 10) {
                    ProgressView(value: processor.progress)
                        .progressViewStyle(.linear)
                    Text(processor.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                Text(processor.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                if let input = inputFolder, let output = outputFolder {
                    Task {
                        await processor.processBatch(inputFolder: input, outputFolder: output)
                    }
                }
            }) {
                Text(processor.isProcessing ? "Processing..." : "Start Batch Processing")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(inputFolder != nil && outputFolder != nil && !processor.isProcessing ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(inputFolder == nil || outputFolder == nil || processor.isProcessing)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 350)
    }
    
    private func selectFolder(completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                completion(url)
            }
        }
    }
}

#Preview {
    ContentView()
}
