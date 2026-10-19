import CoreGraphics
import Foundation

/// Tijd ↔ positie. Eén minuut = `pxPerMinute` punten; het zichtbare venster is 3 uur.
struct TimeGrid: Sendable, Equatable {
    static let visibleMinutes: CGFloat = 180
    static let slotMinutes = 30
    static let hoursBefore = 6
    static let hoursAfter = 30

    let rangeStart: Date
    let rangeEnd: Date
    let pxPerMinute: CGFloat

    /// `anchor` ligt vast zolang de gids open staat, zodat het raster niet verschuift terwijl de tijd verstrijkt;
    /// alleen de Nu-lijn beweegt.
    init(anchor: Date, viewportWidth: CGFloat) {
        rangeStart = anchor.addingTimeInterval(-Double(Self.hoursBefore) * 3600)
        rangeEnd = anchor.addingTimeInterval(Double(Self.hoursAfter) * 3600)
        pxPerMinute = viewportWidth / Self.visibleMinutes
    }

    init(now: Date, viewportWidth: CGFloat) {
        self.init(anchor: Self.floorToSlot(now), viewportWidth: viewportWidth)
    }

    var totalWidth: CGFloat { x(for: rangeEnd) }
    var slotWidth: CGFloat { CGFloat(Self.slotMinutes) * pxPerMinute }

    func x(for date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSince(rangeStart) / 60) * pxPerMinute
    }

    /// Linkerrand van het initieel zichtbare venster: één slot vóór het huidige slot,
    /// zodat de Nu-lijn niet tegen de rand zit.
    func initialOffset(now: Date) -> CGFloat {
        x(for: Self.floorToSlot(now).addingTimeInterval(-Double(Self.slotMinutes) * 60))
    }

    /// Geclipte (x, breedte) binnen het bereik; nil als het programma er buiten valt.
    func frame(start: Date, end: Date) -> (x: CGFloat, width: CGFloat)? {
        let s = max(start, rangeStart), e = min(end, rangeEnd)
        guard e > s else { return nil }
        return (x(for: s), x(for: e) - x(for: s))
    }

    /// Fractie (0…1) van het programma die vóór `now` ligt; nil als het niet loopt.
    static func splitFraction(start: Date, end: Date, now: Date) -> Double? {
        guard start < now, now < end else { return nil }
        return now.timeIntervalSince(start) / end.timeIntervalSince(start)
    }

    /// Slot-starts (om de 30 minuten) binnen het bereik.
    var slots: [Date] {
        var result: [Date] = []
        var t = rangeStart
        while t < rangeEnd {
            result.append(t)
            t = t.addingTimeInterval(Double(Self.slotMinutes) * 60)
        }
        return result
    }

    static func floorToSlot(_ date: Date) -> Date {
        let step = Double(slotMinutes) * 60
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / step).rounded(.down) * step)
    }

    /// Geeft 20:00 uur (Brusselse tijd) van de dag van `date`.
    static func eveningDate(relativeTo date: Date = .now) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = BrusselsTime.zone
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = 20
        comps.minute = 0
        comps.second = 0
        return cal.date(from: comps) ?? date
    }
}

enum BrusselsTime {
    static let zone = TimeZone(identifier: "Europe/Brussels")!

    static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_BE")
        f.timeZone = zone
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func range(_ start: Date, _ end: Date) -> String {
        "\(format(start)) - \(format(end))"
    }
}
