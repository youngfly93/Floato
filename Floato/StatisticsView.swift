import SwiftUI
// import ContributionChart  // 需要通过SPM添加依赖

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TodoStore.self) private var todoStore
    
    var body: some View {
        VStack(spacing: 20) {
            // 头部标题
            HStack {
                Text("番茄钟统计")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            // 统计摘要卡片
            let summary = todoStore.statisticsStore.getStatisticsSummary()
            HStack(spacing: 16) {
                StatCard(title: "今日", value: summary.today, color: .blue)
                StatCard(title: "本周", value: summary.thisWeek, color: .green)
                StatCard(title: "本月", value: summary.thisMonth, color: .orange)
                StatCard(title: "总计", value: summary.total, color: .purple)
            }
            .padding(.horizontal)
            
            // 热力图区域
            VStack(alignment: .leading, spacing: 12) {
                Text("最近一年活动")
                    .font(.headline)
                    .padding(.horizontal)
                
                // 临时使用简单的网格视图替代ContributionChart
                // 等SPM依赖添加后可以替换为真正的ContributionChart
                HeatmapGridView(data: todoStore.statisticsStore.getHeatmapData())
                    .frame(height: 120)
                    .padding(.horizontal)
                
                // 图例
                HStack {
                    Text("少")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 3) {
                        ForEach(0..<5) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(heatmapColor(for: level))
                                .frame(width: 12, height: 12)
                        }
                    }
                    
                    Text("多")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(width: 600, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func heatmapColor(for level: Int) -> Color {
        switch level {
        case 0: return Color.gray.opacity(0.1)
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.5)
        case 3: return Color.green.opacity(0.7)
        case 4: return Color.green.opacity(0.9)
        default: return Color.green
        }
    }
}

// 统计卡片组件
struct StatCard: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// 临时的热力图网格视图
struct HeatmapGridView: View {
    let data: [Date: Int]
    
    var body: some View {
        let calendar = Calendar.current
        let weeks = generateWeeks()
        
        VStack(spacing: 3) {
            ForEach(0..<weeks.count, id: \.self) { weekIndex in
                HStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let dayOffset = weekIndex * 7 + dayIndex
                        if let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) {
                            let count = data[date] ?? 0
                            let level = min(count, 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(heatmapColor(for: level))
                                .frame(width: 12, height: 12)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.clear)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
        }
    }
    
    private func generateWeeks() -> [Int] {
        return Array(0..<52) // 52周
    }
    
    private func heatmapColor(for level: Int) -> Color {
        switch level {
        case 0: return Color.gray.opacity(0.1)
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.5)
        case 3: return Color.green.opacity(0.7)
        case 4: return Color.green.opacity(0.9)
        default: return Color.green
        }
    }
}

#Preview {
    StatisticsView()
}