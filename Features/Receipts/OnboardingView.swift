//
//  OnboardingView.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 26/9/25.
//

import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let imageName: String?
        let fallbackSymbol: String
    }

    private let pages: [Page] = [
        .init(
            title: "Сканируйте чеки",
            subtitle: "Наводите камеру на QR — приложение найдет чек, сохранит сумму и продавца.",
            imageName: "onboarding-scan",
            fallbackSymbol: "qrcode.viewfinder"
        ),
        .init(
            title: "Загрузите выписку из MBank",
            subtitle: "Импортируйте Excel — мы посчитаем траты по дням и категориям.",
            imageName: "onboarding-mbank",
            fallbackSymbol: "tray.and.arrow.down.fill"
        ),
        .init(
            title: "Связываем чеки и транзакции",
            subtitle: "Приложение автоматически находит соответствия и подсвечивает их в списке.",
            imageName: "onboarding-match",
            fallbackSymbol: "link"
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [.gray.opacity(0.08), .gray.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: Skip
                HStack {
                    Button("Пропустить") { onFinish() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, p in
                        VStack(spacing: 20) {
                            // Image / symbol
                            ZStack {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                VStack(spacing: 16) {
                                    if let name = p.imageName {
                                        Image(name) // ← напрямую из ассетов, без UIImage(named:)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: 300, maxHeight: 500)
                                    } else {
                                        Image(systemName: p.fallbackSymbol)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 140, height: 140)
                                            .padding(20)
                                    }
                                }
                                .padding(16)
                            }
                            .frame(height: 500)
                            .padding(.horizontal)

                            // Texts
                            VStack(spacing: 8) {
                                Text(p.title)
                                    .font(.title2).bold()
                                    .multilineTextAlignment(.center)
                                Text(p.subtitle)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal)

                            Spacer()
                        }
                        .tag(idx)
                        .padding(.top, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page control
                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.primary : Color.secondary.opacity(0.3)) // ⬅️ фикс
                            .frame(width: i == page ? 10 : 6, height: i == page ? 10 : 6)
                            .animation(.spring(duration: 0.25), value: page)
                    }
                }
                .padding(.vertical, 12)

                // Bottom button
                Button(action: {
                    if page < pages.count - 1 {
                        withAnimation(.easeInOut) { page += 1 }
                    } else {
                        onFinish()
                    }
                }) {
                    Text(page < pages.count - 1 ? "Далее" : "Начать пользоваться")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
                .accessibilityLabel(page < pages.count - 1 ? "Далее" : "Начать пользоваться")
            }
        }
    }
}
