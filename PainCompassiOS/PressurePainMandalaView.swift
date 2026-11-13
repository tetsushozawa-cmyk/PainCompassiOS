import SwiftUI

struct PressurePainMandalaView: View {
    @EnvironmentObject private var recordStore: DiaryRecordStore
    @EnvironmentObject private var pressureStore: PressureMeasurementStore
    @Binding var path: [AppRoute]
    @State private var selectedPeriod: PressurePainMandalaPeriod = .oneWeek

    private var points: [PressurePainMandalaPoint] {
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

        let candidates = pressureCandidates
        let datedRecords = recordStore.records
            .compactMap { record -> (record: DiaryRecord, recordDate: Date)? in
                guard let recordDate = DateFormatter.painRecordDateTime.date(from: record.dateTime) else {
                    return nil
                }
                return (record, recordDate)
            }
            .filter { $0.recordDate >= periodStart && $0.recordDate <= periodEnd }
            .sorted { $0.recordDate > $1.recordDate }

        let validCoordinates = datedRecords.compactMap { entry -> (Int, DailyPressureChangeLevel, Date)? in
            let record = entry.record
            guard let pain = Int(Self.leadingNumber(record.painLevel)),
                  (1...6).contains(pain),
                  let pressure = record.measuredPressureHectopascals,
                  let measuredAt = record.pressureMeasuredAt,
                  let change = DailyPressureChangeCalculator.calculate(
                    current: DailyPressureDataPoint(
                        hectopascals: pressure,
                        measuredAt: measuredAt
                    ),
                    candidates: candidates,
                    calendar: calendar
                  ) else {
                return nil
            }
            return (pain, change.level, entry.recordDate)
        }

        return validCoordinates.enumerated().map { index, coordinate in
            PressurePainMandalaPoint(
                pain: coordinate.0,
                pressureLevel: coordinate.1,
                label: "\(index + 1)",
                color: Self.color(for: coordinate.2, calendar: calendar),
                isLatest: index == 0
            )
        }
    }

    private var pressureCandidates: [DailyPressureDataPoint] {
        var candidates = pressureStore.history.map {
            DailyPressureDataPoint(
                hectopascals: $0.hectopascals,
                measuredAt: $0.measuredAt
            )
        }

        for record in recordStore.records {
            guard let pressure = record.measuredPressureHectopascals,
                  let measuredAt = record.pressureMeasuredAt else {
                continue
            }
            let candidate = DailyPressureDataPoint(
                hectopascals: pressure,
                measuredAt: measuredAt
            )
            if !candidates.contains(candidate) {
                candidates.append(candidate)
            }
        }
        return candidates
    }

    var body: some View {
        FormPage {
            Text("気圧変化×疼痛曼荼羅")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PressurePainMandalaPeriod.allCases) { period in
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

            Text("前日との気圧差と疼痛（\(selectedPeriod.title)）：\(points.count)件")
                .font(.system(size: 16))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal) {
                PressurePainMandalaMap(points: points)
                    .frame(width: 372, height: 319)
                    .padding(10)
                    .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.inputBorder.opacity(0.65), lineWidth: 1)
                    )
            }

            PressurePainClassificationGuide()
            PressurePainMandalaLegend()

            Button {
                path.removeAll()
            } label: {
                ActionLabel(title: "最初に戻る", color: .clearButton, foreground: .textPrimary)
            }
        }
    }

    private static func leadingNumber(_ value: String) -> String {
        String(value.prefix { $0.isNumber })
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
}

struct PressurePainMandalaMap: View {
    let points: [PressurePainMandalaPoint]

    var body: some View {
        Canvas { context, size in
            let cell = min(size.width / 7, size.height / 6)
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
                drawText(point.point.label, in: &context, at: point.position, color: .white, size: 12, weight: .bold)
            }

            for point in positionedPoints where point.point.isLatest {
                drawText(
                    "1",
                    in: &context,
                    at: point.position,
                    color: Color(red: 245 / 255, green: 184 / 255, blue: 32 / 255),
                    size: 27,
                    weight: .bold
                )
            }
        }
    }

    private func drawGrid(context: inout GraphicsContext, cell: CGFloat) {
        let gridColor = Color(red: 0.835, green: 0.851, blue: 0.871)
        for row in 0..<6 {
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
                    label = ["", "≥+5", ">+1", "±1", "<-1", "≤-5"][row]
                } else {
                    label = ""
                }
                if !label.isEmpty {
                    drawText(label, in: &context, at: CGPoint(x: rect.midX, y: rect.midY), color: .textPrimary, size: 13, weight: .regular)
                }
            }
        }
    }

    private func drawLines(context: inout GraphicsContext, cell: CGFloat) {
        guard points.count >= 2 else { return }
        let path = Path { path in
            for (index, point) in points.reversed().enumerated() {
                let center = center(of: point, cell: cell)
                if index == 0 { path.move(to: center) } else { path.addLine(to: center) }
            }
        }
        context.stroke(path, with: .color(Color.textPrimary.opacity(0.35)), lineWidth: 1.5)
    }

    private func positionedPoints(cell: CGFloat) -> [PositionedPressurePainPoint] {
        var sameCellCounts: [String: Int] = [:]
        return points.map { point in
            let key = "\(point.pain)-\(point.pressureLevel.rawValue)"
            let count = sameCellCounts[key, default: 0]
            sameCellCounts[key] = count + 1
            let center = center(of: point, cell: cell)
            let offset = pointOffset(index: count, isLatest: point.isLatest)
            return PositionedPressurePainPoint(
                point: point,
                position: CGPoint(x: center.x + offset.x, y: center.y + offset.y)
            )
        }
    }

    private func center(of point: PressurePainMandalaPoint, cell: CGFloat) -> CGPoint {
        let row = 3 - point.pressureLevel.rawValue
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

struct PressurePainMandalaPoint {
    let pain: Int
    let pressureLevel: DailyPressureChangeLevel
    let label: String
    let color: Color
    var isLatest = false
}

private struct PositionedPressurePainPoint {
    let point: PressurePainMandalaPoint
    let position: CGPoint
}

enum PressurePainMandalaPeriod: Int, CaseIterable, Identifiable {
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

struct PressurePainClassificationGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("気圧差の判定基準")
                .font(.system(size: 18, weight: .bold))
            Text("＋2：＋5.0 hPa以上")
            Text("＋1：＋1.0 hPa超〜＋5.0 hPa未満")
            Text("0：−1.0〜＋1.0 hPa")
            Text("−1：−5.0 hPa超〜−1.0 hPa未満")
            Text("−2：−5.0 hPa以下")
        }
        .font(.system(size: 16))
        .foregroundStyle(Color.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct PressurePainMandalaLegend: View {
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
            HStack(spacing: 10) {
                Text("1")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color(red: 245 / 255, green: 184 / 255, blue: 32 / 255))
                Text("最新の対象記録")
            }
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
