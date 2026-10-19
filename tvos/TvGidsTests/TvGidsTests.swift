import XCTest
@testable import TvGids

private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

final class ColorAssignerTests: XCTestCase {
    private struct Vectors: Decodable {
        struct Hash: Decodable { let title: String; let fnv1a32: UInt32; let index: Int }
        struct Sequence: Decodable { let titles: [String]; let indices: [Int] }
        let hashes: [Hash]; let sequence: Sequence
    }

    private func vectors() throws -> Vectors {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "palette-vectors", withExtension: "json"))
        return try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: url))
    }

    func testHashVectors() throws {
        for v in try vectors().hashes {
            XCTAssertEqual(ColorAssigner.fnv1a32(v.title), v.fnv1a32, v.title)
            XCTAssertEqual(Int(ColorAssigner.fnv1a32(v.title) % 5), v.index, v.title)
        }
    }

    func testSequenceNeverRepeatsNeighbour() throws {
        let s = try vectors().sequence
        XCTAssertEqual(ColorAssigner.indices(for: s.titles), s.indices)
        let many = ColorAssigner.indices(for: Array(repeating: "Nieuws", count: 20))
        for (a, b) in zip(many, many.dropFirst()) { XCTAssertNotEqual(a, b) }
    }

    func testDeterministic() {
        let t = ["A", "B", "C", "A"]
        XCTAssertEqual(ColorAssigner.indices(for: t), ColorAssigner.indices(for: t))
    }

    func testPaletteFallbackHasFiveEntries() { XCTAssertEqual(Palette.fallback.count, 5) }
}

final class TimeGridTests: XCTestCase {
    private let now = date("2026-10-15T12:10:00Z")

    func testFloorToSlot() {
        XCTAssertEqual(TimeGrid.floorToSlot(now), date("2026-10-15T12:00:00Z"))
        XCTAssertEqual(TimeGrid.floorToSlot(date("2026-10-15T12:59:59Z")), date("2026-10-15T12:30:00Z"))
    }

    func testThreeHourViewport() {
        let grid = TimeGrid(now: now, viewportWidth: 1800)
        XCTAssertEqual(grid.pxPerMinute, 10)
        XCTAssertEqual(grid.x(for: grid.rangeStart.addingTimeInterval(180 * 60)), 1800)
        XCTAssertEqual(grid.slotWidth, 300)
    }

    func testFrameClipsToRange() throws {
        let grid = TimeGrid(now: now, viewportWidth: 1800)
        let f = try XCTUnwrap(grid.frame(start: grid.rangeStart.addingTimeInterval(-3600),
                                         end: grid.rangeStart.addingTimeInterval(1800)))
        XCTAssertEqual(f.x, 0)
        XCTAssertEqual(f.width, 300)
        XCTAssertNil(grid.frame(start: grid.rangeEnd, end: grid.rangeEnd.addingTimeInterval(60)))
    }

    func testSlotsAreHalfHours() {
        let grid = TimeGrid(now: now, viewportWidth: 1800)
        XCTAssertEqual(grid.slots.count, (TimeGrid.hoursBefore + TimeGrid.hoursAfter) * 2)
        XCTAssertEqual(grid.slots[1].timeIntervalSince(grid.slots[0]), 1800)
    }

    func testSplitFraction() {
        let s = date("2026-10-15T12:00:00Z"), e = date("2026-10-15T13:00:00Z")
        XCTAssertEqual(TimeGrid.splitFraction(start: s, end: e, now: now) ?? -1, 10.0 / 60, accuracy: 1e-9)
        XCTAssertNil(TimeGrid.splitFraction(start: s, end: e, now: s))
        XCTAssertNil(TimeGrid.splitFraction(start: s, end: e, now: e))
        XCTAssertNil(TimeGrid.splitFraction(start: s, end: s.addingTimeInterval(300), now: now))
    }

    func testBrusselsFormat() {
        XCTAssertEqual(BrusselsTime.format(date("2026-10-15T18:35:00Z")), "20:35")
        XCTAssertEqual(BrusselsTime.range(date("2026-01-15T19:35:00Z"), date("2026-01-15T20:25:00Z")), "20:35 - 21:25")
    }

    func testEveningDate() {
        let sample = date("2026-10-15T12:10:00Z")
        let evening = TimeGrid.eveningDate(relativeTo: sample)
        XCTAssertEqual(BrusselsTime.format(evening), "20:00")
    }
}

final class GuideDecodingTests: XCTestCase {
    func testSampleDecodesAndMatchesApps() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "sample", withExtension: "json"))
        let guide = try Guide.decode(Data(contentsOf: url))
        XCTAssertEqual(guide.channels.count, 11)
        XCTAssertEqual(guide.channels.first?.name, "VTM")
        let schemes = Dictionary(guide.channels.map { ($0.app, $0.scheme) }, uniquingKeysWith: { a, b in
            XCTAssertEqual(a, b); return a
        })
        XCTAssertEqual(schemes, ["vtmgo": "vtmgo://", "goplay": "goplay-app://", "vrtmax": "vrtmax://"])
    }

    func testAppInfoURLs() {
        let app = AppInfo(name: "VTM GO", scheme: "vtmgo://", appStoreId: 589370040)
        XCTAssertEqual(app.launchURL?.scheme, "vtmgo")
        XCTAssertEqual(app.storeURL?.absoluteString, "https://apps.apple.com/be/app/id589370040")
    }

    func testChannelProgramAtTime() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "sample", withExtension: "json"))
        let guide = try Guide.decode(Data(contentsOf: url))
        let channel = try XCTUnwrap(guide.channels.first)
        let second = channel.programs[1]
        // Binnen het programma:
        let mid = second.start.addingTimeInterval(60)
        XCTAssertEqual(channel.program(at: mid)?.start, second.start)
        // Exact op de starttijd:
        XCTAssertEqual(channel.program(at: second.start)?.start, second.start)
    }
}

final class BundledLogoTests: XCTestCase {
    func testEveryChannelLogoIsBundled() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "sample", withExtension: "json"))
        let guide = try Guide.decode(Data(contentsOf: url))
        let appBundle = Bundle(for: GuideStore.self)
        let files = BundledLogo.logoFiles(bundle: appBundle)
        XCTAssertEqual(files["play5"], "play-fictie-be.png")
        for channel in guide.channels {
            XCTAssertNotNil(BundledLogo.image(for: channel, files: files, bundle: appBundle), channel.name)
        }
    }
}

final class AppLinksTests: XCTestCase {
    func testChannelsHaveOverrideURL() {
        let links = AppLinks(bundle: Bundle(for: GuideStore.self))
        let base = "https://www.play.tv/live-kijken/"
        XCTAssertEqual(links.channelURLs["play4"]?.absoluteString, base + "play")
        XCTAssertEqual(links.channelURLs["play5"]?.absoluteString, base + "play-fictie")
        XCTAssertEqual(links.channelURLs["play6"]?.absoluteString, base + "play-actie")
        XCTAssertEqual(links.channelURLs["play7"]?.absoluteString, base + "play-reality")
        XCTAssertEqual(links.channelURLs.count, 9)
    }

    func testVTMUsesSchemeAndVRTUsesBundleID() {
        let links = AppLinks(bundle: Bundle(for: GuideStore.self))
        for id in ["vtm", "vtm2", "vtm3", "vtm4", "vtmgold"] {
            XCTAssertEqual(links.channelURLs[id]?.scheme, "vtmgo", id)
        }
        for id in ["vrt1", "vrtcanvas"] {
            XCTAssertNil(links.channelURLs[id], id)
        }
        XCTAssertEqual(links.apps["vrtmax"]?.bundleId, "be.vrt.vrtnu")
    }
}
