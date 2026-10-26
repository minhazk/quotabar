import Foundation

enum Vendor: String, CaseIterable, Codable {
    case claude, gemini, codex, grok

    var name: String { ["claude": "Claude", "gemini": "Gemini", "codex": "Codex", "grok": "Grok"][rawValue]! }
    /// The CLI leftbar asks, and what the panel suggests when it is missing or signed out.
    var cli: String { ["claude": "claude", "gemini": "agy", "codex": "codex", "grok": "grok"][rawValue]! }
    var product: String {
        ["claude": "Claude Code", "gemini": "Google Antigravity CLI", "codex": "Codex CLI", "grok": "Grok Build"][rawValue]!
    }
    var loginHint: String {
        ["claude": "run `claude`, then /login", "gemini": "run `agy` once and sign in",
         "codex": "run `codex login`", "grok": "run `grok login`"][rawValue]!
    }
    var mark: String { ["claude": "claude", "gemini": "gemini", "codex": "openai", "grok": "xai"][rawValue]! }
}

/// Why a vendor shows no numbers. `ok` = the CLI answered.
enum VendorState: String, Codable {
    case ok
    case missing        // CLI not found: hidden from the menu bar, listed in the panel
    case untrusted      // found, but owned by another account or group/world-writable: never run
    case signedOut      // the CLI says nobody is signed in
    case failed         // it ran and did not give limits (timeout, error, changed format)
}

/// One limit window as the vendor reports it. `used` is percent USED, 0–100.
struct Window: Codable, Equatable {
    var label: String            // "5-hour", "Week", "Weekly credits", …
    var short: String            // "5h" or "w" — the menu bar adds a superscript w for weekly windows
    var used: Double?
    var resetsAt: Date?

    var id: String { label + ":" + short }

    /// The reset time has passed since we read it: the old percent is obsolete, not "0 %".
    var resetPassed: Bool { (resetsAt.map { $0 < Date() }) ?? false }

    /// Missing or expired readings are unknown; a reset alone does not prove a full allowance.
    func remaining(at now: Date = Date()) -> Double? {
        guard let used = percent(used), resetsAt.map({ $0 > now }) ?? true else { return nil }
        return 100 - used
    }
}

struct Snapshot: Codable, Equatable {
    var vendor: Vendor
    var state: VendorState = .ok
    var plan: String = ""         // from the CLI's own answer: "Max", "ChatGPT Plus", "X Premium+"
    var bar: Window?              // the window the menu bar shows for this vendor
    var windows: [Window] = []    // everything shown in the panel, bar window first
    var notes: [String] = []      // e.g. "2 free full resets · next expires Fri 3 Jan"
    var measuredAt: Date?         // when the vendor's numbers were taken (not when we looked)
    var error: String?            // last failure, shown dimmed; previous numbers are kept

    /// Claude always means the all-model weekly allowance, including when loading an old cache.
    /// A missing weekly reading must never silently substitute the five-hour allowance.
    var displayWindow: Window? {
        vendor == .claude ? windows.first { $0.label == "Week" && $0.short == "w" } : bar
    }

    var displayWindows: [Window] {
        guard let preferred = displayWindow else { return windows }
        return [preferred] + windows.filter { $0 != preferred }
    }

    /// Any window of this vendor at ≥ 90 % other than the one in the bar → "!" next to the digit.
    var otherHot: Bool {
        windows.contains { $0 != displayWindow && ($0.remaining().map { $0 <= 10 } ?? false) }
    }

    static func status(_ v: Vendor, _ state: VendorState, _ error: String? = nil) -> Snapshot {
        Snapshot(vendor: v, state: state, error: error)
    }
}

/// A percentage from a CLI is only used when it is a finite number in 0…100.
func percent(_ any: Any?) -> Double? {
    let v: Double?
    switch any {
    case let d as Double: v = d
    case let i as Int: v = Double(i)
    case let n as NSNumber: v = n.doubleValue
    default: v = nil
    }
    guard let x = v, x.isFinite, x >= 0, x <= 100 else { return nil }
    return x
}

/// Bar digit: rounded, but 99.6 % must never read as 100 %.
func percentText(_ v: Double?) -> String {
    guard let v = percent(v) else { return "—" }
    if v > 0 && v < 1 { return "<1" }
    let r = v.rounded()
    return String(Int(r >= 100 && v < 100 ? 99 : r))
}
