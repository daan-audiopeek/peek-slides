import AppKit
import PresenterCore
import SwiftUI

/// Settings shared by the docked media pool, its window and the View menu.
enum MediaPool {
    static let visibleKey = "mediaPool.visible"
    static let detachedKey = "mediaPool.detached"
    static let heightKey = "mediaPool.height"
    static let windowID = "mediaPool"
    static let heightRange: ClosedRange<CGFloat> = 120 ... 520
}

/// A grid of the media library for running a show: one click sends a tile
/// live, a live tile wears a green ring, and tiles drag into the run order.
/// Shown docked under the Present stage or in its own window.
struct MediaPoolView: View {
    let model: AppModel
    let controls: ServiceControls?
    /// Docked: offers pop-out and close; in a window it fills the window.
    var docked = true

    @AppStorage("mediaPool.folder") private var folder = ""
    @AppStorage("mediaPool.tileWidth") private var tileWidth = 132.0
    @AppStorage(MediaPool.visibleKey) private var visible = true
    @AppStorage(MediaPool.detachedKey) private var detached = false
    @State private var query = ""
    @State private var menuState = MediaCueMenuState()
    @Environment(\.openWindow) private var openWindow

    private var folderPaths: [String] { model.folders(in: .media) }

    private var entries: [LibraryIndex.Entry] {
        let scoped = folder.isEmpty || !folderPaths.contains(folder)
            ? model.entries(in: .media)
            : model.entriesUnder(in: .media, prefix: folder.split(separator: "/").map(String.init))
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let matching = trimmed.isEmpty ? scoped : scoped.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        return matching.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            let shown = entries
            if shown.isEmpty {
                Text(query.isEmpty ? "No media here yet. Import files in the library's Media tab." : "No media matches.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: tileWidth, maximum: tileWidth * 1.4), spacing: 10)],
                        alignment: .leading, spacing: 10
                    ) {
                        ForEach(shown, id: \.id) { entry in
                            tile(entry)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .mediaCueSheets(model: model, state: menuState)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Media")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            folderMenu
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
                    .font(.caption)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle.standard(CornerStandard.element))
            .frame(maxWidth: 220)
            Spacer(minLength: 8)
            Slider(value: $tileWidth, in: 90 ... 240)
                .controlSize(.mini)
                .frame(width: 90)
                .help("Tile size")
            if docked {
                Button {
                    detached = true
                    openWindow(id: MediaPool.windowID)
                } label: {
                    Image(systemName: "macwindow.on.rectangle")
                }
                .help("Open the media pool in its own window")
                Button {
                    visible = false
                } label: {
                    Image(systemName: "xmark")
                }
                .help("Hide the media pool (View › Show Media Pool brings it back)")
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .frame(height: 30)
    }

    private var folderMenu: some View {
        Menu {
            Button("All Media") { folder = "" }
            if !folderPaths.isEmpty {
                Divider()
                ForEach(folderPaths, id: \.self) { path in
                    Button(path) { folder = path }
                }
            }
        } label: {
            Text(folder.isEmpty || !folderPaths.contains(folder) ? "All Media" : folder)
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func tile(_ entry: LibraryIndex.Entry) -> some View {
        let isLive = controls?.isMediaLive(entry.id) ?? false
        let missing = model.media(entry.id).map { model.isMediaFileMissing($0) } ?? true
        let shape = RoundedRectangle.standard(CornerStandard.element)
        return VStack(alignment: .leading, spacing: 4) {
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay { PosterImage(model: model, mediaId: entry.id) }
                .clipShape(shape)
                .overlay {
                    shape.strokeBorder(
                        isLive ? Color.green : Color.separator.opacity(0.6),
                        lineWidth: isLive ? 3 : 1)
                }
                .overlay(alignment: .topTrailing) {
                    if missing {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Color.orange, in: Circle())
                            .padding(4)
                    }
                }
            Text(entry.name)
                .font(.caption)
                .foregroundStyle(isLive ? Color.green : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .contentShape(Rectangle())
        .onTapGesture { fire(entry) }
        .draggable(entry.id)
        .contextMenu {
            MediaCueMenuItems(
                model: model, actionRouter: controls?.actionRouter,
                mediaID: entry.id, state: menuState)
        }
        .help(missing ? "\u{201C}\(entry.name)\u{201D} isn't on this Mac" : "Click to send live")
    }

    private func fire(_ entry: LibraryIndex.Entry) {
        guard let item = model.media(entry.id), !model.isMediaFileMissing(item) else { return }
        controls?.fire(mediaItem: item)
    }
}

/// The media pool's own window: lets it live on a second display. Closing it
/// docks the pool back under the Present stage.
struct MediaPoolWindowView: View {
    let model: AppModel
    let controls: ServiceControls?

    @AppStorage("app.appearance") private var appearanceRaw = AppAppearance.dark.rawValue
    @AppStorage(MediaPool.detachedKey) private var detached = false
    @AppStorage(MediaPool.visibleKey) private var visible = true

    var body: some View {
        MediaPoolView(model: model, controls: controls, docked: false)
            .background(Color.basePlane)
            .focusedSceneValue(\.serviceControls, controls)
            .background(
                ModuleWindowConfigurator(autosaveName: "mediaPool.window") {
                    detached = false
                    visible = true
                }
            )
            .onAppear { detached = true }
            .navigationTitle("Media Pool")
            .frame(minWidth: 360, minHeight: 240)
            .preferredColorScheme((AppAppearance(rawValue: appearanceRaw) ?? .dark).colorScheme)
    }
}
