//
//  ProjectsView.swift
//  TestStealthyUI
//
//  Projects list with search, sort, and create/edit functionality.
//

import SwiftUI

struct ProjectsView: View {
    @Binding var projects: [Project]
    @Binding var pendingEditProjectID: UUID?
    @EnvironmentObject var appStore: AppStore
    @Binding var selection: SidebarSelection?
    @State private var search: String = ""
    @State private var sort: Sort = .recentActivity
    @State private var showingCreate: Bool = false
    @State private var draftTitle: String = ""
    @State private var draftDescription: String = ""
    @State private var hoveredProjectID: UUID? = nil
    @State private var editingProjectID: UUID? = nil
    @State private var path: [UUID] = []
    @State private var showProjectDeleteConfirm: Bool = false
    @State private var deleteTargetProjectID: UUID? = nil

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
        }
        .sheet(isPresented: $showingCreate) {
            createProjectSheet
        }
        .navigationDestination(for: UUID.self) { id in
            if let idx = projects.firstIndex(where: { $0.id == id }) {
                ProjectDetailView(project: $projects[idx], onBack: {
                    path.removeLast()
                }, onDelete: {
                    projects.remove(at: idx)
                    path.removeLast()
                }, onEdit: { p in
                    pendingEditProjectID = p.id
                }, onToggleFavorite: {
                    if projects[idx].flaggedAt == nil {
                        projects[idx].flaggedAt = Date()
                    } else {
                        projects[idx].flaggedAt = nil
                    }
                })
            } else {
                Text("Project not found")
            }
        }
        .alert("Delete Project?", isPresented: $showProjectDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                deleteTargetProjectID = nil
            }
            Button("Delete", role: .destructive) {
                if let id = deleteTargetProjectID, let project = projects.first(where: { $0.id == id }) {
                    deleteProject(project)
                }
                deleteTargetProjectID = nil
            }
        } message: {
            if let id = deleteTargetProjectID, let project = projects.first(where: { $0.id == id }) {
                Text("Are you sure you want to delete \"\(project.title)\"? This action cannot be undone.")
            } else {
                Text("This action cannot be undone.")
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
        ProjectEditorView(
            modeTitle: editingProjectID == nil ? "Create a personal project" : "Edit project",
            primaryButtonTitle: editingProjectID == nil ? "Create project" : "Save changes",
            initialTitle: draftTitle,
            initialDescription: draftDescription,
            initialTags: {
                if let editID = editingProjectID, let idx = projects.firstIndex(where: { $0.id == editID }) {
                    return projects[idx].tags
                }
                return []
            }(),
            initialIconSymbol: {
                if let editID = editingProjectID, let idx = projects.firstIndex(where: { $0.id == editID }) {
                    return projects[idx].iconSymbol ?? "folder"
                }
                return "folder"
            }(),
            initialIconColor: {
                if let editID = editingProjectID, let idx = projects.firstIndex(where: { $0.id == editID }) {
                    return projects[idx].iconColor
                }
                return nil
            }(),
            onCancel: { cancelCreate() },
            onSave: { title, desc, tags, iconSymbol, iconColor in
                if let editID = editingProjectID {
                    appStore.updateProject(id: editID, title: title, description: desc, tags: tags, iconSymbol: iconSymbol, iconColor: iconColor)
                    showingCreate = false
                } else {
                    let newID = appStore.createProject(title: title, description: desc, iconSymbol: iconSymbol ?? "folder", iconColor: iconColor)
                    if let idx = projects.firstIndex(where: { $0.id == newID }) {
                        projects[idx].tags = Array(tags.prefix(10))
                    }
                    showingCreate = false
                    selection = .project(newID)
                }
            }
        )
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
                    selection = .project(project.id)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            if let symbol = project.iconSymbol {
                                Image(systemName: symbol)
                                    .foregroundStyle((project.iconColor ?? .gray).color)
                                    .imageScale(.medium)
                            }
                            Text(project.title)
                                .font(.title3).bold()
                        }
                        if !project.description.isEmpty {
                            Text(project.description)
                                .foregroundStyle(.secondary)
                        }
                        if !project.tags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(project.tags.prefix(10), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Color.secondary.opacity(0.15))
                                        )
                                }
                            }
                        }
                        Text("Updated \(relativeDate(project.updatedAt))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(hoveredProjectID == project.id ? 0.14 : 0.08))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .animation(.easeInOut(duration: 0.12), value: hoveredProjectID)
                }
                .buttonStyle(.plain)
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
                                Label(project.flaggedAt == nil ? "Star" : "Unstar", systemImage: project.flaggedAt == nil ? "star.fill" : "star")
                            }
                            Divider()
                            Button { editProject(project) } label: { Label("Edit", systemImage: "pencil") }
                            Divider()
                            Button(role: .destructive) {
                                deleteTargetProjectID = project.id
                                showProjectDeleteConfirm = true
                            } label: { Label("Delete", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis")
                                .imageScale(.large)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
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
                        Label(project.flaggedAt == nil ? "Star" : "Unstar", systemImage: project.flaggedAt == nil ? "star.fill" : "star")
                    }
                    Divider()
                    Button(role: .destructive) {
                        deleteTargetProjectID = project.id
                        showProjectDeleteConfirm = true
                    } label: { Label("Delete", systemImage: "trash") }
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
}

