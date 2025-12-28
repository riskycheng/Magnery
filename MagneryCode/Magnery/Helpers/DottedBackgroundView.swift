import SwiftUI

struct DottedBackgroundView: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let dotSize: CGFloat = 2
                let spacing: CGFloat = 20
                let dotColor = Color.gray.opacity(0.15)
                
                let columns = Int(size.width / spacing) + 1
                let rows = Int(size.height / spacing) + 1
                
                for row in 0..<rows {
                    for col in 0..<columns {
                        let x = CGFloat(col) * spacing
                        let y = CGFloat(row) * spacing
                        
                        let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                        context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    }
                }
            }
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
    }
}
