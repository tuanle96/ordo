import SwiftUI
import UIKit

struct ReadOnlyFieldRow: View {
    let model: ReadOnlyFieldRowModel

    var body: some View {
        switch model.style {
        case .standard:
            row(multiline: false)
        case .multiline:
            row(multiline: true)
        case .image:
            imageRow
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

    @ViewBuilder
    private func row(multiline: Bool) -> some View {
        LabeledContent(model.label) {
            Text(model.value)
                .multilineTextAlignment(.trailing)
                .lineLimit(multiline ? nil : 1)
                .accessibilityIdentifier("field-value-\(model.id)")
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
        }
        .accessibilityIdentifier("field-row-\(model.id)")
    }
}

#Preview {
    List {
        ReadOnlyFieldRow(model: ReadOnlyFieldRowModel(id: "name", label: "Name", value: "Azure Interior", style: .standard))
        ReadOnlyFieldRow(model: ReadOnlyFieldRowModel(id: "comment", label: "Notes", value: "Preferred customer", style: .multiline))
        ReadOnlyFieldRow(model: ReadOnlyFieldRowModel(id: "state", label: "Status", value: "Active", style: .status))
    }
}