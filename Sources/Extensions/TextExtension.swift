import SwiftUI
extension Text {
    func strokeText(color: Color, width: CGFloat) -> some View {
        self
            .overlay(
                self
                    .foregroundColor(color)
                    .offset(x: width, y: width)
            )
            .overlay(
                self
                    .foregroundColor(color)
                    .offset(x: -width, y: width)
            )
            .overlay(
                self
                    .foregroundColor(color)
                    .offset(x: width, y: -width)
            )
            .overlay(
                self
                    .foregroundColor(color)
                    .offset(x: -width, y: -width)
            )
    }
}
