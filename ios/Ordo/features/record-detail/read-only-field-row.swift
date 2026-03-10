import SwiftUI
import QuickLook
import UIKit

struct ReadOnlyFieldRow: View {
    @Environment(AppState.self) private var appState

    let model: ReadOnlyFieldRowModel

    @State private var previewFile: TemporaryAttachmentFile?
    @State private var exportFile: TemporaryAttachmentFile?

    var body: some View {
        Group {
            switch model.style {
            case .standard:
                if model.attachment?.kind == .document {
                    attachmentValueRow(multiline: false)
                } else if case .row(let destination)? = model.relationPresentation {
                    relationRow(destination: destination)
                } else if case .chips(let destinations)? = model.relationPresentation {
                    relationChipsRow(destinations: destinations)
                } else {
                    row(multiline: false)
                }
            case .multiline:
                row(multiline: true)
            case .image:
                imageRow
            case .signature:
                signatureRow
            case .status:
                LabeledContent(model.label) {
                    Label(model.value, systemImage: "circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("field-value-\(model.id)")
                }
                .accessibilityIdentifier("field-row-\(model.id)")
            case .phone:
                ActionableFieldRow(
                    label: model.label,
                    value: model.value,
                    action: .phone(model.value),
                    fieldID: model.id
                )
            case .email:
                ActionableFieldRow(
                    label: model.label,
                    value: model.value,
                    action: .email(model.value),
                    fieldID: model.id
                )
            case .url:
                ActionableFieldRow(
                    label: model.label,
                    value: model.value,
                    action: .url(model.value),
                    fieldID: model.id
                )
            case .unsupported(let fieldType):
                LabeledContent(model.label) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(model.value)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("field-value-\(model.id)")
                        Text(fieldType == .unsupported ? "Unsupported field" : "Unsupported type: \(fieldType.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("field-row-\(model.id)")
            }
        }
        .sheet(item: $previewFile, onDismiss: cleanupPreviewFile) { file in
            QuickLookPreviewSheet(fileURL: file.url)
        }
        .sheet(item: $exportFile, onDismiss: cleanupExportFile) { file in
            ShareSheet(activityItems: [file.url])
        }
    }

    private func descriptor(for destination: ReadOnlyRelationDestination) -> ModelDescriptor {
        appState.modelDescriptor(for: destination.model)
    }

    @ViewBuilder
    private func row(multiline: Bool) -> some View {
        LabeledContent(model.label) {
            if multiline, let richText = model.richText {
                Text(richText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(nil)
                    .accessibilityIdentifier("field-value-\(model.id)")
            } else {
                Text(model.value)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(multiline ? nil : 1)
                    .accessibilityIdentifier("field-value-\(model.id)")
            }
        }
        .accessibilityIdentifier("field-row-\(model.id)")
    }

    private func relationRow(destination: ReadOnlyRelationDestination) -> some View {
        NavigationLink {
            RecordDetailView(
                descriptor: descriptor(for: destination),
                recordID: destination.recordID
            )
        } label: {
            LabeledContent(model.label) {
                HStack(spacing: 6) {
                    Text(model.value)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .accessibilityIdentifier("field-value-\(model.id)")
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("field-link-\(model.id)")
        }
        .buttonStyle(.plain)
    }

    private func relationChipsRow(destinations: [ReadOnlyRelationDestination]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.label)
                .font(.subheadline.weight(.medium))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(destinations) { destination in
                    NavigationLink {
                        RecordDetailView(
                            descriptor: descriptor(for: destination),
                            recordID: destination.recordID
                        )
                    } label: {
                        HStack(spacing: 6) {
                            Text(destination.label)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("field-relation-\(model.id)-\(destination.recordID)")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityIdentifier("field-row-\(model.id)")
    }

    @ViewBuilder
    private func attachmentValueRow(multiline: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(model.label) {
                Text(model.value)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(multiline ? nil : 1)
                    .accessibilityIdentifier("field-value-\(model.id)")
            }

            attachmentActions
        }
        .accessibilityIdentifier("field-row-\(model.id)")
    }

    @ViewBuilder
    private var imageRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.label)
                .font(.subheadline.weight(.medium))

            if let previewData = model.previewData,
               let previewImage = UIImage(data: previewData) {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("field-image-\(model.id)")
            } else {
                Text(model.value)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("field-value-\(model.id)")
            }

            attachmentActions
        }
        .accessibilityIdentifier("field-row-\(model.id)")
    }

    @ViewBuilder
    private var signatureRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.label)
                .font(.subheadline.weight(.medium))

            if let previewData = model.previewData,
               let previewImage = UIImage(data: previewData) {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: 160)
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("field-signature-\(model.id)")
            } else {
                Text(model.value)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("field-value-\(model.id)")
            }

            attachmentActions
        }
        .accessibilityIdentifier("field-row-\(model.id)")
    }

    @ViewBuilder
    private var attachmentActions: some View {
        if model.attachment != nil {
            HStack(spacing: 12) {
                Button("Preview") {
                    previewAttachment()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("field-preview-\(model.id)")

                Button("Export") {
                    exportAttachment()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("field-export-\(model.id)")
            }
            .font(.subheadline.weight(.medium))
        }
    }

    private func previewAttachment() {
        previewFile = temporaryFile()
    }

    private func exportAttachment() {
        exportFile = temporaryFile()
    }

    private func temporaryFile() -> TemporaryAttachmentFile? {
        guard let attachment = model.attachment else { return nil }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ordo-inline-preview", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("\(UUID().uuidString)-\(attachment.filename)")
            try attachment.data.write(to: url, options: .atomic)
            return TemporaryAttachmentFile(url: url)
        } catch {
            return nil
        }
    }

    private func cleanupPreviewFile() {
        cleanup(file: previewFile)
        previewFile = nil
    }

    private func cleanupExportFile() {
        cleanup(file: exportFile)
        exportFile = nil
    }

    private func cleanup(file: TemporaryAttachmentFile?) {
        guard let file else { return }
        try? FileManager.default.removeItem(at: file.url)
    }
}

private struct TemporaryAttachmentFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct QuickLookPreviewSheet: UIViewControllerRepresentable {
    let fileURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.fileURL = fileURL
        uiViewController.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var fileURL: URL

        init(fileURL: URL) {
            self.fileURL = fileURL
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            fileURL as NSURL
        }
    }
}

#Preview {
    List {
        ReadOnlyFieldRow(model: ReadOnlyFieldRowModel(id: "name", label: "Name", value: "Azure Interior", style: .standard))
        ReadOnlyFieldRow(model: ReadOnlyFieldRowModel(id: "comment", label: "Notes", value: "Preferred customer", style: .multiline))
        ReadOnlyFieldRow(model: ReadOnlyFieldRowModel(id: "state", label: "Status", value: "Active", style: .status))
    }
    .environment(AppState.preview)
}