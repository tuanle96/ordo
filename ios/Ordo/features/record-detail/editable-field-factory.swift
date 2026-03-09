import SwiftUI
import PencilKit
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct EditableFieldRowModel {
    enum Style {
        case text
        case multiline
        case image
        case signature
        case binary(filenameField: String?)
        case priority
        case integer
        case float
        case monetary(currencyField: String?)
        case date
        case datetime
        case toggle
        case selection(options: [[String]])
        case many2one(comodel: String)
        case one2many(subfields: [FieldSchema])
        case many2many(comodel: String)
    }

    let style: Style
}

enum EditableFieldFactory {
    static func model(for field: FieldSchema) -> EditableFieldRowModel? {
        switch field.type {
        case .char:
            return .init(style: .text)
        case .text, .html:
            return .init(style: .multiline)
        case .image:
            return .init(style: .image)
        case .signature:
            return .init(style: .signature)
        case .binary:
            return .init(style: .binary(filenameField: field.filenameField))
        case .priority:
            return .init(style: .priority)
        case .integer:
            return .init(style: .integer)
        case .float:
            return .init(style: .float)
        case .monetary:
            return .init(style: .monetary(currencyField: field.currencyField))
        case .date:
            return .init(style: .date)
        case .datetime:
            return .init(style: .datetime)
        case .boolean:
            return .init(style: .toggle)
        case .selection:
            return .init(style: .selection(options: field.selection ?? []))
        case .many2one:
            guard let comodel = field.comodel else { return nil }
            return .init(style: .many2one(comodel: comodel))
        case .one2many:
            guard let subfields = field.subfields, !subfields.isEmpty else { return nil }
            return .init(style: .one2many(subfields: subfields))
        case .many2many:
            guard let comodel = field.comodel else { return nil }
            return .init(style: .many2many(comodel: comodel))
        default:
            return nil
        }
    }
}

struct EditableFieldRow: View {
    @Environment(AppState.self) private var appState

    let field: FieldSchema
    let model: EditableFieldRowModel
    let draft: FormDraft
    let fallbackValue: JSONValue?
    let searchDomain: JSONValue?
    let validationMessage: String?
    let onValueChange: ((FieldSchema, JSONValue?) -> Void)?

    @State private var isShowingRelationPicker = false

    var body: some View {
        switch model.style {
        case .text:
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent(field.label) {
                    TextField(field.placeholder ?? field.label, text: stringBinding)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("field-editor-\(field.name)")
                }
                validationText
            }
            .accessibilityIdentifier("field-row-\(field.name)")
        case .multiline:
            VStack(alignment: .leading, spacing: 8) {
                Text(field.label)
                    .font(.subheadline.weight(.medium))
                TextField(field.placeholder ?? field.label, text: stringBinding, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("field-editor-\(field.name)")
                validationText
            }
            .accessibilityIdentifier("field-row-\(field.name)")
        case .image:
            ImageFieldEditor(
                field: field,
                draft: draft,
                fallbackValue: fallbackValue,
                validationMessage: validationMessage,
                onValueChange: onValueChange
            )
            .accessibilityIdentifier("field-row-\(field.name)")
        case .signature:
            SignatureFieldEditor(
                field: field,
                draft: draft,
                fallbackValue: fallbackValue,
                validationMessage: validationMessage,
                onValueChange: onValueChange
            )
            .accessibilityIdentifier("field-row-\(field.name)")
        case .binary:
            BinaryDocumentFieldEditor(
                field: field,
                draft: draft,
                fallbackValue: fallbackValue,
                validationMessage: validationMessage,
                onValueChange: onValueChange
            )
            .accessibilityIdentifier("field-row-\(field.name)")
        case .priority:
            VStack(alignment: .leading, spacing: 8) {
                Text(field.label)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 12) {
                    ForEach(1...3, id: \.self) { rating in
                        Button {
                            applyChange(.string(String(rating)))
                        } label: {
                            Image(systemName: currentPriority >= rating ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundStyle(currentPriority >= rating ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("field-priority-\(field.name)-\(rating)")
                    }

                    Spacer()

                    if currentPriority > 0 {
                        Button("Clear") {
                            applyChange(nil)
                        }
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("field-clear-\(field.name)")
                    }
                }

                validationText
            }
            .accessibilityIdentifier("field-row-\(field.name)")
        case .integer:
            NumericFieldEditor(
                field: field,
                text: numericStringBinding,
                keyboardType: .numberPad,
                validationMessage: validationMessage
            )
            .accessibilityIdentifier("field-row-\(field.name)")
        case .float:
            NumericFieldEditor(
                field: field,
                text: numericStringBinding,
                keyboardType: .decimalPad,
                validationMessage: validationMessage
            )
            .accessibilityIdentifier("field-row-\(field.name)")
        case .monetary(let currencyField):
            NumericFieldEditor(
                field: field,
                text: numericStringBinding,
                keyboardType: .decimalPad,
                validationMessage: validationMessage,
                prefix: monetaryPrefix(currencyField: currencyField)
            )
            .accessibilityIdentifier("field-row-\(field.name)")
        case .date:
            TemporalFieldEditor(
                field: field,
                fallbackValue: fallbackValue,
                validationMessage: validationMessage,
                displayedComponents: [.date],
                includeTime: false,
                onValueChange: onValueChange,
                draft: draft
            )
            .accessibilityIdentifier("field-row-\(field.name)")
        case .datetime:
            TemporalFieldEditor(
                field: field,
                fallbackValue: fallbackValue,
                validationMessage: validationMessage,
                displayedComponents: [.date, .hourAndMinute],
                includeTime: true,
                onValueChange: onValueChange,
                draft: draft
            )
            .accessibilityIdentifier("field-row-\(field.name)")
        case .toggle:
            VStack(alignment: .leading, spacing: 6) {
                Toggle(field.label, isOn: boolBinding)
                    .accessibilityIdentifier("field-editor-\(field.name)")
                validationText
            }
            .accessibilityIdentifier("field-row-\(field.name)")
        case .selection(let options):
            VStack(alignment: .leading, spacing: 6) {
                Picker(field.label, selection: selectionBinding(options: options)) {
                    ForEach(options, id: \.self) { option in
                        if option.count > 1 {
                            Text(option[1]).tag(option[0])
                        }
                    }
                }
                .accessibilityIdentifier("field-editor-\(field.name)")
                validationText
            }
            .accessibilityIdentifier("field-row-\(field.name)")
        case .many2one(let comodel):
            VStack(alignment: .leading, spacing: 8) {
                Text(field.label)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 12) {
                    Button {
                        isShowingRelationPicker = true
                    } label: {
                        HStack {
                            Text(relationLabel ?? field.placeholder ?? "Select \(field.label)")
                                .foregroundStyle(relationLabel == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("field-editor-\(field.name)")

                    if relationLabel != nil {
                        Button("Clear") {
                            applyChange(nil)
                        }
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("field-clear-\(field.name)")
                    }
                }

                validationText
            }
            .accessibilityIdentifier("field-row-\(field.name)")
            .sheet(isPresented: $isShowingRelationPicker) {
                Many2OnePickerSheet(
                    field: field,
                    comodel: comodel,
                    currentValue: draft.value(for: field.name, fallback: fallbackValue),
                    searchDomain: searchDomain,
                    onSelect: { selection in
                        applyChange(selection)
                    }
                )
                .environment(appState)
            }
        case .one2many(let subfields):
            One2ManyFieldEditor(
                field: field,
                subfields: subfields,
                draft: draft,
                fallbackValue: fallbackValue,
                validationMessage: validationMessage,
                onValueChange: onValueChange
            )
            .accessibilityIdentifier("field-row-\(field.name)")
        case .many2many(let comodel):
            VStack(alignment: .leading, spacing: 10) {
                Text(field.label)
                    .font(.subheadline.weight(.medium))

                if selectedRelations.isEmpty {
                    Text(field.placeholder ?? "No items selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("field-empty-\(field.name)")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(selectedRelations) { relation in
                            Button {
                                removeRelation(relation.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(relation.label)
                                        .lineLimit(1)
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("many2many-tag-\(field.name)-\(relation.id)")
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button(selectedRelations.isEmpty ? "Add" : "Manage") {
                        isShowingRelationPicker = true
                    }
                    .accessibilityIdentifier("field-editor-\(field.name)")

                    if !selectedRelations.isEmpty {
                        Button("Clear") {
                            applyChange(.array([]))
                        }
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("field-clear-\(field.name)")
                    }
                }

                validationText
            }
            .accessibilityIdentifier("field-row-\(field.name)")
            .sheet(isPresented: $isShowingRelationPicker) {
                Many2ManyPickerSheet(
                    field: field,
                    comodel: comodel,
                    currentSelections: selectedRelations,
                    searchDomain: searchDomain,
                    onSelect: { selections in
                        applyChange(.array(selections.map { .relation(id: $0.id, label: $0.label) }))
                    }
                )
                .environment(appState)
            }
        }
    }

    @ViewBuilder
    private var validationText: some View {
        if let validationMessage {
            Text(validationMessage)
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityIdentifier("field-error-\(field.name)")
        }
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: { draft.value(for: field.name, fallback: fallbackValue)?.stringValue ?? "" },
            set: { applyChange($0.isEmpty ? nil : .string($0)) }
        )
    }

    private var numericStringBinding: Binding<String> {
        Binding(
            get: {
                let value = draft.value(for: field.name, fallback: fallbackValue) ?? fallbackValue
                switch value {
                case .string(let rawString):
                    return rawString
                case .number(let number):
                    return number.rounded() == number ? String(Int(number)) : String(number)
                default:
                    return ""
                }
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                applyChange(trimmed.isEmpty ? nil : .string(trimmed))
            }
        )
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: {
                if case .bool(let value) = draft.value(for: field.name, fallback: fallbackValue) {
                    return value
                }
                return false
            },
            set: { applyChange(.bool($0)) }
        )
    }

    private func selectionBinding(options: [[String]]) -> Binding<String> {
        Binding(
            get: {
                if let value = draft.value(for: field.name, fallback: fallbackValue)?.stringValue {
                    return value
                }
                return options.first?.first ?? ""
            },
            set: { applyChange($0.isEmpty ? nil : .string($0)) }
        )
    }

    private func monetaryPrefix(currencyField: String?) -> String? {
        guard let currencyField else { return nil }
        let currencyValue = draft.values[currencyField]
        return currencyValue?.relationLabel ?? currencyValue?.stringValue
    }

    private var relationLabel: String? {
        draft.value(for: field.name, fallback: fallbackValue)?.relationLabel
            ?? fallbackValue?.relationLabel
    }

    private var currentPriority: Int {
        let value = draft.value(for: field.name, fallback: fallbackValue) ?? fallbackValue
        let rawValue = value?.stringValue ?? value?.displayText ?? "0"
        return max(0, min(Int(rawValue) ?? value?.intValue ?? 0, 3))
    }

    private var selectedRelations: [RelationValue] {
        let value = draft.value(for: field.name, fallback: fallbackValue) ?? fallbackValue
        return value?.relationValues ?? []
    }

    private func removeRelation(_ relationID: Int) {
        let remaining = selectedRelations.filter { $0.id != relationID }
        applyChange(.array(remaining.map { .relation(id: $0.id, label: $0.label) }))
    }

    private func applyChange(_ value: JSONValue?) {
        if let onValueChange {
            onValueChange(field, value)
        } else {
            draft.setValue(value, for: field.name)
        }
    }
}

private struct SignatureFieldEditor: View {
    let field: FieldSchema
    let draft: FormDraft
    let fallbackValue: JSONValue?
    let validationMessage: String?
    let onValueChange: ((FieldSchema, JSONValue?) -> Void)?

    @State private var isShowingCapture = false
    @State private var captureError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(field.label)
                .font(.subheadline.weight(.medium))

            Group {
                if let signatureImage = currentUIImage {
                    Image(uiImage: signatureImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(maxHeight: 160)
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("field-signature-preview-\(field.name)")
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "signature")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text("No signature captured")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("field-signature-placeholder-\(field.name)")
                }
            }

            HStack(spacing: 12) {
                Button(currentSignatureData == nil ? "Draw Signature" : "Replace Signature") {
                    isShowingCapture = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("field-editor-\(field.name)")

                if currentSignatureData != nil {
                    Button("Clear") {
                        captureError = nil
                        applyChange(nil)
                    }
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("field-clear-\(field.name)")
                }
            }

            Text("Small signatures only — PNG up to \(InlineSignatureSupport.limitDescription).")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("field-error-\(field.name)")
            }

            if let captureError {
                Text(captureError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("field-picker-error-\(field.name)")
            }
        }
        .sheet(isPresented: $isShowingCapture) {
            SignatureCaptureSheet { signatureData in
                applyCapturedSignature(signatureData)
            }
        }
    }

    private var currentSignatureData: Data? {
        let value = draft.value(for: field.name, fallback: fallbackValue) ?? fallbackValue
        return value?.binaryData
    }

    private var currentUIImage: UIImage? {
        guard let currentSignatureData else { return nil }
        return UIImage(data: currentSignatureData)
    }

    private func applyCapturedSignature(_ signatureData: Data) {
        guard !signatureData.isEmpty else {
            captureError = "Couldn’t capture the signature."
            return
        }

        guard signatureData.count <= InlineSignatureSupport.maxBytes else {
            captureError = "\(field.label) must be \(InlineSignatureSupport.limitDescription) or smaller."
            return
        }

        captureError = nil
        applyChange(.string(signatureData.base64EncodedString()))
        isShowingCapture = false
    }

    private func applyChange(_ value: JSONValue?) {
        if let onValueChange {
            onValueChange(field, value)
        } else {
            draft.setValue(value, for: field.name)
        }
    }
}

private struct BinaryDocumentFieldEditor: View {
    let field: FieldSchema
    let draft: FormDraft
    let fallbackValue: JSONValue?
    let validationMessage: String?
    let onValueChange: ((FieldSchema, JSONValue?) -> Void)?

    @State private var isShowingPicker = false
    @State private var pickerError: String?
    @State private var isLoading = false
    @State private var localFilename: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(field.label)
                .font(.subheadline.weight(.medium))

            Label(currentFilename ?? "No document selected", systemImage: currentDocumentData == nil ? "doc" : "doc.fill")
                .font(.subheadline)
                .foregroundStyle(currentDocumentData == nil ? .secondary : .primary)
                .accessibilityIdentifier("field-document-label-\(field.name)")

            HStack(spacing: 12) {
                Button(currentDocumentData == nil ? "Choose File" : "Replace File") {
                    isShowingPicker = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                .accessibilityIdentifier("field-editor-\(field.name)")

                if currentDocumentData != nil {
                    Button("Clear") {
                        clearDocument()
                    }
                    .font(.subheadline.weight(.medium))
                    .disabled(isLoading)
                    .accessibilityIdentifier("field-clear-\(field.name)")
                }
            }

            Text("Small files only — up to \(InlineBinaryDocumentSupport.limitDescription).")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("field-error-\(field.name)")
            }

            if let pickerError {
                Text(pickerError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("field-picker-error-\(field.name)")
            }
        }
        .sheet(isPresented: $isShowingPicker) {
            DocumentPickerSheet(
                onPick: { url in
                    Task {
                        await loadDocument(from: url)
                    }
                },
                onCancel: {
                    isShowingPicker = false
                }
            )
        }
    }

    private var currentDocumentData: Data? {
        let value = draft.value(for: field.name, fallback: fallbackValue) ?? fallbackValue
        return value?.binaryData
    }

    private var currentFilename: String? {
        if let filenameField = field.filenameField,
           let filename = draft.value(for: filenameField, fallback: nil)?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !filename.isEmpty {
            return filename
        }

        if let localFilename = localFilename?.trimmingCharacters(in: .whitespacesAndNewlines), !localFilename.isEmpty {
            return localFilename
        }

        return currentDocumentData == nil ? nil : "Document attached"
    }

    private func clearDocument() {
        pickerError = nil
        localFilename = nil

        if let filenameField = field.filenameField {
            draft.setValue(nil, for: filenameField)
        }

        applyChange(nil)
    }

    private func loadDocument(from url: URL) async {
        isLoading = true
        pickerError = nil
        defer {
            isLoading = false
            isShowingPicker = false
        }

        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let filename = try resolvedFilename(from: url)
            let documentData = try Data(contentsOf: url)

            guard !documentData.isEmpty else {
                pickerError = "Couldn’t load the selected file."
                return
            }

            guard documentData.count <= InlineBinaryDocumentSupport.maxBytes else {
                pickerError = "\(field.label) must be \(InlineBinaryDocumentSupport.limitDescription) or smaller."
                return
            }

            localFilename = filename

            if let filenameField = field.filenameField {
                draft.setValue(.string(filename), for: filenameField)
            }

            applyChange(.string(documentData.base64EncodedString()))
        } catch {
            pickerError = "Couldn’t load the selected file."
        }
    }

    private func resolvedFilename(from url: URL) throws -> String {
        if let filename = try url.resourceValues(forKeys: [.nameKey]).name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !filename.isEmpty {
            return filename
        }

        let fallback = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fallback.isEmpty else {
            throw CocoaError(.fileReadUnknown)
        }

        return fallback
    }

    private func applyChange(_ value: JSONValue?) {
        if let onValueChange {
            onValueChange(field, value)
        } else {
            draft.setValue(value, for: field.name)
        }
    }
}

private struct SignatureCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var drawing = PKDrawing()

    let onSave: (Data) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Draw inside the box, then save when you’re happy with it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SignatureCanvasView(drawing: $drawing)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        drawing = PKDrawing()
                    }
                    .disabled(drawing.bounds.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use") {
                        guard let imageData = renderedSignatureData else { return }
                        onSave(imageData)
                    }
                    .fontWeight(.semibold)
                    .disabled(renderedSignatureData == nil)
                }
            }
        }
    }

    private var renderedSignatureData: Data? {
        guard !drawing.bounds.isEmpty else { return nil }

        let renderRect = drawing.bounds.insetBy(dx: -12, dy: -12)
        guard renderRect.width > 0, renderRect.height > 0 else { return nil }

        return drawing.image(from: renderRect, scale: 2).pngData()
    }
}

private struct SignatureCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.delegate = context.coordinator
        canvasView.drawing = drawing
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 4)
        canvasView.alwaysBounceVertical = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding private var drawing: PKDrawing

        init(drawing: Binding<PKDrawing>) {
            _drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
        }
    }
}

private struct ImageFieldEditor: View {
    let field: FieldSchema
    let draft: FormDraft
    let fallbackValue: JSONValue?
    let validationMessage: String?
    let onValueChange: ((FieldSchema, JSONValue?) -> Void)?

    @State private var selectedItem: PhotosPickerItem?
    @State private var pickerError: String?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(field.label)
                .font(.subheadline.weight(.medium))

            Group {
                if let uiImage = currentUIImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("field-image-preview-\(field.name)")
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text("No image selected")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("field-image-placeholder-\(field.name)")
                }
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(currentImageData == nil ? "Choose Image" : "Replace Image")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                .accessibilityIdentifier("field-editor-\(field.name)")

                if currentImageData != nil {
                    Button("Clear") {
                        pickerError = nil
                        applyChange(nil)
                    }
                    .font(.subheadline.weight(.medium))
                    .disabled(isLoading)
                    .accessibilityIdentifier("field-clear-\(field.name)")
                }
            }

            Text("Small images only — up to \(InlineImageSupport.limitDescription).")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("field-error-\(field.name)")
            }

            if let pickerError {
                Text(pickerError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("field-picker-error-\(field.name)")
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await loadImage(from: newValue)
            }
        }
    }

    private var currentImageData: Data? {
        let value = draft.value(for: field.name, fallback: fallbackValue) ?? fallbackValue
        return value?.binaryData
    }

    private var currentUIImage: UIImage? {
        guard let currentImageData else { return nil }
        return UIImage(data: currentImageData)
    }

    private func loadImage(from item: PhotosPickerItem) async {
        isLoading = true
        pickerError = nil
        defer {
            isLoading = false
            selectedItem = nil
        }

        do {
            guard let imageData = try await item.loadTransferable(type: Data.self), !imageData.isEmpty else {
                pickerError = "Couldn’t load the selected image."
                return
            }

            guard imageData.count <= InlineImageSupport.maxBytes else {
                pickerError = "\(field.label) must be \(InlineImageSupport.limitDescription) or smaller."
                return
            }

            applyChange(.string(imageData.base64EncodedString()))
        } catch {
            pickerError = "Couldn’t load the selected image."
        }
    }

    private func applyChange(_ value: JSONValue?) {
        if let onValueChange {
            onValueChange(field, value)
        } else {
            draft.setValue(value, for: field.name)
        }
    }
}

private struct DocumentPickerSheet: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }

            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

private struct NumericFieldEditor: View {
    let field: FieldSchema
    let text: Binding<String>
    let keyboardType: UIKeyboardType
    let validationMessage: String?
    var prefix: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(field.label) {
                HStack(spacing: 8) {
                    if let prefix, !prefix.isEmpty {
                        Text(prefix)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    TextField(field.placeholder ?? field.label, text: text)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(keyboardType)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("field-editor-\(field.name)")
                }
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("field-error-\(field.name)")
            }
        }
    }
}

private struct TemporalFieldEditor: View {
    let field: FieldSchema
    let fallbackValue: JSONValue?
    let validationMessage: String?
    let displayedComponents: DatePickerComponents
    let includeTime: Bool
    let onValueChange: ((FieldSchema, JSONValue?) -> Void)?

    @Bindable var draft: FormDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.label)
                .font(.subheadline.weight(.medium))

            if let currentDate = resolvedDate {
                DatePicker(
                    field.label,
                    selection: dateBinding(currentDate),
                    displayedComponents: displayedComponents
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .accessibilityLabel(field.label)
                .accessibilityIdentifier("field-editor-\(field.name)")

                Button("Clear") {
                    applyChange(nil)
                }
                .font(.subheadline.weight(.medium))
                .accessibilityIdentifier("field-clear-\(field.name)")
            } else {
                Button(includeTime ? "Set Date & Time" : "Set Date") {
                    applyChange(.string(Self.string(from: Date(), includeTime: includeTime)))
                }
                .accessibilityIdentifier("field-editor-\(field.name)")
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("field-error-\(field.name)")
            }
        }
    }

    private var resolvedDate: Date? {
        let value = draft.value(for: field.name, fallback: fallbackValue) ?? fallbackValue
        return Self.date(from: value, includeTime: includeTime)
    }

    private func dateBinding(_ fallbackDate: Date) -> Binding<Date> {
        Binding(
            get: { resolvedDate ?? fallbackDate },
            set: { newValue in
                applyChange(.string(Self.string(from: newValue, includeTime: includeTime)))
            }
        )
    }

    private func applyChange(_ value: JSONValue?) {
        if let onValueChange {
            onValueChange(field, value)
        } else {
            draft.setValue(value, for: field.name)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static func date(from value: JSONValue?, includeTime: Bool) -> Date? {
        guard case .string(let rawString)? = value else { return nil }
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if includeTime {
            return dateTimeFormatter.date(from: trimmed)
                ?? shortDateTimeFormatter.date(from: trimmed)
                ?? ISO8601DateFormatter().date(from: trimmed)
        }

        return dateFormatter.date(from: trimmed)
    }

    private static func string(from date: Date, includeTime: Bool) -> String {
        includeTime ? dateTimeFormatter.string(from: date) : dateFormatter.string(from: date)
    }
}

private struct Many2OnePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let field: FieldSchema
    let comodel: String
    let currentValue: JSONValue?
    let searchDomain: JSONValue?
    let onSelect: (JSONValue?) -> Void

    @State private var query = ""
    @State private var results: [NameSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let currentLabel = currentValue?.relationLabel {
                    Section("Current") {
                        Button {
                            dismiss()
                        } label: {
                            HStack {
                                Text(currentLabel)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    Section {
                        Text("Type at least 2 characters to search \(field.label.lowercased()).")
                            .foregroundStyle(.secondary)
                    }
                } else if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if results.isEmpty {
                    Section {
                        Text("No matches found.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Results") {
                        ForEach(results) { result in
                            Button {
                                onSelect(.relation(id: result.id, label: result.name))
                                dismiss()
                            } label: {
                                Text(result.name)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("many2one-option-\(field.name)-\(result.id)")
                        }
                    }
                }
            }
            .navigationTitle(field.label)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search \(field.label.lowercased())")
            .task(id: query) {
                await search()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if currentValue != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            onSelect(nil)
                            dismiss()
                        }
                        .accessibilityIdentifier("many2one-clear-\(field.name)")
                    }
                }
            }
        }
    }

    private func search() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            results = []
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            let searchResults = try await appState.withAuthenticatedToken { token in
                try await appState.apiClient.search(model: comodel, query: trimmedQuery, limit: 20, domain: searchDomain, token: token)
            }

            guard !Task.isCancelled else { return }
            results = searchResults
        } catch {
            guard !(error is CancellationError) else { return }
            errorMessage = error.localizedDescription
            results = []
        }

        isLoading = false
    }
}

private struct Many2ManyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let field: FieldSchema
    let comodel: String
    let currentSelections: [RelationValue]
    let searchDomain: JSONValue?
    let onSelect: ([RelationValue]) -> Void

    @State private var query = ""
    @State private var results: [NameSearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRelations: [RelationValue]

    init(field: FieldSchema, comodel: String, currentSelections: [RelationValue], searchDomain: JSONValue?, onSelect: @escaping ([RelationValue]) -> Void) {
        self.field = field
        self.comodel = comodel
        self.currentSelections = currentSelections
        self.searchDomain = searchDomain
        self.onSelect = onSelect
        _selectedRelations = State(initialValue: currentSelections)
    }

    var body: some View {
        NavigationStack {
            List {
                if !selectedRelations.isEmpty {
                    Section("Selected") {
                        ForEach(selectedRelations) { relation in
                            Button {
                                toggleSelection(id: relation.id, label: relation.label)
                            } label: {
                                HStack {
                                    Text(relation.label)
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("many2many-selected-\(field.name)-\(relation.id)")
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    Section {
                        Text("Type at least 2 characters to search \(field.label.lowercased()).")
                            .foregroundStyle(.secondary)
                    }
                } else if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if results.isEmpty {
                    Section {
                        Text("No matches found.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Results") {
                        ForEach(results) { result in
                            Button {
                                toggleSelection(id: result.id, label: result.name)
                            } label: {
                                HStack {
                                    Text(result.name)
                                    Spacer()
                                    if isSelected(result.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("many2many-option-\(field.name)-\(result.id)")
                        }
                    }
                }
            }
            .navigationTitle(field.label)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search \(field.label.lowercased())")
            .task(id: query) {
                await search()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if !selectedRelations.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            selectedRelations = []
                        }
                        .accessibilityIdentifier("many2many-clear-\(field.name)")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onSelect(selectedRelations)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("many2many-done-\(field.name)")
                }
            }
        }
    }

    private func isSelected(_ relationID: Int) -> Bool {
        selectedRelations.contains { $0.id == relationID }
    }

    private func toggleSelection(id: Int, label: String) {
        if let index = selectedRelations.firstIndex(where: { $0.id == id }) {
            selectedRelations.remove(at: index)
        } else {
            selectedRelations.append(RelationValue(id: id, label: label))
        }
    }

    private func search() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            results = []
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            let searchResults = try await appState.withAuthenticatedToken { token in
                try await appState.apiClient.search(model: comodel, query: trimmedQuery, limit: 20, domain: searchDomain, token: token)
            }

            guard !Task.isCancelled else { return }
            results = searchResults
        } catch {
            guard !(error is CancellationError) else { return }
            errorMessage = error.localizedDescription
            results = []
        }

        isLoading = false
    }
}