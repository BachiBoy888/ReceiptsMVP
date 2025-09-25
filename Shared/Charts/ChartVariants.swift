//
//  ChartVariants.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 25/9/25.
//

import SwiftUI
import Charts

enum ChartVariant: String, CaseIterable, Identifiable {
    case dailyBars
    case cumulative

    var id: String { rawValue }
    var title: String {
        switch self {
        case .dailyBars: return "Дни"
        case .cumulative: return "Накопит."
        }
    }
}

// === A) Дневные столбики ===
struct SpendingChartDailyBars: View {
    let points: [ChartPoint]
    let period: (start: Date, end: Date)
    let title: String

    var body: some View {
            chartCard {
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
                                Text(d, format: .dateTime.day().month(.abbreviated))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
            }
        }
    }
}

// === D) Накопительная линия ===
struct SpendingChartCumulative: View {
    let points: [ChartPoint]
    let period: (start: Date, end: Date)
    let title: String = "Накопительно / KGS"
    var budget: Double? = nil

    private var cum: [ChartPoint] {
        var run = 0.0
        return points.map { p in run += p.value; return .init(date: p.date, value: run) }
    }

    var body: some View {
        let maxY = max(cum.map(\.value).max() ?? 0, budget ?? 0, 1)

        chartCard {
            Chart {
                ForEach(cum) { p in
                    LineMark(
                        x: .value("Дата", p.date),
                        y: .value(title, p.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(.circle)
                }
                if let b = budget, b > 0 {
                    RuleMark(y: .value("Бюджет", b))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4,4]))
                        .annotation(position: .topTrailing) { Text("Бюджет") }
                }
            }
            .chartXScale(domain: xDomain(start: period.start, end: period.end))
            .chartYScale(domain: 0...maxY * 1.1)
            .chartXAxis { AxisMarks(position: .automatic) }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }
}
