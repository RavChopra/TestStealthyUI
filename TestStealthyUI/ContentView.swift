import SwiftUI
#if os(macOS)
import AppKit
#endif

// A 1-pixel thin separator, matching Finder's divider thickness
private struct HairlineSeparator: View {
    var body: some View {
        Rectangle()
            .foregroundStyle(.separator)
            .frame(height: hairlineWidth)
    }

    private var hairlineWidth: CGFloat {
#if os(macOS)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
#else
        let scale = UIScreen.main.scale
#endif
        return 1.0 / scale
    }
}

// MARK: - Chat Model
private struct Message: Identifiable, Equatable {
    let id = UUID()
    var text: String
    let isUser: Bool
}

// MARK: - Detail
private struct DetailView: View {
    let title: String
    @Binding var projects: [Project]
    @Binding var pendingEditProjectID: UUID?

    @State private var messages: [Message] = [
        Message(text: "Got it — I'm here and working fine. What would you like to test?", isUser: false)
    ]
    @State private var input: String = ""

    var body: some View {
        Group {
            if title == "Projects" {
                ProjectsView(projects: $projects, pendingEditProjectID: $pendingEditProjectID)
            } else {
                VStack(spacing: 0) {
                    HairlineSeparator()
                    chatScroll
                    inputBar
                }
            }
        }
        .background(Color.clear)
    }

    // MARK: Chat Scroll
    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        HStack(alignment: .bottom) {
                            if message.isUser {
                                Spacer(minLength: 40)
                                Text(message.text)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.secondary.opacity(0.2))
                                    )
                                    .foregroundStyle(.primary)
                            } else {
                                Text(message.text)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .onChange(of: messages) { _, _ in
                if let last = messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: Input Bar
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask anything", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...12) // Expands up to 12 lines, then becomes scrollable
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                )
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .imageScale(.medium)
            }
            .keyboardShortcut(.return, modifiers: []) // Press Return to send
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }

    // MARK: Actions
    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(Message(text: trimmed, isUser: true))
        input = ""

        // Start a simulated streaming/typing response
        let fullResponse = "You said: \(trimmed)"
        startTyping(response: fullResponse)
    }
    
    private func startTyping(response: String) {
        // Append an empty assistant message first
        messages.append(Message(text: "", isUser: false))
        let index = messages.count - 1

        Task {
            for ch in response {
                try? await Task.sleep(nanoseconds: 25_000_000) // ~40 chars/sec
                await MainActor.run {
                    messages[index].text.append(ch)
                }
            }
        }
    }
}

struct ContentView: View {
    // Controls whether the sidebar is shown, hidden, or automatic
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedItem: String? = "Welcome"
    @State private var conversationID = UUID()
    @State private var conversations: [String] = [
        "Welcome", "Documents", "Downloads", "Pictures", "Music"
    ]
    @State private var projects: [Project] = [
        Project(title: "Test project", description: "Testing the create project functionality", updatedAt: Date().addingTimeInterval(-4*60)),
        Project(title: "StealthyAI", description: "", updatedAt: Date().addingTimeInterval(-19*24*3600)),
        Project(title: "How to use Claude", description: "An example project that also doubles as a how-to guide for using Claude.", updatedAt: Date().addingTimeInterval(-19*24*3600))
    ]
    @State private var pendingEditProjectID: UUID? = nil

    @State private var showingSidebarEdit: Bool = false
    @State private var sidebarEditDraftTitle: String = ""
    @State private var sidebarEditDraftDescription: String = ""
    @State private var sidebarEditingProjectID: UUID? = nil

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(selectedItem: $selectedItem, conversations: $conversations, projects: $projects, pendingEditProjectID: $pendingEditProjectID)
        } detail: {
            DetailView(title: selectedItem ?? "", projects: $projects, pendingEditProjectID: $pendingEditProjectID)
                .id(conversationID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
        }
        .toolbar {
#if os(macOS)
            ToolbarItem(placement: .navigation) {
                Button {
                    // Create a uniquely named conversation, select it, and reset the chat view
                    let base = "New Conversation"
                    var name = base
                    var i = 2
                    while conversations.contains(name) {
                        name = "\(base) \(i)"
                        i += 1
                    }
                    conversations.insert(name, at: 0)
                    selectedItem = name
                    conversationID = UUID()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Conversation")
                .keyboardShortcut("n", modifiers: [.command])
            }
#endif
        }
        .onChange(of: pendingEditProjectID) { _, newValue in
            if let id = newValue, let idx = projects.firstIndex(where: { $0.id == id }) {
                let project = projects[idx]
                sidebarEditingProjectID = id
                sidebarEditDraftTitle = project.title
                sidebarEditDraftDescription = project.description
                showingSidebarEdit = true
                pendingEditProjectID = nil
            }
        }
        .sheet(isPresented: $showingSidebarEdit) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Edit project").font(.largeTitle).bold()
                VStack(alignment: .leading, spacing: 8) {
                    Text("What are you working on?").font(.headline)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.secondary.opacity(0.4))
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.secondary.opacity(0.08))
                            )
                        TextField("", text: $sidebarEditDraftTitle, prompt: Text("Name your project"))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    .frame(height: 44)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("What are you trying to achieve?").font(.headline)
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.secondary.opacity(0.4))
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.secondary.opacity(0.08))
                            )
                        TextEditor(text: $sidebarEditDraftDescription)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 10)
                            .padding(.top, 14)
                            .padding(.bottom, 10)
                            .background(Color.clear)
                        if sidebarEditDraftDescription.isEmpty {
                            Text("Describe your project, goals, subject, etc...")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                        }
                    }
                    .frame(minHeight: 140)
                }
                HStack {
                    Spacer()
                    Button("Cancel") { showingSidebarEdit = false }
                    Button("Save changes") {
                        if let id = sidebarEditingProjectID, let idx = projects.firstIndex(where: { $0.id == id }) {
                            let title = sidebarEditDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            let desc = sidebarEditDraftDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !title.isEmpty else { return }
                            projects[idx].title = title
                            projects[idx].description = desc
                            projects[idx].updatedAt = Date()
                        }
                        showingSidebarEdit = false
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(sidebarEditDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
            .frame(maxWidth: 720)
        }
    }

#if os(macOS)
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
#endif
}

// MARK: - Sidebar
private struct SidebarView: View {
    @Binding var selectedItem: String?
    @Binding var conversations: [String]
    @Binding var projects: [Project]
    @Binding var pendingEditProjectID: UUID?
    @State private var searchText: String = ""
    @State private var editingItem: String? = nil
    @State private var draftTitle: String = ""
    @State private var archived: Set<String> = []

    private var flaggedProjects: [Project] {
        projects
            .filter { $0.flaggedAt != nil }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var filteredItems: [String] {
        let visible = conversations.filter { !archived.contains($0) }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return visible }
        return visible.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Liquid Glass background filling the sidebar
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 0))
                .ignoresSafeArea()

            VStack(spacing: 6) {
                // Search + Compose
                HStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("", text: $searchText, prompt: Text("Search"))
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: 28)
                .padding(.horizontal, 8)
                .padding(.top, 6)

                // Sidebar list
                List(selection: $selectedItem) {
                    Section("Projects") {
                        NavigationLink(value: "Projects") {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                Text("Projects")
                                    .padding(.horizontal, 8)
                            }
                        }
                        ForEach(flaggedProjects) { p in
                            NavigationLink(value: p.title) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                    Text(p.title)
                                        .padding(.horizontal, 8)
                                }
                            }
                            .contextMenu {
                                Button {
                                    setFlag(nil, for: p.id)
                                } label: {
                                    Label("Unflag", systemImage: "flag")
                                }
                                Button {
                                    pendingEditProjectID = p.id
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    deleteProject(p)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    Section("Conversations") {
                        ForEach(filteredItems, id: \.self) { item in
                            NavigationLink(value: item) {
                                if editingItem == item {
                                    TextField("Title", text: $draftTitle)
                                        .textFieldStyle(.plain)
                                        .onSubmit { commitRename(original: item) }
                                        .onExitCommand { cancelRename() }
                                        .padding(.horizontal, 8)
                                } else {
                                    Text(item)
                                        .padding(.horizontal, 8)
                                }
                            }
                            .contextMenu {
                                Button("Rename") { beginRename(item) }
                                Button("Archive") { archive(item) }
                                Button("Delete", role: .destructive) { delete(item) }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden) // Let the glass show through
        }
    }

    // MARK: - Project Actions
    private func newProject() {
        // TODO: Implement new project flow
    }

    // MARK: - Actions
    private func beginRename(_ item: String) {
        editingItem = item
        draftTitle = item
    }

    private func commitRename(original: String) {
        let newTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else { cancelRename(); return }
        if let idx = conversations.firstIndex(of: original) {
            conversations[idx] = newTitle
            if selectedItem == original { selectedItem = newTitle }
        }
        editingItem = nil
        draftTitle = ""
    }

    private func cancelRename() {
        editingItem = nil
        draftTitle = ""
    }

    private func delete(_ item: String) {
        conversations.removeAll { $0 == item }
        archived.remove(item)
        if selectedItem == item { selectedItem = nil }
    }

    private func archive(_ item: String) {
        archived.insert(item)
        if selectedItem == item { selectedItem = nil }
    }

    private func symbol(for item: String) -> String {
        switch item {
        case "Welcome": return "sparkles"
        case "Documents": return "doc.text"
        case "Downloads": return "arrow.down.circle"
        case "Pictures": return "photo"
        case "Music": return "music.note"
        default: return "folder"
        }
    }
    
    private func setFlag(_ color: FlagColor?, for projectID: UUID) {
        if let idx = projects.firstIndex(where: { $0.id == projectID }) {
            projects[idx].flagColor = color
            projects[idx].flaggedAt = (color == nil ? nil : Date())
        }
    }
    
    private func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
    }
}

// MARK: - Projects Model
private enum FlagColor: String, CaseIterable, Codable, Equatable {
    case red, orange, yellow, green, blue, teal, purple, gray
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .teal: return .teal
        case .purple: return .purple
        case .gray: return .gray
        }
    }
    
    var accessibilityName: String {
        switch self {
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .teal: return "Teal"
        case .purple: return "Purple"
        case .gray: return "Gray"
        }
    }
}

private struct Project: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var description: String
    var updatedAt: Date
    var flaggedAt: Date? = nil
    var flagColor: FlagColor? = nil
}

// MARK: - Projects List
private struct ProjectsView: View {
    @Binding var projects: [Project]
    @Binding var pendingEditProjectID: UUID?
    @State private var search: String = ""
    @State private var sort: Sort = .recentActivity
    @State private var showingCreate: Bool = false
    @State private var draftTitle: String = ""
    @State private var draftDescription: String = ""
    @State private var hoveredProjectID: UUID? = nil
    @State private var editingProjectID: UUID? = nil
    @State private var path: [UUID] = []

    enum Sort { case recentActivity, recentlyCreated }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 16) {
                header
                searchRow
#if os(macOS)
                if #available(macOS 14.0, *) {
                    ScrollView {
                        list
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.top, 4)
                    }
                } else {
                    ScrollView {
                        list
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.top, 4)
                    }
                }
#else
                ScrollView {
                    list
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.top, 4)
                }
#endif
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .sheet(isPresented: $showingCreate) {
                createProjectSheet
            }
            .navigationDestination(for: UUID.self) { id in
                if let idx = projects.firstIndex(where: { $0.id == id }) {
                    ProjectDetailView(
                        project: $projects[idx],
                        onBack: { path.removeAll() },
                        onDelete: {
                            projects.remove(at: idx)
                            path.removeAll()
                        },
                        onEdit: { p in
                            draftTitle = p.title
                            draftDescription = p.description
                            editingProjectID = p.id
                            showingCreate = true
                        },
                        onToggleFavorite: {
                            if projects[idx].flaggedAt == nil {
                                projects[idx].flaggedAt = Date()
                            } else {
                                projects[idx].flaggedAt = nil
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: Header
    private var header: some View {
        HStack {
            Text("Projects")
                .font(.largeTitle).bold()
            Spacer()
            Button(action: newProject) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                    Text("New Project")
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: Search + Sort
    private var searchRow: some View {
        HStack(alignment: .center, spacing: 24) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.secondary.opacity(0.4))
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("", text: $search, prompt: Text("Search projects…"))
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)

            Menu {
                Button {
                    sort = .recentActivity
                } label: {
                    HStack {
                        Text("Recent Activity")
                        if sort == .recentActivity { Image(systemName: "checkmark") }
                    }
                }
                Button {
                    sort = .recentlyCreated
                } label: {
                    HStack {
                        Text("Recently Created")
                        if sort == .recentlyCreated { Image(systemName: "checkmark") }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
        }
    }

    private var createProjectSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(editingProjectID == nil ? "Create a personal project" : "Edit project")
                .font(.largeTitle).bold()

            VStack(alignment: .leading, spacing: 8) {
                Text("What are you working on?")
                    .font(.headline)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    TextField("", text: $draftTitle, prompt: Text("Name your project"))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .frame(height: 44)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What are you trying to achieve?")
                    .font(.headline)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.4))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    TextEditor(text: $draftDescription)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .background(Color.clear)
                    if draftDescription.isEmpty {
                        Text("Describe your project, goals, subject, etc...")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                }
                .frame(minHeight: 140)
            }

            HStack {
                Spacer()
                Button("Cancel") { cancelCreate() }
                Button(editingProjectID == nil ? "Create project" : "Save changes") { saveProject() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(maxWidth: 720)
    }

    // MARK: List
    private var list: some View {
        let filtered = projects.filter { p in
            search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            p.title.localizedCaseInsensitiveContains(search) ||
            p.description.localizedCaseInsensitiveContains(search)
        }.sorted(by: { a, b in
            // Flagged first (most recently flagged at the top)
            switch (a.flaggedAt, b.flaggedAt) {
            case let (ad?, bd?):
                if ad != bd { return ad > bd }
                // If both flagged at the same time, fall back to secondary sort
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }
            // Secondary sort based on current selection
            switch sort {
            case .recentActivity:
                return a.updatedAt > b.updatedAt
            case .recentlyCreated:
                return a.id.uuidString < b.id.uuidString
            }
        })

        return LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(filtered) { project in
                Button {
                    path.append(project.id)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(project.title)
                            .font(.title3).bold()
                        if !project.description.isEmpty {
                            Text(project.description)
                                .foregroundStyle(.secondary)
                        }
                        Text("Updated \(relativeDate(project.updatedAt))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .overlay(alignment: .topTrailing) {
                    if hoveredProjectID == project.id {
                        Menu {
                            Button {
                                if project.flaggedAt == nil {
                                    toggleFlag(project)
                                } else {
                                    toggleFlag(project)
                                }
                            } label: {
                                Label(project.flaggedAt == nil ? "Flag" : "Unflag", systemImage: project.flaggedAt == nil ? "flag.fill" : "flag")
                            }
                            Divider()
                            Button { editProject(project) } label: { Label("Edit", systemImage: "pencil") }
                            Divider()
                            Button(role: .destructive) { deleteProject(project) } label: { Label("Delete", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis").imageScale(.large)
                        }
                        .menuIndicator(.hidden)
                        .buttonStyle(.borderless)
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                    }
                }
#if os(macOS)
                .onHover { hovering in
                    if hovering {
                        hoveredProjectID = project.id
                    } else if hoveredProjectID == project.id {
                        hoveredProjectID = nil
                    }
                }
#endif
                .contextMenu {
                    Button {
                        toggleFlag(project)
                    } label: {
                        Label(project.flaggedAt == nil ? "Flag" : "Unflag", systemImage: project.flaggedAt == nil ? "flag.fill" : "flag")
                    }
                    Divider()
                    Button(role: .destructive) { deleteProject(project) } label: { Label("Delete", systemImage: "trash") }
                    Button { editProject(project) } label: { Label("Edit", systemImage: "pencil") }
                }
            }
        }
    }

    private func toggleFlag(_ project: Project) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            if projects[idx].flaggedAt == nil {
                projects[idx].flaggedAt = Date()
            } else {
                projects[idx].flaggedAt = nil
            }
        }
    }
    
    private func setFlag(_ color: FlagColor?, for project: Project) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx].flagColor = color
            projects[idx].flaggedAt = (color == nil ? nil : Date())
        }
    }

    private func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func newProject() {
        draftTitle = ""
        draftDescription = ""
        editingProjectID = nil
        showingCreate = true
    }

    private func editProject(_ project: Project) {
        draftTitle = project.title
        draftDescription = project.description
        editingProjectID = project.id
        showingCreate = true
    }

    private func cancelCreate() {
        showingCreate = false
    }

    private func saveProject() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = draftDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if let editingID = editingProjectID, let idx = projects.firstIndex(where: { $0.id == editingID }) {
            projects[idx].title = title
            projects[idx].description = desc
            projects[idx].updatedAt = Date()
        } else {
            projects.insert(Project(title: title, description: desc, updatedAt: Date()), at: 0)
        }
        showingCreate = false
    }
}

// MARK: - Project Detail
private struct ProjectDetailView: View {
    @Binding var project: Project
    var onBack: () -> Void
    var onDelete: () -> Void
    var onEdit: (Project) -> Void
    var onToggleFavorite: () -> Void

    @State private var input: String = ""
    @State private var showingMenu: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Back
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("All projects")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            // Title row
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(.largeTitle).bold()
                    if !project.description.isEmpty {
                        Text(project.description)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Menu {
                    Button {
                        if project.flaggedAt == nil {
                            project.flaggedAt = Date()
                        } else {
                            project.flaggedAt = nil
                        }
                    } label: {
                        Label(project.flaggedAt == nil ? "Flag" : "Unflag", systemImage: project.flaggedAt == nil ? "flag.fill" : "flag")
                    }
                    Divider()
                    Button { onEdit(project) } label: { Label("Edit", systemImage: "pencil") }
                    Divider()
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .imageScale(.large)
                }
                .menuIndicator(.hidden)
                .buttonStyle(.borderless)
            }

            // Chat input area (simple prompt)
            VStack(alignment: .leading, spacing: 8) {
                TextField("How can I help you today?", text: $input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.secondary.opacity(0.25))
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.secondary.opacity(0.06))
                            )
                    )
            }
            .padding(.trailing, 8)

            // Conversations list placeholder linked to project
            VStack(alignment: .leading, spacing: 12) {
                Text("Conversations")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    // Placeholder rows
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(height: 56)
                        .overlay(alignment: .leading) {
                            Text("Test conversation")
                                .padding(.horizontal, 16)
                        }
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(height: 56)
                        .overlay(alignment: .leading) {
                            Text("Project testing approach")
                                .padding(.horizontal, 16)
                        }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

#Preview {
    ContentView()
}

