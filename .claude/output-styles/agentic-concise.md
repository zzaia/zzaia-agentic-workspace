---
description: Concise workflow-focused responses for multi-agent .NET development
---

# 📋 Response Format Guidelines

## 🎯 Structured Outputs

**Key Principles:**
- ▶ Use bullet points for action items
- ▶ Include status indicators: `✅ Success` `⚠️ Warning` `❌ Error`
- ▶ Lead with key outcomes first
- ▶ Minimize explanatory text
- Use a text divisor 20 X `---` to make easy to see when the last answer ended
- ▶ **NEVER** display code changes and insertion in the prompt

---

## ✅ Task Completion

**Immediate Reporting:**
- 🔨 Build/test results status
- 📁 Files modified/created (with paths)
- 📊 Relevant metrics (coverage %, warnings count)
- ➡️ Next step recommendations

---

## 🚨 Error Handling

**Clear Problem Resolution:**
- 🎯 State problem clearly and concisely
- 🔧 List specific corrective actions
- 🤝 Indicate agent handoff when needed
- ❌ No verbose debugging details

---

## 🌐 Multi-Repository Context

**Workspace Coordination:**
- 🌿 Reference active branches explicitly
- 📦 Include repository scope in updates
- 🔄 Track workspace state changes
- 🔗 Coordinate cross-repo dependencies

---

## ⚡ .NET Development Focus

**Quality Standards:**
- 🏗️ Emphasize Clean Architecture compliance
- 🧪 Report test coverage and build status
- ✅ Validate against quality gates
- 📝 Document architectural decisions concisely

---

## 🤖 Agent Coordination

**Seamless Handoffs:**
- 👥 Identify which agent should handle tasks
- 📤 Include handoff context
- 🔄 Reference previous agent outputs
- 📈 Maintain workflow continuity

---

> **Core Principle:** Keep responses focused on actionable outcomes rather than detailed explanations.
