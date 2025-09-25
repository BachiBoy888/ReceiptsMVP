//
//  PrimaryButtonStyle.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 25/9/25.
//

import SwiftUI

public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))        // как в «Сканировать»
            .frame(maxWidth: .infinity, minHeight: 46)          // единая высота
            .padding(.horizontal, 16)                            // внутр. горизонтальный
            .background(.blue, in: RoundedRectangle(cornerRadius: 12,
                                                    style: .continuous))
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
