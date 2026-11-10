import Foundation

struct Stopwatch {
    let accumulated: Duration
    let started: ContinuousClock.Instant?

    init(accumulated: Duration = .zero, started: ContinuousClock.Instant? = nil) {
        self.accumulated = accumulated
        self.started = started
    }

    func elapsed(at now: ContinuousClock.Instant) -> Duration {
        accumulated + (started.map { $0.duration(to: now) } ?? .zero)
    }

    func toggled(at now: ContinuousClock.Instant) -> Stopwatch {
        if started != nil { return Stopwatch(accumulated: elapsed(at: now)) }
        return Stopwatch(accumulated: accumulated, started: now)
    }

    func text(at now: ContinuousClock.Instant) -> String {
        Self.format(seconds: elapsed(at: now).components.seconds)
    }

    static func format(seconds: Int64) -> String {
        let value = max(0, seconds)
        return String(format: "%02lld:%02lld:%02lld", value / 3600, value / 60 % 60, value % 60)
    }
}

struct Countdown {
    let duration: Int64
    let clock: Stopwatch

    init(duration: Int64, clock: Stopwatch = Stopwatch()) {
        self.duration = max(0, duration)
        self.clock = clock
    }

    func remaining(at now: ContinuousClock.Instant) -> Int64 {
        // Round up: a fresh five-second timer shows 5 until the first second ends.
        max(0, duration - clock.elapsed(at: now).components.seconds)
    }

    func finished(at now: ContinuousClock.Instant) -> Bool {
        clock.elapsed(at: now) >= .seconds(duration)
    }

    func toggled(at now: ContinuousClock.Instant) -> Countdown {
        Countdown(duration: duration, clock: clock.toggled(at: now))
    }

    static func duration(hours: String, minutes: String, seconds: String) -> Int64? {
        guard let h = Int64(hours), let m = Int64(minutes), let s = Int64(seconds),
              (0...99).contains(h), (0...59).contains(m), (0...59).contains(s),
              h + m + s > 0 else { return nil }
        return h * 3600 + m * 60 + s
    }
}
