//
//  AnalyticsService.swift
//  ReceiptsMVP
//
//  Created by Tilek Maralov on 3/10/25.
//

// Shared/Analytics/AnalyticsService.swift
import Foundation
import AmplitudeSwift

enum AnalyticsEvent {
    static let receiptScanned        = "receipt_scanned"
    static let bankStatementUploaded = "bank_statement_uploaded"
    static let helpInstructionOpened = "help_instruction_opened"
    static let devContactLinkClicked = "dev_contact_link_clicked"
}

final class AnalyticsService {
    static let shared = AnalyticsService()
    let amplitude: Amplitude

    private init() {
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "AMPLITUDE_API_KEY") as? String ?? ""
        assert(!apiKey.isEmpty, "AMPLITUDE_API_KEY is empty — проверь Info.plist / Build Settings")

        #if DEBUG
        let cfg = Configuration(
            apiKey: apiKey,
            logLevel: .DEBUG,
            callback: { event, code, message in
                print("Amplitude upload → \(event.eventType) code:", code, "msg:", message)
            },
            autocapture: .sessions
        )
        #else
        let cfg = Configuration(
            apiKey: apiKey,
            logLevel: .ERROR,
            autocapture: .sessions
        )
        #endif

        amplitude = Amplitude(configuration: cfg)

        // user properties
        let identify = Identify()
        identify.setOnce(property: "installed_at",
                         value: ISO8601DateFormatter().string(from: Date()))
        identify.set(property: "app_version",
                     value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
        identify.set(property: "build_number",
                     value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")
        identify.set(property: "locale",
                     value: Locale.current.identifier)
#if DEBUG
identify.set(property: "env", value: "dev")
#else
identify.set(property: "env", value: "prod")
#endif
        amplitude.identify(identify: identify)

        #if DEBUG
        amplitude.track(eventType: "debug_app_launched",
                        eventProperties: ["ts": ISO8601DateFormatter().string(from: Date())])
        #endif
    }

    func track(_ event: String, props: [String: Any?] = [:]) {
        amplitude.track(eventType: event, eventProperties: props.compactMapValues { $0 })
    }

    func trackScreen(_ name: String) {
        amplitude.track(eventType: "[Amplitude] Screen Viewed",
                        eventProperties: ["[Amplitude] Screen Name": name])
    }
}
