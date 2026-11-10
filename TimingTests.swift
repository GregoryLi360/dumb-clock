import Foundation

@main
struct TimingTests {
    static func main() {
        let now = ContinuousClock.now
        let initial = Stopwatch()
        assert(initial.text(at: now) == "00:00:00")
        let running = initial.toggled(at: now)
        assert(running.text(at: now.advanced(by: .milliseconds(1234))) == "00:00:01")
        let paused = running.toggled(at: now.advanced(by: .seconds(2)))
        assert(paused.elapsed(at: now.advanced(by: .seconds(100))) == .seconds(2))
        let resumed = paused.toggled(at: now.advanced(by: .seconds(100)))
        assert(resumed.elapsed(at: now.advanced(by: .milliseconds(101500))) == .milliseconds(3500))
        assert(running.text(at: now.advanced(by: .seconds(60))) == "00:01:00")
        assert(running.text(at: now.advanced(by: .seconds(3661))) == "01:01:01")
        assert(running.text(at: now.advanced(by: .seconds(360000))) == "100:00:00")
        let timer = Countdown(duration: 5).toggled(at: now)
        assert(Countdown(duration: 0).remaining(at: now) == 0)
        assert(timer.remaining(at: now.advanced(by: .milliseconds(100))) == 5)
        assert(timer.remaining(at: now.advanced(by: .seconds(1))) == 4)
        assert(!timer.finished(at: now.advanced(by: .milliseconds(4999))))
        assert(timer.finished(at: now.advanced(by: .seconds(5))))
        assert(timer.remaining(at: now.advanced(by: .seconds(100))) == 0)
        let stopped = timer.toggled(at: now.advanced(by: .seconds(2)))
        assert(stopped.remaining(at: now.advanced(by: .seconds(200))) == 3)
        let continued = stopped.toggled(at: now.advanced(by: .seconds(200)))
        assert(!continued.finished(at: now.advanced(by: .seconds(202))))
        assert(continued.finished(at: now.advanced(by: .seconds(203))))
        assert(Countdown.duration(hours: "1", minutes: "2", seconds: "3") == 3723)
        for bad in ["-1", "100", "x", ""] {
            assert(Countdown.duration(hours: bad, minutes: "0", seconds: "1") == nil)
        }
        assert(Countdown.duration(hours: "0", minutes: "60", seconds: "0") == nil)
        assert(Countdown.duration(hours: "0", minutes: "0", seconds: "0") == nil)
        print("Timing checks passed: pause/resume, display rollover, countdown deadline and input validation.")
    }
}
