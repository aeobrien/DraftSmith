import SwiftUI

struct PromptInspectorView: View {
    @Environment(PromptManagerService.self) private var promptManager

    @State private var templates: [PromptTemplate] = []
    @State private var selectedTask: PromptTask = .diplomaticComment

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Prompt Inspector")
                .font(.title2)

            Picker("Task", selection: $selectedTask) {
                ForEach(PromptTask.allCases) { task in
                    Text(task.displayName).tag(task)
                }
            }
            .pickerStyle(.segmented)

            if let template = templates.first(where: { $0.promptTask == selectedTask && $0.isActive }) {
                VStack(alignment: .leading, spacing: 12) {
                    GroupBox("System Directive") {
                        Text(template.systemDirective)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }

                    GroupBox("Task Template (v\(template.version))") {
                        ScrollView {
                            Text(template.taskTemplate)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 400)
                    }

                    // Token budget breakdown
                    GroupBox("Token Budget") {
                        let budget = TokenBudget.default
                        VStack(alignment: .leading, spacing: 4) {
                            BudgetRow(label: "System", tokens: budget.system, color: .blue)
                            BudgetRow(label: "Guide", tokens: budget.guide, color: .green)
                            BudgetRow(label: "Capsule", tokens: budget.capsule, color: .purple)
                            BudgetRow(label: "Examples", tokens: budget.examples, color: .orange)
                            BudgetRow(label: "Input", tokens: budget.input, color: .red)
                            BudgetRow(label: "Output (reserved)", tokens: budget.output, color: .gray)
                            Divider()
                            BudgetRow(label: "Total", tokens: budget.totalBudget, color: .primary)
                        }
                    }
                }
            } else {
                Text("No active template for this task.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear {
            templates = promptManager.fetchAllTemplates()
        }
    }
}

private struct BudgetRow: View {
    let label: String
    let tokens: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
            Spacer()
            Text("\(tokens) tokens")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
