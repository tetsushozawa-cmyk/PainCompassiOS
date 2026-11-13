import SwiftUI
import UIKit

struct DiaryRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var dateTime: String
    var painLevel: String
    var movement: String
    var sleep: String
    var brainFog: String
    var painTime: String
    var weather: String
    var temperature: String
    var pressure: String
    var dailyActivity: String
    var memo: String
    var measuredPressureHectopascals: Double? = nil
    var pressureMeasuredAt: Date? = nil
    var yesterdayStepCount: Int? = nil
    var dayBeforeYesterdayStepCount: Int? = nil
}

final class DiaryRecordStore: ObservableObject {
    @Published private(set) var records: [DiaryRecord] = []
    private let recordsKey = "records_json"

    init() {
        load()
    }

    func add(_ record: DiaryRecord) {
        records.append(record)
        save()
    }

    func delete(_ record: DiaryRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func makeShareFile() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(ReadableSharedRecords(records: records))
        let fileName = "pain_compass_records_\(DateFormatter.shareFileDateTime.string(from: Date())).json"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: recordsKey) else {
            records = []
            return
        }
        records = (try? JSONDecoder().decode([DiaryRecord].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: recordsKey)
    }
}

struct ReadableSharedRecords: Encodable {
    let records: [DiaryRecord]

    enum CodingKeys: String, CodingKey {
        case records = "記録"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(records.map(ReadableSharedRecord.init), forKey: .records)
    }
}

struct ReadableSharedRecord: Encodable {
    let record: DiaryRecord

    enum CodingKeys: String, CodingKey {
        case dateTime = "日時"
        case painLevel = "痛みの度合い"
        case movement = "動ける状態"
        case sleep = "睡眠の状態"
        case brainFog = "頭の働き"
        case painTime = "痛い時間帯"
        case weather = "天候"
        case temperature = "気温"
        case pressure = "気圧の変化"
        case dailyActivity = "日常活動性"
        case memo = "メモ"
        case measuredPressureHectopascals = "実測気圧（hPa）"
        case pressureMeasuredAt = "気圧測定時刻"
        case yesterdayStepCount = "昨日の歩数"
        case dayBeforeYesterdayStepCount = "一昨日の歩数"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(record.dateTime, forKey: .dateTime)
        try container.encode(record.painLevel, forKey: .painLevel)
        try container.encode(record.movement, forKey: .movement)
        try container.encode(record.sleep, forKey: .sleep)
        try container.encode(record.brainFog, forKey: .brainFog)
        try container.encode(record.painTime, forKey: .painTime)
        try container.encode(record.weather, forKey: .weather)
        try container.encode(record.temperature, forKey: .temperature)
        try container.encode(record.pressure, forKey: .pressure)
        try container.encode(record.dailyActivity, forKey: .dailyActivity)
        try container.encode(record.memo, forKey: .memo)
        try container.encodeIfPresent(record.measuredPressureHectopascals, forKey: .measuredPressureHectopascals)
        if let pressureMeasuredAt = record.pressureMeasuredAt {
            try container.encode(
                DateFormatter.pressureMeasurementDateTime.string(from: pressureMeasuredAt),
                forKey: .pressureMeasuredAt
            )
        }
        try container.encodeIfPresent(record.yesterdayStepCount, forKey: .yesterdayStepCount)
        try container.encodeIfPresent(
            record.dayBeforeYesterdayStepCount,
            forKey: .dayBeforeYesterdayStepCount
        )
    }
}

struct DraftRecord: Equatable, Hashable {
    var dateTime = DateFormatter.painRecordDateTime.string(from: Date())
    var painLevel = PainRecordOptions.painLevels[0]
    var movement = PainRecordOptions.movements[0]
    var sleep = PainRecordOptions.sleeps[0]
    var brainFog = PainRecordOptions.brainFogs[0]
    var painTimes: Set<String> = []
    var weather = PainRecordOptions.weathers[0]
    var temperature = PainRecordOptions.temperatures[0]
    var pressure = PainRecordOptions.pressures[0]
    var dailyActivity = PainRecordOptions.dailyActivities[0]
    var memo = ""

    var painTimeText: String {
        PainRecordOptions.painTimes.filter { painTimes.contains($0) }.joined(separator: "、")
    }

    func record(
        pressureMeasurement: PressureMeasurement?,
        yesterdayStepCount: Int?,
        dayBeforeYesterdayStepCount: Int?
    ) -> DiaryRecord {
        DiaryRecord(
            dateTime: dateTime,
            painLevel: painLevel,
            movement: movement,
            sleep: sleep,
            brainFog: brainFog,
            painTime: painTimeText,
            weather: weather,
            temperature: temperature,
            pressure: pressure,
            dailyActivity: dailyActivity,
            memo: memo,
            measuredPressureHectopascals: pressureMeasurement?.hectopascals,
            pressureMeasuredAt: pressureMeasurement?.measuredAt,
            yesterdayStepCount: yesterdayStepCount,
            dayBeforeYesterdayStepCount: dayBeforeYesterdayStepCount
        )
    }
}

enum AppRoute: Hashable {
    case recordInput
    case savedRecords
    case mandalaData
    case olderWeeksMandala
    case stepsPainMandala
    case pressurePainMandala
    case environment(DraftRecord)
}

enum PainRecordOptions {
    static let painLevels = ["1. 全く痛くない", "2. 少し痛い", "3. 痛い", "4. 酷く痛い", "5. 経験した中で一番痛い", "6. 夜間眠れないほど痛い"]
    static let movements = ["1. 健康に歩ける", "2. どうにか歩ける", "3. ようやく歩ける", "4. 杖がいる", "5. 車椅子がいる", "6. 寝たきり"]
    static let sleeps = ["1. よく眠れた", "2. 夜間目覚めることがあった", "3. 夜間何度も目覚めた", "4. ほとんど眠れなかった", "5. 眠れなかった"]
    static let brainFogs = ["1. 脳の働きがすっきりしている", "2. 脳の働きが少し悪い", "3. 脳の働きが大分悪い", "4. ほとんど働かない", "5. 全く働かない"]
    static let painTimes = ["1. 午前中", "2. 夕方", "3. 夜間", "4. 1日中"]
    static let weathers = ["1. 晴れ", "2. 曇り", "3. 雨", "4. 雪", "5. 強風（雨、雪を含む）"]
    static let temperatures = ["1. 酷く暑い", "2. 暑い", "3. 少し暑い", "4. 快適", "5. 少し寒い", "6. 寒い", "7. 酷く寒い"]
    static let pressures = ["1. 高気圧の接近", "2. 安定", "3. 低気圧の接近", "4. 前線の移動", "5. 台風の接近"]
    static let dailyActivities = ["1. 完全", "2. ちょっと大変", "3. 大分大変", "4. 辛くて早退", "5. 行けなかった"]
}

extension DateFormatter {
    static let painRecordDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    static let painRecordDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    static let shareFileDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    static let pressureMeasurementDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }()
}

extension Color {
    static let screenBackground = Color(red: 0.973, green: 0.976, blue: 0.980)
    static let textPrimary = Color(red: 0.125, green: 0.141, blue: 0.165)
    static let textSecondary = Color(red: 0.392, green: 0.439, blue: 0.490)
    static let accentGreen = Color(red: 0.063, green: 0.557, blue: 0.443)
    static let mandalaBlue = Color(red: 0.122, green: 0.298, blue: 0.557)
    static let clearButton = Color(red: 0.925, green: 0.941, blue: 0.957)
    static let homeClearButton = Color(red: 0.973, green: 0.929, blue: 0.890)
    static let panelBackground = Color.white
    static let softBlue = Color(red: 0.910, green: 0.945, blue: 0.980)
    static let inputBorder = Color(red: 0.835, green: 0.851, blue: 0.871)
    static let savedRecord = Color.white
    static let deleteRed = Color(red: 0.690, green: 0.210, blue: 0.210)
    static let deleteSoft = Color(red: 0.988, green: 0.925, blue: 0.925)
}

struct ContentView: View {
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.screenBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        Image("PainCompassThumbnail")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 125, height: 125)
                            .clipped()
                            .padding(.top, 40)
                            .padding(.bottom, 16)

                        Text("疼痛コンパス")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity)

                        Text("線維筋痛症ダイアリー")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.top, 8)

                        PressureStatusView()
                            .padding(.top, 16)

                        YesterdayStepCountStatusView()
                            .padding(.top, 12)

                        NavigationLink(value: AppRoute.recordInput) {
                            HomeButtonLabel(title: "記録を入力する", color: .accentGreen, foreground: .white)
                        }
                        .padding(.top, 148)

                        NavigationLink(value: AppRoute.savedRecords) {
                            HomeButtonLabel(title: "保存を見る", color: .homeClearButton, foreground: .black)
                        }
                        .padding(.top, 64)

                        NavigationLink(value: AppRoute.mandalaData) {
                            HomeButtonLabel(title: "曼荼羅用データ", color: .mandalaBlue, foreground: .white)
                        }
                        .padding(.top, 64)
                        .padding(.bottom, 48)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 140)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .recordInput:
                    RecordInputView(path: $path)
                case .savedRecords:
                    SavedRecordsView(path: $path)
                case .mandalaData:
                    MandalaDataView(path: $path)
                case .olderWeeksMandala:
                    OlderWeeksMandalaView(path: $path)
                case .stepsPainMandala:
                    StepsPainMandalaView(path: $path)
                case .pressurePainMandala:
                    PressurePainMandalaView(path: $path)
                case .environment(let draft):
                    EnvironmentInputView(path: $path, draft: draft)
                }
            }
        }
    }
}

struct YesterdayStepCountStatusView: View {
    @EnvironmentObject private var stepCountStore: YesterdayStepCountStore

    var body: some View {
        VStack(spacing: 3) {
            Text(yesterdayStatusText)
            Text(dayBeforeYesterdayStatusText)
        }
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Color.textPrimary)
    }

    private var yesterdayStatusText: String {
        switch stepCountStore.state {
        case .idle, .loading:
            "昨日の歩数：取得中…"
        case .loaded(let stepCount, _):
            stepCount.map { "昨日の歩数：\($0)歩" } ?? "昨日の歩数：取得できません"
        case .unavailable:
            "昨日の歩数：取得できません"
        }
    }

    private var dayBeforeYesterdayStatusText: String {
        switch stepCountStore.state {
        case .idle, .loading:
            "一昨日の歩数：取得中…"
        case .loaded(_, let stepCount):
            stepCount.map { "一昨日の歩数：\($0)歩" } ?? "一昨日の歩数：取得できません"
        case .unavailable:
            "一昨日の歩数：取得できません"
        }
    }
}

struct PressureStatusView: View {
    @EnvironmentObject private var pressureStore: PressureMeasurementStore

    var body: some View {
        VStack(spacing: 3) {
            if let measurement = pressureStore.latestMeasurement {
                Text(String(format: "最新気圧 %.1f hPa", measurement.hectopascals))
                Text("測定時刻 \(measurement.measuredAt.formatted(date: .omitted, time: .standard))")
            } else {
                Text(statusText)
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(Color.textSecondary)
    }

    private var statusText: String {
        switch pressureStore.state {
        case .idle:
            "気圧測定を待機中"
        case .measuring:
            "気圧を取得中…"
        case .unavailable:
            "気圧センサーを利用できません"
        case .failed:
            "気圧を取得できませんでした"
        }
    }
}

struct PressureChangeStatusView: View {
    let result: PressureChangeCalculationResult

    var body: some View {
        VStack(spacing: 2) {
            Text("約24時間前との差")
            switch result {
            case .calculated(let change):
                Text(changeText(change))
                Text(
                    "比較対象：\(DateFormatter.pressureMeasurementDateTime.string(from: change.comparisonData.measuredAt))"
                )
            case .comparisonDataUnavailable:
                Text("比較データなし")
            }
        }
    }

    private func changeText(_ change: PressureChange) -> String {
        switch change.direction {
        case .rising:
            String(format: "＋%.1f hPa ↑", abs(change.differenceHectopascals))
        case .falling:
            String(format: "−%.1f hPa ↓", abs(change.differenceHectopascals))
        case .unchanged:
            "0.0 hPa →"
        }
    }
}

struct HomeButtonLabel: View {
    let title: String
    let color: Color
    let foreground: Color

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(color, in: RoundedRectangle(cornerRadius: 38))
            .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 2)
    }
}

struct RecordInputView: View {
    @Binding var path: [AppRoute]
    @State private var draft = DraftRecord()

    var body: some View {
        FormPage {
            FieldSection(title: "日付と時刻") {
                StaticFieldText(draft.dateTime)
            }

            FieldSection(title: "メモ（自由記載）") {
                TextEditor(text: $draft.memo)
                    .font(.system(size: 17))
                    .foregroundColor(Color.textPrimary)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .overlay(alignment: .topLeading) {
                        if draft.memo.isEmpty {
                            Text("今日の状態を入力")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.textSecondary.opacity(0.75))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }

            OptionPicker(title: "痛みの度合い", selection: $draft.painLevel, options: PainRecordOptions.painLevels)
            OptionPicker(title: "動ける状態", selection: $draft.movement, options: PainRecordOptions.movements)
            OptionPicker(title: "睡眠の状態", selection: $draft.sleep, options: PainRecordOptions.sleeps)
            OptionPicker(title: "頭の働き（ブレインフォグ）", selection: $draft.brainFog, options: PainRecordOptions.brainFogs)

            FieldSection(title: "痛い時間帯") {
                VStack(spacing: 0) {
                    ForEach(PainRecordOptions.painTimes, id: \.self) { item in
                        Toggle(item, isOn: Binding(
                            get: { draft.painTimes.contains(item) },
                            set: { isOn in
                                if isOn {
                                    draft.painTimes.insert(item)
                                } else {
                                    draft.painTimes.remove(item)
                                }
                            }
                        ))
                        .frame(minHeight: 48)
                    }
                }
            }

            Button {
                path.append(.environment(draft))
            } label: {
                ActionLabel(title: "次へ", color: .mandalaBlue, foreground: .white)
            }

            Button {
                path.removeAll()
            } label: {
                ActionLabel(title: "最初に戻る", color: .clearButton, foreground: .textPrimary)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EnvironmentInputView: View {
    @EnvironmentObject private var store: DiaryRecordStore
    @EnvironmentObject private var pressureStore: PressureMeasurementStore
    @EnvironmentObject private var stepCountStore: YesterdayStepCountStore
    @Binding var path: [AppRoute]
    @State private var draft: DraftRecord
    @State private var didSave = false

    init(path: Binding<[AppRoute]>, draft: DraftRecord) {
        _path = path
        _draft = State(initialValue: draft)
    }

    var body: some View {
        FormPage {
            Text("環境と日常活動")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            OptionPicker(title: "天候", selection: $draft.weather, options: PainRecordOptions.weathers)
            OptionPicker(title: "気温", selection: $draft.temperature, options: PainRecordOptions.temperatures)
            OptionPicker(title: "気圧の変化", selection: $draft.pressure, options: PainRecordOptions.pressures)
            OptionPicker(title: "日常の通勤・通学・家事の活動性", selection: $draft.dailyActivity, options: PainRecordOptions.dailyActivities)

            Button {
                store.add(
                    draft.record(
                        pressureMeasurement: pressureStore.currentMeasurement(),
                        yesterdayStepCount: stepCountStore.currentYesterdayStepCount(),
                        dayBeforeYesterdayStepCount: stepCountStore.currentDayBeforeYesterdayStepCount()
                    )
                )
                didSave = true
            } label: {
                ActionLabel(title: "保存", color: .accentGreen, foreground: .white)
            }

            Button("最初に戻る") {
                path.removeAll()
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(Color.clearButton, in: RoundedRectangle(cornerRadius: 14))
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.textPrimary)
        }
        .alert("保存しました", isPresented: $didSave) {
            Button("OK", role: .cancel) { }
        }
    }
}

struct SavedRecordsView: View {
    @EnvironmentObject private var store: DiaryRecordStore
    @Binding var path: [AppRoute]
    @State private var deleteTarget: DiaryRecord?
    @State private var shareItem: ShareItem?
    @State private var shareErrorMessage = ""
    @State private var showsShareError = false

    var body: some View {
        FormPage {
            HStack(alignment: .center, spacing: 12) {
                Text("保存済み記録")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    shareSavedRecords()
                } label: {
                    Text("データ共有")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(store.records.isEmpty ? Color.textSecondary : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            store.records.isEmpty ? Color.clearButton : Color.mandalaBlue,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: UIScreen.main.bounds.width * 0.45)
                .disabled(store.records.isEmpty)
            }

            if store.records.isEmpty {
                Text("保存された記録はありません")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(store.records.reversed()) { record in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(recordSummary(record))
                            .font(.system(size: 16))
                            .lineSpacing(4)
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            Button {
                                deleteTarget = record
                            } label: {
                                ActionLabel(title: "削除", color: .deleteSoft, foreground: .deleteRed, height: 48)
                            }
                            .frame(maxWidth: .infinity)

                            Spacer(minLength: 0)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(18)
                    .background(Color.savedRecord, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.inputBorder.opacity(0.65), lineWidth: 1)
                    )
                }
            }

            Button("最初に戻る") {
                path.removeAll()
            }
            .buttonStyle(PlainButtonStyle())
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
        }
        .alert("この記録を削除しますか？", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("削除", role: .destructive) {
                if let deleteTarget {
                    store.delete(deleteTarget)
                }
                deleteTarget = nil
            }
            Button("キャンセル", role: .cancel) {
                deleteTarget = nil
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.url])
        }
        .alert("共有ファイルを作成できませんでした", isPresented: $showsShareError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(shareErrorMessage)
        }
    }

    private func shareSavedRecords() {
        do {
            shareItem = ShareItem(url: try store.makeShareFile())
        } catch {
            shareErrorMessage = error.localizedDescription
            showsShareError = true
        }
    }

    private func recordSummary(_ record: DiaryRecord) -> String {
        var lines = [
            "日付と時刻: \(record.dateTime)",
            "痛みの度合い: \(record.painLevel)",
            "動ける状態: \(record.movement)",
            "睡眠の状態: \(record.sleep)",
            "頭の働き（ブレインフォグ）: \(record.brainFog)",
            "痛い時間帯: \(record.painTime)",
            "天候: \(record.weather)",
            "気温: \(record.temperature)",
            "気圧の変化: \(record.pressure)"
        ]

        if let measuredPressure = record.measuredPressureHectopascals {
            lines.append(String(format: "実測気圧：%.1f hPa", measuredPressure))
            if let pressureMeasuredAt = record.pressureMeasuredAt {
                lines.append(
                    "気圧測定時刻：\(DateFormatter.pressureMeasurementDateTime.string(from: pressureMeasuredAt))"
                )
            }
        }

        if let yesterdayStepCount = record.yesterdayStepCount {
            lines.append("昨日の歩数：\(yesterdayStepCount)歩")
        }

        if let dayBeforeYesterdayStepCount = record.dayBeforeYesterdayStepCount {
            lines.append("一昨日の歩数：\(dayBeforeYesterdayStepCount)歩")
        }

        lines.append("日常の通勤・通学・家事の活動性: \(record.dailyActivity)")
        lines.append("メモ: \(record.memo)")
        return lines.joined(separator: "\n")
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

struct MandalaDataView: View {
    @EnvironmentObject private var store: DiaryRecordStore
    @Binding var path: [AppRoute]
    @State private var selectedDays = 7
    @State private var selectedRecordID: DiaryRecord.ID?
    private let periods = [(7, "1週"), (14, "2週"), (28, "4週"), (56, "8週"), (84, "12週"), (182, "26週")]

    private var selectedRecords: [DiaryRecord] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(selectedDays - 1), to: todayStart),
              let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) else {
            return []
        }
        return store.records.reversed().filter { record in
            guard let date = DateFormatter.painRecordDateTime.date(from: record.dateTime) else { return false }
            return date >= start && date <= end
        }
    }

    private var selectedRecord: DiaryRecord? {
        guard let selectedRecordID else { return nil }
        return selectedRecords.first { $0.id == selectedRecordID }
    }

    var body: some View {
        FormPage {
            Text("曼荼羅用データ")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(periodText)
                .font(.system(size: 17))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(periods, id: \.0) { days, title in
                        Button(title) {
                            selectedDays = days
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(selectedDays == days ? .white : Color.textPrimary)
                        .frame(width: 76, height: 50)
                        .background(selectedDays == days ? Color.accentGreen : Color.clearButton, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if selectedRecords.isEmpty {
                    Text("保存された記録はありません")
                } else {
                    ForEach(Array(selectedRecords.enumerated()), id: \.element.id) { index, record in
                        Button {
                            selectedRecordID = record.id
                        } label: {
                            Text(mandalaRecordText(index: index, record: record))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    selectedRecordID == record.id ? Color.softBlue : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
                .font(.system(size: 17))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.inputBorder.opacity(0.65), lineWidth: 1)
                )

            Text("6×6曼荼羅マップ")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal) {
                MandalaMap(records: selectedRecords)
                    .frame(width: 372, height: 372)
                    .padding(10)
                    .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.inputBorder.opacity(0.65), lineWidth: 1)
                    )
            }

            if let selectedRecord {
                MandalaRecordDetail(record: selectedRecord)
            }

            LegendView()

            VStack(spacing: 16) {
                Button {
                    path.removeAll()
                } label: {
                    MandalaNavigationButtonLabel(title: "最初に戻る")
                }

                NavigationLink(value: AppRoute.olderWeeksMandala) {
                    MandalaNavigationButtonLabel(title: "13〜26週の曼荼羅")
                }
                .padding(.top, 8)

                NavigationLink(value: AppRoute.stepsPainMandala) {
                    MandalaNavigationButtonLabel(title: "歩数×疼痛の曼荼羅")
                }

                NavigationLink(value: AppRoute.pressurePainMandala) {
                    MandalaNavigationButtonLabel(title: "気圧×疼痛の曼荼羅")
                }
            }
        }
        .onChange(of: selectedDays) { _, _ in
            guard let selectedRecordID,
                  !selectedRecords.contains(where: { $0.id == selectedRecordID }) else {
                return
            }
            self.selectedRecordID = nil
        }
    }

    private var periodText: String {
        let dates = selectedRecords.compactMap { DateFormatter.painRecordDateTime.date(from: $0.dateTime) }
        guard let oldest = dates.min(), let newest = dates.max() else {
            return "対象期間：記録なし"
        }
        return "対象期間：\(DateFormatter.painRecordDateOnly.string(from: oldest)) ～ \(DateFormatter.painRecordDateOnly.string(from: newest))"
    }

    private func mandalaRecordText(index: Int, record: DiaryRecord) -> String {
        "\(index + 1)回前　痛み：\(leadingNumber(record.painLevel))　動ける状態：\(leadingNumber(record.movement))"
    }
}

struct OlderWeeksMandalaView: View {
    @EnvironmentObject private var store: DiaryRecordStore
    @Binding var path: [AppRoute]

    private var records: [DiaryRecord] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -181, to: todayStart),
              let end = calendar.date(byAdding: .day, value: -84, to: todayStart) else {
            return []
        }

        return store.records.reversed().filter { record in
            guard let date = DateFormatter.painRecordDateTime.date(from: record.dateTime) else {
                return false
            }
            return date >= start && date < end
        }
    }

    var body: some View {
        FormPage {
            Text("13〜26週の曼荼羅")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("13〜26週の記録：\(records.count)件")
                .font(.system(size: 16))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal) {
                MandalaMap(records: records)
                    .frame(width: 372, height: 372)
                    .padding(10)
                    .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.inputBorder.opacity(0.65), lineWidth: 1)
                    )
            }

            Text(olderRecordsText)
                .font(.system(size: 16))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                if !path.isEmpty {
                    path.removeLast()
                }
            } label: {
                MandalaNavigationButtonLabel(title: "元の曼荼羅に戻る")
            }
        }
    }

    private var olderRecordsText: String {
        guard !records.isEmpty else { return "この期間の記録はありません" }
        return records.enumerated().map { index, record in
            "\(index + 1). 痛み\(leadingNumber(record.painLevel))・活動\(leadingNumber(record.movement))"
        }.joined(separator: "\n")
    }
}

struct MandalaNavigationButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.mandalaBlue, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct MandalaRecordDetail: View {
    let record: DiaryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("選択した記録")
                .font(.system(size: 18, weight: .bold))
            Text("記録日時：\(record.dateTime)")
            Text("痛みの度合い：\(record.painLevel)")
            Text("動ける状態：\(record.movement)")
            if let yesterdayStepCount = record.yesterdayStepCount {
                Text("昨日の歩数：\(yesterdayStepCount)歩")
            }
            if let dayBeforeYesterdayStepCount = record.dayBeforeYesterdayStepCount {
                Text("一昨日の歩数：\(dayBeforeYesterdayStepCount)歩")
            }
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.inputBorder.opacity(0.65), lineWidth: 1)
        )
    }
}

struct MandalaMap: View {
    let records: [DiaryRecord]

    var body: some View {
        Canvas { context, size in
            let cell = min(size.width, size.height) / 7
            let gridColor = Color(red: 0.835, green: 0.851, blue: 0.871)
            let textColor = Color.textPrimary

            for row in 0..<7 {
                for column in 0..<7 {
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.stroke(Path(rect), with: .color(gridColor), lineWidth: 1)
                    let label: String
                    if row == 0 && column > 0 {
                        label = "痛\(column)"
                    } else if column == 0 && row > 0 {
                        label = "動\(row)"
                    } else {
                        label = ""
                    }
                    if !label.isEmpty {
                        drawText(label, in: &context, at: CGPoint(x: rect.midX, y: rect.midY), color: textColor, size: 14, weight: .regular)
                    }
                }
            }

            let points = positionedPoints(cell: cell)
            let linePath = Path { path in
                let ordered = points.reversed()
                for (index, point) in ordered.enumerated() {
                    if index == 0 {
                        path.move(to: point.position)
                    } else {
                        path.addLine(to: point.position)
                    }
                }
            }
            context.stroke(linePath, with: .color(Color.textPrimary.opacity(0.35)), lineWidth: 1.5)

            for point in points where !point.isLatest {
                context.fill(Path(ellipseIn: CGRect(x: point.position.x - 12, y: point.position.y - 12, width: 24, height: 24)), with: .color(point.color))
                drawText(point.label, in: &context, at: point.position, color: .white, size: 12, weight: .bold)
            }

            for point in points where point.isLatest {
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: point.position.x - 12,
                        y: point.position.y - 12,
                        width: 24,
                        height: 24
                    )),
                    with: .color(Color(red: 245 / 255, green: 184 / 255, blue: 32 / 255))
                )
                drawText("1", in: &context, at: point.position, color: .black, size: 12, weight: .bold)
            }
        }
    }

    private func positionedPoints(cell: CGFloat) -> [MandalaPoint] {
        var cellCounts: [String: Int] = [:]
        return records.enumerated().compactMap { displayIndex, record in
            guard let pain = Int(leadingNumber(record.painLevel)),
                  let movement = Int(leadingNumber(record.movement)),
                  (1...6).contains(pain),
                  (1...6).contains(movement),
                  let date = DateFormatter.painRecordDateTime.date(from: record.dateTime) else {
                return nil
            }
            let key = "\(pain)-\(movement)"
            let count = cellCounts[key, default: 0]
            cellCounts[key] = count + 1
            let isLatest = displayIndex == 0
            let center = CGPoint(x: (CGFloat(pain) + 0.5) * cell, y: (CGFloat(movement) + 0.5) * cell)
            let offset = pointOffset(index: count, isLatest: isLatest)
            return MandalaPoint(
                position: CGPoint(x: center.x + offset.x, y: center.y + offset.y),
                label: "\(displayIndex + 1)",
                color: colorForRecordDate(date),
                isLatest: isLatest
            )
        }
    }

    private func pointOffset(index: Int, isLatest: Bool) -> CGPoint {
        if isLatest { return .zero }
        let offset: CGFloat = 12
        switch index % 5 {
        case 1: return CGPoint(x: -offset, y: -offset)
        case 2: return CGPoint(x: offset, y: -offset)
        case 3: return CGPoint(x: -offset, y: offset)
        case 4: return CGPoint(x: offset, y: offset)
        default: return CGPoint(x: offset, y: 0)
        }
    }

    private func colorForRecordDate(_ date: Date) -> Color {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let daysAgo = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: todayStart).day ?? 0
        if daysAgo < 7 { return .black }
        if daysAgo < 14 { return Color(red: 0.761, green: 0.224, blue: 0.204) }
        if daysAgo < 28 { return Color(red: 0.455, green: 0.290, blue: 0.659) }
        if daysAgo < 56 { return .accentGreen }
        if daysAgo < 84 { return .mandalaBlue }
        return Color(red: 0.902, green: 0.435, blue: 0.125)
    }

    private func drawText(_ text: String, in context: inout GraphicsContext, at point: CGPoint, color: Color, size: CGFloat, weight: Font.Weight) {
        let resolved = context.resolve(Text(text).font(.system(size: size, weight: weight)).foregroundColor(color))
        context.draw(resolved, at: point, anchor: .center)
    }
}

struct MandalaPoint {
    let position: CGPoint
    let label: String
    let color: Color
    let isLatest: Bool
}

struct LegendView: View {
    private let legends: [(Color, String)] = [
        (.black, "過去1週間"),
        (Color(red: 0.761, green: 0.224, blue: 0.204), "過去2週間"),
        (Color(red: 0.455, green: 0.290, blue: 0.659), "過去4週間"),
        (.accentGreen, "過去8週間"),
        (.mandalaBlue, "過去12週間"),
        (Color(red: 0.902, green: 0.435, blue: 0.125), "13〜26週")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("現在位置")
                .font(.system(size: 17, weight: .bold))
            HStack(spacing: 10) {
                Text("★")
                    .foregroundStyle(Color(red: 0.961, green: 0.722, blue: 0.125))
                Text("最新の記録")
            }
            .font(.system(size: 17))

            Text("色の説明")
                .font(.system(size: 17, weight: .bold))
                .padding(.top, 6)
            ForEach(legends, id: \.1) { color, label in
                HStack(spacing: 10) {
                    Circle().fill(color).frame(width: 16, height: 16)
                    Text(label)
                }
                .font(.system(size: 17))
            }
        }
        .foregroundStyle(Color.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.inputBorder.opacity(0.65), lineWidth: 1)
        )
    }
}

struct FormPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                content
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }
}

struct FieldSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            content
                .padding(.horizontal, 17)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.inputBorder, lineWidth: 1)
                        .allowsHitTesting(false)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OptionPicker: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        FieldSection(title: title) {
            HStack {
                Spacer(minLength: 0)

                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option).font(.system(size: 17)).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.textPrimary)
                .font(.system(size: 17))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct StaticFieldText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 17))
            .foregroundStyle(Color.textPrimary)
            .frame(minHeight: 38, alignment: .center)
    }
}

struct ActionLabel: View {
    let title: String
    let color: Color
    let foreground: Color
    var height: CGFloat = 56

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: height)
            .background(color, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct CompassMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
            Circle()
                .stroke(Color.accentGreen, lineWidth: 4)
            ForEach(0..<8) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Color.mandalaBlue : Color.accentGreen)
                    .frame(width: 6, height: index.isMultiple(of: 2) ? 42 : 28)
                    .offset(y: -32)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            Circle()
                .fill(Color.clearButton)
                .frame(width: 34, height: 34)
            Text("痛")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.textPrimary)
        }
    }
}

private func leadingNumber(_ value: String) -> String {
    String(value.prefix { $0.isNumber })
}
