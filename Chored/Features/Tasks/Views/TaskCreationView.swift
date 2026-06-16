import SwiftUI

/// Task creation sheet. Native iOS form appearance; color presets are the only
/// custom color. One primary action (Create).
struct TaskCreationView: View {

    let group: ChoreGroup
    let currentUser: User
    let defaultDate: Date
    @ObservedObject var viewModel: TaskViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    // Core fields
    @State private var name = ""
    @State private var description = ""
    @State private var colorPreset = 0
    @State private var assignee: String
    @State private var startDate: Date

    // End date
    @State private var hasEndDate = false
    @State private var endDate: Date

    // Recurrence
    @State private var isRecurring = false
    @State private var recurrenceMode: RecurrenceMode = .weekdays
    @State private var weekdayMask = 0
    @State private var specificDates: [Date] = []
    @State private var pickerDate: Date

    // Alternating
    @State private var isAlternating = false

    // Estimated interval
    @State private var hasInterval = false
    @State private var intervalDays = 3

    @State private var isWorking = false

    enum RecurrenceMode: String, CaseIterable { case weekdays = "Weekdays", dates = "Specific dates" }

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols // Sun...Sat

    init(group: ChoreGroup, currentUser: User, defaultDate: Date, viewModel: TaskViewModel) {
        self.group = group
        self.currentUser = currentUser
        self.defaultDate = defaultDate
        self.viewModel = viewModel
        _assignee = State(initialValue: currentUser.recordName)
        _startDate = State(initialValue: defaultDate)
        _endDate = State(initialValue: defaultDate.adding(days: 7))
        _pickerDate = State(initialValue: defaultDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                colorSection
                assigneeSection
                scheduleSection
                recurringSection
                alternatingSection
                intervalSection
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
                }
            }
        }
    }

    // MARK: Sections

    private var detailsSection: some View {
        Section {
            TextField("Task name", text: $name).choredBody()
            TextField("Description (optional)", text: $description, axis: .vertical)
                .choredBody()
                .lineLimit(1...3)
                .onChange(of: description) { _, new in
                    if new.count > Constants.Limits.descriptionLength {
                        description = String(new.prefix(Constants.Limits.descriptionLength))
                    }
                }
        } footer: {
            Text("\(description.count)/\(Constants.Limits.descriptionLength)")
                .choredCaption()
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    private var colorSection: some View {
        Section {
            HStack(spacing: Theme.Spacing.md) {
                ForEach(TaskColorPreset.allCases) { preset in
                    Circle()
                        .fill(preset.background(for: scheme))
                        .frame(width: 32, height: 32)
                        .overlay {
                            if preset.rawValue == colorPreset {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(preset.labelColor)
                            }
                        }
                        .onTapGesture { colorPreset = preset.rawValue }
                        .accessibilityLabel(preset.name)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
        } header: {
            sectionHeader("Color")
        }
    }

    private var assigneeSection: some View {
        Section {
            Picker("Assignee", selection: $assignee) {
                ForEach(group.memberRecordNames, id: \.self) { rn in
                    Text(viewModel.displayName(for: rn)).tag(rn)
                }
            }
        } header: {
            sectionHeader("Assignee")
        }
    }

    private var scheduleSection: some View {
        Section {
            DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
            Toggle("End date", isOn: $hasEndDate.animation(.easeInOut(duration: 0.2)))
            if hasEndDate {
                DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
        } header: {
            sectionHeader("Schedule")
        }
    }

    private var recurringSection: some View {
        Section {
            Toggle("Recurring", isOn: $isRecurring.animation(.easeInOut(duration: 0.2)))
            if isRecurring {
                Picker("Pattern", selection: $recurrenceMode) {
                    ForEach(RecurrenceMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if recurrenceMode == .weekdays {
                    weekdayPicker
                } else {
                    specificDatePicker
                }
            }
        } header: {
            sectionHeader("Repeat")
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<7, id: \.self) { i in
                let selected = (weekdayMask & (1 << i)) != 0
                Button {
                    weekdayMask ^= (1 << i)
                } label: {
                    Text(weekdaySymbols[i].prefix(1))
                        .choredSubheadline()
                        .frame(width: Theme.Size.minTouchTarget, height: Theme.Size.minTouchTarget)
                        .background(selected ? Color(.label) : Color(.secondarySystemBackground))
                        .foregroundStyle(selected ? Color(.systemBackground) : Color(.label))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var specificDatePicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            DatePicker("Add a date", selection: $pickerDate, displayedComponents: .date)
                .datePickerStyle(.compact)
            Button("Add date") {
                if !specificDates.contains(where: { $0.isSameDay(as: pickerDate) }) {
                    specificDates.append(pickerDate.startOfDay)
                    specificDates.sort()
                }
            }
            ForEach(specificDates, id: \.self) { date in
                HStack {
                    Text(date.formatted(date: .abbreviated, time: .omitted)).choredCallout()
                    Spacer()
                    Button {
                        specificDates.removeAll { $0.isSameDay(as: date) }
                    } label: { Image(systemName: "minus.circle").foregroundStyle(Color(.systemRed)) }
                }
            }
        }
    }

    private var alternatingSection: some View {
        Section {
            Toggle("Alternating between members", isOn: $isAlternating)
        } header: {
            sectionHeader("Rotation")
        } footer: {
            if isAlternating {
                Text("The assignee rotates through all \(group.memberRecordNames.count) members each time the task is completed.")
                    .choredCaption()
            }
        }
    }

    private var intervalSection: some View {
        Section {
            Toggle("Remind after a number of days", isOn: $hasInterval.animation(.easeInOut(duration: 0.2)))
            if hasInterval {
                Stepper("Every \(intervalDays) day\(intervalDays == 1 ? "" : "s")",
                        value: $intervalDays, in: 1...60)
            }
        } header: {
            sectionHeader("Estimated interval")
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .choredSubheadline()
            .foregroundStyle(Color(.secondaryLabel))
    }

    // MARK: Create

    private func create() {
        isWorking = true
        let task = ChoreTask(
            groupID: group.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            colorPreset: colorPreset,
            assigneeRecordName: isAlternating ? (group.memberRecordNames.first ?? assignee) : assignee,
            isRecurring: isRecurring,
            weekdayMask: (isRecurring && recurrenceMode == .weekdays) ? weekdayMask : nil,
            recurringDates: (isRecurring && recurrenceMode == .dates) ? specificDates : nil,
            isAlternating: isAlternating,
            alternatingOrder: isAlternating ? group.memberRecordNames : [],
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            estimatedIntervalDays: hasInterval ? intervalDays : nil
        )
        Task {
            let ok = await viewModel.create(task)
            isWorking = false
            if ok { dismiss() }
        }
    }
}
