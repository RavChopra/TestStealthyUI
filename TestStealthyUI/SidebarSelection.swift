//
//  SidebarSelection.swift
//  TestStealthyUI
//
//  Selection type for NavigationSplitView sidebar routing
//

import Foundation

enum SidebarSelection: Hashable, Codable {
    case projects
    case project(UUID)
    case conversation(UUID)
}
