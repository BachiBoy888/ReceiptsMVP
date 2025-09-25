//
//  SpendingChartDailyBars.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 25/9/25.
//

import SwiftUI
import Charts

struct SpendingChartDailyBars: View {
    let points: [ChartPoint]
    let period: (start: Date, end: Date)
    let title: String    // например: metric.rawValue

    var body: some View {
        chartCard {
            // ВАЖНО: GeometryReader — ВНУТРИ карточки,
            // чтобы высота/клип у карточки работали стабильно и ничего не «слипалось».
            GeometryReader { geo in
                let count = max(points.count, 1)
                let barWidth: CGFloat = count > 45 ? 4 : (count > 30 ? 6 : 8)
                let maxY = max(points.map(\.value).max() ?? 0, 1)
                let stride = xLabelStride(days: count, width: geo.size.width)

                Chart(points) { p in
                    BarMark(
                        x: .value("Дата", p.date),
                        y: .value(title, p.value),
                        width: .fixed(barWidth)
                    )
                    .cornerRadius(3)
                }
                .chartXScale(domain: xDomain(start: period.start, end: period.end))
                .chartYScale(domain: 0...maxY * 1.2)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: stride)) { v in
                        if let d = v.as(Date.self) {
                            AxisGridLine().foregroundStyle(.gray.opacity(0.3))
                            AxisTick(length: 4)
                            AxisValueLabel {
                                Text(d, format: .dateTime.day().month(.abbreviated)) // d MMM
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5))
                }
            }
        }
    }
}
