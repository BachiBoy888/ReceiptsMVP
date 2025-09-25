//
//  ChartHelpers.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 25/9/25.
//

import SwiftUI
import Charts

// Карточка-обёртка для графиков
@ViewBuilder
func chartCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
        .chartPlotStyle { plot in
            plot.padding(.leading, 6).padding(.trailing, 6).padding(.top, 0)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
}

// X-домен: конец ИСКЛЮЧИТЕЛЕН (+1 день), как в чеках
func xDomain(start: Date, end: Date) -> ClosedRange<Date> {
    let cal = Calendar.current
    let s = cal.startOfDay(for: start)
    let e = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: end))!
    return s...e
}

// Адаптивная частота меток по X
func xLabelStride(days: Int, width: CGFloat) -> Int {
    let approxLabelWidth: CGFloat = 54
    let maxLabels = max(2, Int(width / approxLabelWidth))
    return max(1, Int(ceil(Double(days) / Double(maxLabels))))
}
