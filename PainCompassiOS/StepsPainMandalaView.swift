import SwiftUI

struct StepsPainMandalaView: View {
    enum StepDay: String, CaseIterable {
        case yesterday = "昨日の歩数"
        case dayBeforeYesterday = "一昨日の歩数"
    }

    @EnvironmentObject private var store: DiaryRecordStore
    @Binding var path: [AppRoute]
    @State private var selectedStepDay: StepDay = .yesterday
    @State private var selectedPeriod: StepsPainMandalaPeriod = .oneWeek

    private var points: [StepsPainMandalaPoint] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard let periodStart = calendar.date(
            byAdding: .day,
            value: -(selectedPeriod.days - 1),
            to: todayStart
        ), let periodEnd = calendar.date(
            bySettingHour: 23,
            minute: 59,
            second: 59,
            of: Date()
        ) else {
            return []
        }

        let datedRecords = store.records
            .compactMap { record -> (DiaryRecord, Date)? in
                guard let date = DateFormatter.painRecordDateTime.date(from: record.dateTime) else {
                    return nil
                }
                return (record, date)
            }
            .filter { $0.1 >= periodStart && $0.1 <= periodEnd }
            .sorted { $0.1 > $1.1 }

        let validCoordinates = datedRecords.compactMap { entry -> (pain: Int, stepLevel: Int, date: Date)? in
                let record = entry.0
                guard let pain = Int(Self.leadingNumber(record.painLevel)),
                      (1...6).contains(pain),
                      let steps = stepCount(for: record) else {
                    return nil
                }
                return (pain, Self.stepLevel(for: steps), entry.1)
            }

        return validCoordinates.enumerated().map { index, coordinate in
            StepsPainMandalaPoint(
                    pain: coordinate.pain,
                    stepLevel: coordinate.stepLevel,
                    label: "\(index + 1)",
                    color: Self.color(for: coordinate.date, calendar: calendar),
                    isLatest: index == 0
                )
        }
    }

    var body: some View {
        FormPage {
            Text("歩数×疼痛曼荼羅")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(StepDay.allCases, id: \.self) { stepDay in
                    Button(stepDay.rawValue) {
                        selectedStepDay = stepDay
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(selectedStepDay == stepDay ? .white : Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        selectedStepDay == stepDay ? Color.accentGreen : Color.clearButton,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StepsPainMandalaPeriod.allCases) { period in
                        Button(period.title) {
                            selectedPeriod = period
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(selectedPeriod == period ? .white : Color.textPrimary)
                        .frame(width: 76, height: 50)
                        .background(
                            selectedPeriod == period ? Color.accentGreen : Color.clearButton,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                    }
                }
            }

            Text("\(selectedStepDay.rawValue)と疼痛（\(selectedPeriod.title)）：\(points.count)件")
                .font(.system(size: 16))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal) {
                StepsPainMandalaMap(points: points)
                    .frame(width: 372, height: 372)
                    .padding(10)
                    .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.inputBorder.opacity(0.65), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("歩数レベルの説明")
                    .font(.system(size: 18, weight: .bold))
                Text("歩1：0〜500歩")
                Text("歩2：501〜1,000歩")
                Text("歩3：1,001〜2,500歩")
                Text("歩4：2,501〜5,000歩")
                Text("歩5：5,001〜8,000歩")
                Text("歩6：8,001歩以上")
            }
            .font(.system(size: 16))
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 14))

            StepsPainMandalaLegend()

            Button {
                path.removeAll()
            } label: {
                ActionLabel(title: "最初に戻る", color: .clearButton, foreground: .textPrimary)
            }
        }
    }

    private func stepCount(for record: DiaryRecord) -> Int? {
        switch selectedStepDay {
        case .yesterday:
            record.yesterdayStepCount
        case .dayBeforeYesterday:
            record.dayBeforeYesterdayStepCount
        }
    }

    static func stepLevel(for steps: Int) -> Int {
        switch steps {
        case ...500: 1
        case ...1_000: 2
        case ...2_500: 3
        case ...5_000: 4
        case ...8_000: 5
        default: 6
        }
    }

    private static func color(for date: Date, calendar: Calendar) -> Color {
        let todayStart = calendar.startOfDay(for: Date())
        let daysAgo = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: todayStart
        ).day ?? 0

        if daysAgo < 7 { return .black }
        if daysAgo < 14 { return Color(red: 0.761, green: 0.224, blue: 0.204) }
        if daysAgo < 28 { return Color(red: 0.455, green: 0.290, blue: 0.659) }
        if daysAgo < 56 { return .accentGreen }
        if daysAgo < 84 { return .mandalaBlue }
        return Color(red: 0.902, green: 0.435, blue: 0.125)
    }

    private static func leadingNumber(_ value: String) -> String {
        String(value.prefix { $0.isNumber })
    }
}

struct StepsPainMandalaMap: View {
    let points: [StepsPainMandalaPoint]

    var body: some View {
        Canvas { context, size in
            let cell = min(size.width, size.height) / 7
            drawGrid(context: &context, cell: cell)

            let positionedPoints = positionedPoints(cell: cell)
            drawLines(context: &context, cell: cell)

            for point in positionedPoints where !point.point.isLatest {
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: point.position.x - 12,
                        y: point.position.y - 12,
                        width: 24,
                        height: 24
                    )),
                    with: .color(point.point.color)
                )
                drawText(
                    point.point.label,
                    in: &context,
                    at: point.position,
                    color: .white,
                    size: 12,
                    weight: .bold
                )
            }

            for point in positionedPoints where point.point.isLatest {
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: point.position.x - 12,
                        y: point.position.y - 12,
                        width: 24,
                        height: 24
                    )),
                    with: .color(Color(red: 245 / 255, green: 184 / 255, blue: 32 / 255))
                )
                drawText(
                    "1",
                    in: &context,
                    at: point.position,
                    color: .black,
                    size: 12,
                    weight: .bold
                )
            }
        }
    }

    private func drawGrid(context: inout GraphicsContext, cell: CGFloat) {
        let gridColor = Color(red: 0.835, green: 0.851, blue: 0.871)
        for row in 0..<7 {
            for column in 0..<7 {
                let rect = CGRect(
                    x: CGFloat(column) * cell,
                    y: CGFloat(row) * cell,
                    width: cell,
                    height: cell
                )
                context.stroke(Path(rect), with: .color(gridColor), lineWidth: 1)

                let label: String
                if row == 0 && column > 0 {
                    label = "痛\(column)"
                } else if column == 0 && row > 0 {
                    label = "歩\(7 - row)"
                } else {
                    label = ""
                }
                if !label.isEmpty {
                    drawText(label, in: &context, at: CGPoint(x: rect.midX, y: rect.midY), color: .textPrimary, size: 14, weight: .regular)
                }
            }
        }
    }

    private func drawLines(context: inout GraphicsContext, cell: CGFloat) {
        guard points.count >= 2 else { return }
        let path = Path { path in
            for (index, point) in points.reversed().enumerated() {
                let center = center(of: point, cell: cell)
                if index == 0 {
                    path.move(to: center)
                } else {
                    path.addLine(to: center)
                }
            }
        }
        context.stroke(path, with: .color(Color.textPrimary.opacity(0.35)), lineWidth: 1.5)
    }

    private func positionedPoints(cell: CGFloat) -> [PositionedStepsPainPoint] {
        var sameCellCounts: [String: Int] = [:]
        return points.map { point in
            let key = "\(point.pain)-\(point.stepLevel)"
            let count = sameCellCounts[key, default: 0]
            sameCellCounts[key] = count + 1
            let center = center(of: point, cell: cell)
            let offset = pointOffset(index: count, isLatest: point.isLatest)
            return PositionedStepsPainPoint(
                point: point,
                position: CGPoint(x: center.x + offset.x, y: center.y + offset.y)
            )
        }
    }

    private func center(of point: StepsPainMandalaPoint, cell: CGFloat) -> CGPoint {
        let row = 7 - point.stepLevel
        return CGPoint(
            x: (CGFloat(point.pain) + 0.5) * cell,
            y: (CGFloat(row) + 0.5) * cell
        )
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

    private func drawText(
        _ text: String,
        in context: inout GraphicsContext,
        at point: CGPoint,
        color: Color,
        size: CGFloat,
        weight: Font.Weight
    ) {
        let resolved = context.resolve(
            Text(text).font(.system(size: size, weight: weight)).foregroundColor(color)
        )
        context.draw(resolved, at: point, anchor: .center)
    }
}

struct StepsPainMandalaPoint {
    let pain: Int
    let stepLevel: Int
    let label: String
    let color: Color
    var isLatest = false
}

private struct PositionedStepsPainPoint {
    let point: StepsPainMandalaPoint
    let position: CGPoint
}

enum StepsPainMandalaPeriod: Int, CaseIterable, Identifiable {
    case oneWeek = 7
    case twoWeeks = 14
    case fourWeeks = 28
    case eightWeeks = 56
    case twelveWeeks = 84
    case twentySixWeeks = 182

    var id: Int { rawValue }
    var days: Int { rawValue }

    var title: String {
        switch self {
        case .oneWeek: "1週"
        case .twoWeeks: "2週"
        case .fourWeeks: "4週"
        case .eightWeeks: "8週"
        case .twelveWeeks: "12週"
        case .twentySixWeeks: "26週"
        }
    }
}

struct StepsPainMandalaLegend: View {
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
                Text("1")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color(red: 245 / 255, green: 184 / 255, blue: 32 / 255))
                Text("最新の対象記録")
            }

            Text("色の説明")
                .font(.system(size: 17, weight: .bold))
                .padding(.top, 6)
            ForEach(legends, id: \.1) { color, label in
                HStack(spacing: 10) {
                    Circle().fill(color).frame(width: 16, height: 16)
                    Text(label)
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
    }
}
