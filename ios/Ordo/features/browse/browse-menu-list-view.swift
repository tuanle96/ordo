import SwiftUI

struct BrowseMenuRowLink: View {
    @Environment(AppState.self) private var appState

    let node: BrowseMenuNode
    let compact: Bool

    var body: some View {
        let descriptor = resolvedDescriptor(for: node)

        NavigationLink {
            destination(for: node)
        } label: {
            HStack(spacing: OrdoSpacing.md) {
                Image(systemName: rowSystemImage(for: node, descriptor: descriptor))
                    .font(.system(size: compact ? 16 : 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: compact ? 32 : 40, height: compact ? 32 : 40)
                    .background(OrdoColors.accent, in: RoundedRectangle(cornerRadius: OrdoRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: OrdoSpacing.xs) {
                    Text(resolvedTitle(for: node, descriptor: descriptor))
                        .font(OrdoTypography.headline)
                        .foregroundStyle(OrdoColors.textPrimary)

                    if !compact {
                        Text(rowSubtitle(for: node, descriptor: descriptor))
                            .font(OrdoTypography.subheadline)
                            .foregroundStyle(OrdoColors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OrdoColors.textTertiary)
            }
            .padding(.vertical, OrdoSpacing.md)
        }
        .accessibilityIdentifier(accessibilityIdentifier(for: node))
    }

    @ViewBuilder
    private func destination(for node: BrowseMenuNode) -> some View {
        if let directNode = directRecordListNode(for: node), let model = directNode.model {
            RecordListView(
                descriptor: appState.modelDescriptor(for: model, fallbackTitle: directNode.name),
                preferredViewMode: directNode.preferredViewMode ?? node.preferredViewMode
            )
        } else {
            BrowseMenuListView(title: node.name, nodes: node.children)
        }
    }

    private func resolvedDescriptor(for node: BrowseMenuNode) -> ModelDescriptor? {
        guard let model = (directRecordListNode(for: node) ?? node).model else {
            return nil
        }

        return appState.modelDescriptor(for: model, fallbackTitle: node.name)
    }

    private func resolvedTitle(for node: BrowseMenuNode, descriptor: ModelDescriptor?) -> String {
        if let directNode = directRecordListNode(for: node) {
            return directNode.name
        }

        return descriptor?.title ?? node.name
    }

    private func rowSubtitle(for node: BrowseMenuNode, descriptor: ModelDescriptor?) -> String {
        if let directNode = directRecordListNode(for: node), directNode.id != node.id {
            return "Open \(directNode.name)"
        }

        if node.children.isEmpty {
            return descriptor?.subtitle ?? "Browse records"
        }

        return node.children.count == 1 ? "1 section" : "\(node.children.count) sections"
    }

    private func rowSystemImage(for node: BrowseMenuNode, descriptor: ModelDescriptor?) -> String {
        if let descriptor {
            return descriptor.systemImage
        }

        switch node.kind {
        case .app:
            return "square.grid.2x2"
        case .category:
            return "folder"
        case .leaf:
            return "doc.text"
        }
    }

    private func directRecordListNode(for node: BrowseMenuNode) -> BrowseMenuNode? {
        if node.isDirectRecordListEntry {
            return node
        }

        guard node.kind == .app,
              node.children.count == 1,
              let onlyChild = node.children.first,
              onlyChild.isDirectRecordListEntry else {
            return nil
        }

        return onlyChild
    }

    private func accessibilityIdentifier(for node: BrowseMenuNode) -> String {
        if let directNode = directRecordListNode(for: node), let model = directNode.model {
            return node.kind == .app
                ? "browse-app-\(sanitizedIdentifierComponent(model))"
                : "browse-model-\(sanitizedIdentifierComponent(model))"
        }

        return node.kind == .app
            ? "browse-app-\(node.id)"
            : "browse-menu-\(node.id)"
    }

    private func sanitizedIdentifierComponent(_ value: String) -> String {
        value.replacingOccurrences(of: ".", with: "-")
    }
}

struct BrowseMenuListView: View {
    @Environment(AppState.self) private var appState

    let title: String
    let nodes: [BrowseMenuNode]

    var body: some View {
        ScrollView {
            VStack(spacing: OrdoSpacing.lg) {
                if nodes.isEmpty {
                    OrdoEmptyStateCard(
                        title: title == "Browse" && appState.browseDiscoveryErrorMessage != nil
                            ? "Browse is unavailable right now"
                            : "No browseable menus found",
                        message: title == "Browse"
                            ? appState.browseDiscoveryErrorMessage
                                ?? "The signed-in user does not currently have any browseable Odoo menu/action entries exposed to the mobile app."
                            : "The signed-in user does not currently have any browseable Odoo menu/action entries exposed to the mobile app.",
                        systemImage: "tray",
                        accessibilityPrefix: "browse-empty-catalog"
                    )
                } else {
                    OrdoCard {
                        VStack(spacing: 0) {
                            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                                BrowseMenuRowLink(node: node, compact: false)

                                if index < nodes.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, OrdoSpacing.lg)
            .padding(.vertical, OrdoSpacing.sm)
        }
        .background(OrdoColors.surfaceGrouped)
        .navigationTitle(title)
        .accessibilityIdentifier(title == "Browse" ? "browse-home-screen" : "browse-menu-screen")
    }
}

#Preview {
    NavigationStack {
        BrowseMenuListView(title: "Browse", nodes: ModelRegistry.fallbackBrowseMenuTree)
            .environment(AppState.preview)
    }
}