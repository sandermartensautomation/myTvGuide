import SwiftUI
import UIKit

struct FocusTarget: Hashable {
    let channelID: String
    let start: Date
}

struct EPGGrid: View {
    let guide: Guide
    let logoURL: (Channel) -> URL?
    let palette: [ColorPair]
    let anchor: Date
    let now: Date
    let viewportWidth: CGFloat
    @Binding var focus: FocusTarget?
    let onSelect: (Channel, Program) -> Void

    @FocusState private var focused: FocusTarget?
    @State private var rowsPosition = ScrollPosition(x: 0)
    @State private var headerPosition = ScrollPosition(x: 0)
    @State private var didPlaceInitially = false
    @State private var referenceTime: Date?

    private let logoFiles = BundledLogo.logoFiles()
    private let channelColumnWidth: CGFloat = 280
    private let rowHeight: CGFloat = 84
    private let rowSpacing: CGFloat = 10
    private let headerHeight: CGFloat = 38

    private var grid: TimeGrid {
        TimeGrid(anchor: anchor, viewportWidth: viewportWidth - channelColumnWidth)
    }

    var body: some View {
        let grid = grid
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: channelColumnWidth)
                HStack {
                    Button {
                        jumpToEvening(grid: grid)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "moon.stars.fill")
                            Text("Avond")
                        }
                        .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                }
            }
            .frame(height: 44)
            .focusSection()
            .padding(.top, 48)
            .padding(.bottom, 48)

            HStack(spacing: 0) {
                Color.clear.frame(width: channelColumnWidth, height: headerHeight)
                ScrollView(.horizontal, showsIndicators: false) {
                    TimeHeader(grid: grid).frame(height: headerHeight)
                }
                .scrollDisabled(true)
                .scrollPosition($headerPosition)
            }
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: rowSpacing) {
                        ForEach(guide.channels) { ChannelCell(channel: $0, logo: logoURL($0), logoFiles: logoFiles, height: rowHeight) }
                    }
                    .frame(width: channelColumnWidth)
                    ScrollView(.horizontal, showsIndicators: false) {
                        rows(grid: grid)
                    }
                    .scrollPosition($rowsPosition)
                    .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, x in
                        headerPosition.scrollTo(x: x)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .onChange(of: focused) { old, new in
            guard let new else { return }
            if let old, old.channelID != new.channelID {
                // Verticale navigatie met de pijltjes naar een andere zender:
                // Blijf op hetzelfde tijdstip focussen (het programma dat de nu-lijn kruist,
                // of het tijdstip waar de gebruiker horizontaal naar toe gebladerd is).
                let targetTime = referenceTime ?? now
                if let channel = guide.channels.first(where: { $0.id == new.channelID }),
                   let target = channel.program(at: targetTime) {
                    if target.start != new.start {
                        focused = FocusTarget(channelID: new.channelID, start: target.start)
                        return
                    }
                }
            } else if let channel = guide.channels.first(where: { $0.id == new.channelID }),
                      let program = channel.programs.first(where: { $0.start == new.start }) {
                // Horizontale navigatie binnen dezelfde zender: werk het actieve tijdstip bij.
                referenceTime = program.isLive(at: now) ? now : program.start
            }
            focus = new
        }
        .onAppear { placeInitially(grid: grid) }
    }

    private func rows(grid: TimeGrid) -> some View {
        VStack(spacing: rowSpacing) {
            ForEach(guide.channels) { channel in
                let colors = ColorAssigner.indices(for: channel.programs.map(\.title), paletteCount: palette.count)
                TimelineRowLayout(totalWidth: grid.totalWidth, height: rowHeight) {
                    ForEach(Array(channel.programs.enumerated()), id: \.element.id) { i, program in
                        if let f = grid.frame(start: program.start, end: program.end) {
                            let target = FocusTarget(channelID: channel.id, start: program.start)
                            Button { onSelect(channel, program) } label: {
                                ProgramBlock(program: program, pair: palette[colors[i]], now: now)
                            }
                            .buttonStyle(BlockButtonStyle())
                            .focused($focused, equals: target)
                            .timelineSlot(x: f.x, width: max(f.width - 4, 1))
                            // Gefocust blok boven zijn buren, anders tekent de volgende het van links naar rechts over de rand.
                            .zIndex(focused == target ? 1 : 0)
                        }
                    }
                }
                // Idem tussen rijen: de rij met focus boven de rij eronder (schaal + schaduw lopen eroverheen).
                .zIndex(focused?.channelID == channel.id ? 1 : 0)
            }
        }
        .focusSection()
    }

    private func placeInitially(grid: TimeGrid) {
        guard !didPlaceInitially else { return }
        didPlaceInitially = true
        referenceTime = now
        let x = grid.initialOffset(now: now)
        rowsPosition.scrollTo(x: x)
        headerPosition.scrollTo(x: x)
        // Initiële focus: huidig programma van de eerste zender.
        if let first = guide.channels.first,
           let live = first.programs.first(where: { $0.isLive(at: now) }) ?? first.programs.first(where: { $0.end > now }) {
            focused = FocusTarget(channelID: first.id, start: live.start)
        }
    }

    private func jumpToEvening(grid: TimeGrid) {
        let evening = TimeGrid.eveningDate(relativeTo: anchor)
        let visibleWidth = viewportWidth - channelColumnWidth
        let targetX = max(0, grid.x(for: evening) - (visibleWidth / 2))
        withAnimation(.easeInOut(duration: 0.35)) {
            rowsPosition.scrollTo(x: targetX)
            headerPosition.scrollTo(x: targetX)
        }
        referenceTime = evening
        let channelID = focused?.channelID ?? focus?.channelID ?? guide.channels.first?.id
        if let channelID,
           let channel = guide.channels.first(where: { $0.id == channelID }),
           let target = channel.program(at: evening) {
            focused = FocusTarget(channelID: channelID, start: target.start)
            focus = focused
            Task { @MainActor in
                focused = FocusTarget(channelID: channelID, start: target.start)
                // tvOS scrolt het gefocuste blok minimaal in beeld en overschrijft zo de centrering;
                // zet 20:00 na de focuswissel opnieuw in het midden.
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeInOut(duration: 0.25)) {
                    rowsPosition.scrollTo(x: targetX)
                    headerPosition.scrollTo(x: targetX)
                }
            }
        }
    }
}

private struct TimeHeader: View {
    let grid: TimeGrid

    var body: some View {
        HStack(spacing: 0) {
            ForEach(grid.slots, id: \.self) { slot in
                Text(BrusselsTime.format(slot))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
                    .frame(width: grid.slotWidth, alignment: .leading)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1)
                    }
            }
        }
        .frame(width: grid.totalWidth, alignment: .leading)
    }
}

private struct ChannelCell: View {
    let channel: Channel
    let logo: URL?
    let logoFiles: [String: String]
    let height: CGFloat

    var body: some View {
        HStack(spacing: 14) {
            ChannelLogo(bundled: BundledLogo.image(for: channel, files: logoFiles), remote: logo)
                .frame(width: 64, height: 48)
            Text(channel.name)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: height)
    }
}

private struct ChannelLogo: View {
    let bundled: UIImage?
    let remote: URL?

    var body: some View {
        if let bundled {
            Image(uiImage: bundled).resizable().scaledToFit()
        } else {
            AsyncImage(url: remote) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
        }
    }
}
