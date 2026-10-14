import Layout
import SwiftUI
import UIKit

/// How the event sheet is used (M3b contract §4.3).
enum EventEditorMode: Equatable {
    case create
    case edit(eventId: String, recurring: Bool)
    /// `calendar.allowsContentModifications == false`: every field disabled, 「閉じる」 only.
    case readOnly(eventId: String)
}

/// What the person asked the sheet's owner to do.
enum EventEditorResult {
    /// `span` is non-nil only when a recurring event is edited (「この回だけ／以降すべて」).
    case save(EventDraft, span: EventSpan?, eraseInk: Bool)
    case delete(span: EventSpan?)
    case cancel
}

/// The create / edit / view sheet of one event (M3b contract §4.3, DESIGN §4.5–4.6; the web
/// version's event-dialog.js). The form state is the pure `EventEditorForm`; this view only binds
/// it to the controls, validates on 「保存」, asks the recurrence scope and the delete confirmation,
/// and runs `onSubmit`. A thrown error keeps the sheet open and shows `errorDescription` in red
/// (so a handwritten title is never lost); the owner closes the sheet on success.
struct EventEditorSheet: View {
    var mode: EventEditorMode
    /// The initial values.
    var draft: EventDraft
    /// Create: the writable calendars. Edit / view: the event's own calendar (one entry).
    var calendars: [CalendarOption]
    /// The handwriting the event is made from (lasso → 「予定にする」 only).
    var snapshot: UIImage?
    /// Show the 「この手書きを消す」 switch (lasso → 「予定にする」 only).
    var showEraseOption: Bool
    /// Initial value of that switch (`AppSettings.eraseInkAfterConvert`).
    var eraseDefault: Bool
    /// Performs the save / delete. A throw keeps the sheet open with the error in the footer.
    var onSubmit: (EventEditorResult) async throws -> Void
    var onCancel: () -> Void

    @State private var form: EventEditorForm
    @State private var calendarId: String
    @State private var eraseInk: Bool
    @State private var titleError: String?
    @State private var dateError: String?
    @State private var footerError: String?
    @State private var isBusy = false
    @State private var showDeleteConfirmation = false
    @State private var showSaveScope = false
    @State private var showDeleteScope = false
    /// The validated draft waiting for the 「この回だけ／以降すべて」 answer.
    @State private var pendingDraft: EventDraft?
    @FocusState private var titleFocused: Bool

    init(
        mode: EventEditorMode,
        draft: EventDraft,
        calendars: [CalendarOption],
        snapshot: UIImage? = nil,
        showEraseOption: Bool = false,
        eraseDefault: Bool = true,
        onSubmit: @escaping (EventEditorResult) async throws -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.draft = draft
        self.calendars = calendars
        self.snapshot = snapshot
        self.showEraseOption = showEraseOption
        self.eraseDefault = eraseDefault
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        _form = State(initialValue: EventEditorForm(draft: draft))
        _calendarId = State(initialValue: draft.calendarId)
        _eraseInk = State(initialValue: eraseDefault)
    }

    // MARK: - Derived

    private var isReadOnly: Bool {
        if case .readOnly = mode { return true }
        return false
    }

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isRecurringEdit: Bool {
        if case .edit(_, let recurring) = mode { return recurring }
        return false
    }

    /// Every field is frozen while read-only or while a submit is running.
    private var fieldsDisabled: Bool { isReadOnly || isBusy }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private var navigationTitle: String {
        switch mode {
        case .create: return "予定を追加"
        case .edit: return "予定を編集"
        case .readOnly: return "予定の詳細"
        }
    }

    private var currentCalendar: CalendarOption? {
        calendars.first { $0.id == calendarId } ?? calendars.first
    }

    // MARK: - Body

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            sheetContent.presentationDetents([.large])
        } else {
            sheetContent
        }
    }

    private var sheetContent: some View {
        NavigationStack {
            Form {
                snapshotSection
                titleSection
                dateSection
                calendarSection
                Section("場所") {
                    TextField("場所", text: $form.location)
                        .submitLabel(.done)
                        .disabled(fieldsDisabled)
                }
                Section("メモ") {
                    TextEditor(text: $form.notes)
                        .frame(minHeight: 80)
                        .disabled(fieldsDisabled)
                }
                if showEraseOption, !isReadOnly {
                    Section {
                        Toggle("この手書きを消す", isOn: $eraseInk)
                            .disabled(fieldsDisabled)
                    }
                }
                if isRecurringEdit {
                    Section {
                        Label("繰り返しの予定です。保存・削除のときに「この回だけ」か「以降すべて」を選びます", systemImage: "repeat")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if isEdit {
                    Section {
                        Button("削除", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(fieldsDisabled)
                    }
                }
                if isReadOnly {
                    Section {
                        Text("このカレンダーは変更できません（読み取り専用）")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let footerError = footerError {
                    Section {
                        Text(footerError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
            }
            .environment(\.calendar, form.calendar)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isReadOnly ? "閉じる" : "キャンセル", action: onCancel)
                        .disabled(isBusy)
                }
                if !isReadOnly {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isBusy ? "保存中…" : "保存", action: save)
                            .fontWeight(.semibold)
                            .disabled(isBusy)
                    }
                }
            }
            .confirmationDialog("この予定を削除しますか？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("削除", role: .destructive, action: confirmDelete)
                Button("キャンセル", role: .cancel) {}
            }
            .recurrenceScopeDialog(isPresented: $showSaveScope, kind: .save) { span in
                guard let pending = pendingDraft else { return }
                pendingDraft = nil
                submit(.save(pending, span: span, eraseInk: showEraseOption && eraseInk))
            }
            .recurrenceScopeDialog(isPresented: $showDeleteScope, kind: .delete) { span in
                submit(.delete(span: span))
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var snapshotSection: some View {
        if let snapshot = snapshot {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Image(uiImage: snapshot)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 160)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1))
                        )
                        .accessibilityLabel("選択した手書き")
                    Text("書いた内容")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var titleSection: some View {
        Section {
            TextField("ここにペンで書くと文字になります", text: $form.title)
                .font(.title3)
                .submitLabel(.done)
                .focused($titleFocused)
                .disabled(fieldsDisabled)
                .onChange(of: form.title) { titleError = nil }
            if isPad, !isReadOnly {
                Text("Apple Pencil で欄の上に書くと、文字に変換されます（スクリブル）")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let titleError = titleError {
                Text(titleError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("タイトル")
        }
    }

    private var dateSection: some View {
        Section {
            Toggle("終日", isOn: allDayBinding)
                .disabled(fieldsDisabled)
            if form.allDay {
                DatePicker("開始日", selection: startBinding, displayedComponents: [.date])
                    .disabled(fieldsDisabled)
                DatePicker("終了日", selection: endBinding, displayedComponents: [.date])
                    .disabled(fieldsDisabled)
            } else {
                DatePicker("開始", selection: startBinding, displayedComponents: [.date, .hourAndMinute])
                    .disabled(fieldsDisabled)
                DatePicker("終了", selection: endBinding, displayedComponents: [.date, .hourAndMinute])
                    .disabled(fieldsDisabled)
            }
            if let dateError = dateError {
                Text(dateError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var calendarSection: some View {
        Section("カレンダー") {
            if mode == .create, calendars.count > 1 {
                Picker("カレンダー", selection: $calendarId) {
                    ForEach(calendars) { option in
                        calendarLabel(option).tag(option.id)
                    }
                }
                .pickerStyle(.navigationLink)
                .disabled(fieldsDisabled)
            } else if let option = currentCalendar {
                calendarLabel(option)
            }
        }
    }

    private func calendarLabel(_ option: CalendarOption) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(uiColor: PaperPalette.color(hex: option.colorHex)))
                .frame(width: 10, height: 10)
            Text(option.title)
        }
    }

    // MARK: - Bindings (every change goes through the pure form)

    private var allDayBinding: Binding<Bool> {
        Binding(
            get: { form.allDay },
            set: { on in
                form.setAllDay(on)
                dateError = nil
            }
        )
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { form.start },
            set: { date in
                form.setStart(date)
                dateError = nil
            }
        )
    }

    /// All-day: the inclusive last day; timed: the end instant.
    private var endBinding: Binding<Date> {
        Binding(
            get: { form.endPickerDate },
            set: { date in
                form.setEnd(date)
                dateError = nil
            }
        )
    }

    // MARK: - Actions

    private func save() {
        guard !isBusy, !isReadOnly else { return }
        titleError = nil
        dateError = nil
        footerError = nil
        switch form.draft(calendarId: calendarId) {
        case .failure(let error):
            if error == .emptyTitle {
                titleError = error.errorDescription
                titleFocused = true
            } else {
                dateError = error.errorDescription
            }
        case .success(let validated):
            if isRecurringEdit {
                pendingDraft = validated
                showSaveScope = true
            } else {
                submit(.save(validated, span: nil, eraseInk: showEraseOption && eraseInk))
            }
        }
    }

    private func confirmDelete() {
        if isRecurringEdit {
            // The confirmation dialog must be gone before the scope question can appear.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.35))
                showDeleteScope = true
            }
        } else {
            submit(.delete(span: nil))
        }
    }

    private func submit(_ result: EventEditorResult) {
        guard !isBusy else { return }
        isBusy = true
        footerError = nil
        Task { @MainActor in
            do {
                try await onSubmit(result)
            } catch {
                footerError = (error as? LocalizedError)?.errorDescription ?? "保存できませんでした"
            }
            isBusy = false
        }
    }
}
