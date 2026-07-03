export const meta = {
  name: 'workflows:local:architect',
  description: 'Orchestrate local architectural documentation with BDD, SDD, plan, and per-item specifications using Specification Driven Design — no PR, no work items, local-only review',
  whenToUse: 'Generate architectural documentation locally from workspace and document context, with generated specifications reviewed directly on the local branch after completion',
  phases: [
    { title: 'Context' },
    { title: 'Branch' },
    { title: 'Clarification' },
    { title: 'Behavior Docs' },
    { title: 'Specification Docs' },
    { title: 'Plan' },
    { title: 'Per-Item Docs' },
  ],
}

// args: { repo, branch, targetBranch, description, workspace: [path], doc: [path] }

const CLARIFICATION_SCHEMA = {
  type: 'object',
  properties: {
    questions: { type: 'array', items: { type: 'string' } },
    assumedAnswers: { type: 'array', items: { type: 'string' } },
  },
  required: ['questions', 'assumedAnswers'],
}

const PLAN_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          title: { type: 'string' },
          type: { type: 'string' },
          parentId: { type: ['string', 'null'] },
          predecessors: { type: 'array', items: { type: 'string' } },
          successors: { type: 'array', items: { type: 'string' } },
          wave: { type: 'number' },
          isLeaf: { type: 'boolean' },
        },
        required: ['id', 'title', 'type', 'wave'],
      },
    },
  },
  required: ['items'],
}

phase('Context')
const contextAgents = []

// Gather workspace paths in parallel
if (args.workspace && Array.isArray(args.workspace) && args.workspace.length > 0) {
  contextAgents.push(
    ...args.workspace.map(
      path =>
        () =>
          agent(
            `Inspect the workspace repository at path "${path}". Summarize the source code structure, configuration files, existing documentation, and any relevant architectural patterns or dependencies. Keep the summary concise but comprehensive.`,
            { agentType: 'zzaia-workspace-manager', label: `workspace:${path}` }
          )
    )
  )
}

// Gather doc paths in parallel
if (args.doc && Array.isArray(args.doc) && args.doc.length > 0) {
  contextAgents.push(
    ...args.doc.map(
      path =>
        () =>
          agent(
            `Use the SlashCommand tool to invoke: /capability:document:read --file "${path}". This reads and extracts key requirements, design principles, constraints, and domain concepts relevant to architectural design.`,
            { agentType: 'zzaia-document-specialist', label: `doc:${path}` }
          )
    )
  )
}

let context = args.description || ''

if (contextAgents.length > 0) {
  const contextResults = await parallel(contextAgents)
  context = [context, ...contextResults.filter(Boolean)].filter(Boolean).join('\n\n---\n\n')
} else if (!context) {
  context = 'No additional context provided'
}

log(`NOTE: This local-only workflow has no approval gates by design. All generated documentation will be committed to the local branch "${args.branch || 'plan/*'}" and should be reviewed directly on disk after the run completes. There is no PR or discussion channel to gate on — the workflow runs straight through to completion.`)

phase('Branch')
if (!args.repo) {
  log(`ERROR: repo is required to proceed. This script requires --repo to be resolved before running. Returning early.`)
  return { status: 'missing-repo', message: 'repo argument is required' }
}

const branchName = args.branch || await agent(
  `Generate a branch name in the pattern "plan/<slug>" derived from this description: "${args.description || 'architectural-plan'}". Return only the branch name, no explanation.`,
  { agentType: 'zzaia-workspace-manager', label: 'generate-branch-name' }
)

await agent(
  `Use the SlashCommand tool to invoke: /behavior:workspace:repo --action new --repo ${args.repo} --branch ${branchName} --source-branch ${args.targetBranch || 'main'}. This creates a new documentation branch ready for commits.`,
  { agentType: 'zzaia-workspace-manager', label: 'create-branch' }
)

phase('Clarification')
const clarificationResult = await agent(
  `Generate critical clarification questions from this architectural context: "${context}". Also provide your own best-effort assumed answers to each question (since there is no human-in-the-loop available in this local-only workflow). Return a JSON object with two arrays: "questions" (5-10 key questions that must be answered before proceeding with design) and "assumedAnswers" (your assumed answers in the same order).`,
  { agentType: 'zzaia-task-clarifier', schema: CLARIFICATION_SCHEMA, label: 'generate-clarification' }
)

log(`CLARIFICATION: Generated ${clarificationResult.questions.length} critical questions with unconfirmed assumptions. These assumptions must be verified by reviewing the generated documentation files. Questions and assumed answers have been appended to context for downstream phases.`)

const questionsAndAnswers = clarificationResult.questions.map((q, i) => `Q: ${q}\nA (assumed): ${clarificationResult.assumedAnswers[i] || '(no assumption)'}`).join('\n\n')
context = `${context}\n\n### Clarification Questions and Assumed Answers\n${questionsAndAnswers}`

phase('Behavior Docs')
const userBddContent = await agent(
  `Use the SlashCommand tool to invoke: /behavior:management:business --context "${context}". This generates business-level behavior flows and user scenarios describing observable user interactions, expected outcomes, and business value.`,
  { agentType: 'zzaia-task-clarifier', label: 'generate-user-bdd' }
)

await agent(
  `Use the SlashCommand tool to invoke: /capability:document:write --template bdd-scenarios --title "${args.description || 'architecture'} User BDD Scenarios" --context "${userBddContent}" --output docs/user-bdd-scenarios.md. Then use the SlashCommand tool to invoke: /behavior:development:git --action commit --repo ${args.repo} --branch ${branchName} --message "docs: add behavior documentation (user and application BDD) for ${args.description || 'architecture'}"`,
  { agentType: 'zzaia-document-specialist', label: 'write-user-bdd' }
)

const appBddContent = await agent(
  `Use the SlashCommand tool to invoke: /behavior:management:architect --context "${context}". This generates application-level BDD specifications describing inter-service interactions, API contracts, event flows, and application-level behaviors.`,
  { agentType: 'zzaia-task-clarifier', label: 'generate-app-bdd' }
)

await agent(
  `Use the SlashCommand tool to invoke: /capability:document:write --template bdd-scenarios --title "${args.description || 'architecture'} Application BDD Specifications" --context "${appBddContent}" --output docs/application-bdd-specifications.md. Then use the SlashCommand tool to invoke: /behavior:development:git --action commit --repo ${args.repo} --branch ${branchName} --message "docs: add behavior documentation (user and application BDD) for ${args.description || 'architecture'}"`,
  { agentType: 'zzaia-document-specialist', label: 'write-app-bdd' }
)

phase('Specification Docs')
const sddContent = await agent(
  `Use the SlashCommand tool to invoke: /behavior:management:architect --context "${context}". This generates complete system architecture and SDD overview including bounded contexts, consistency strategies, event flows, and architectural decision records following Domain Driven Design, Clean Architecture, and SOLID principles.`,
  { agentType: 'zzaia-task-clarifier', label: 'generate-sdd' }
)

await agent(
  `Use the SlashCommand tool to invoke: /capability:document:write --template architecture-overview --title "${args.description || 'architecture'} Architecture Overview" --context "${sddContent}" --output docs/architecture-overview.md. Then use the SlashCommand tool to invoke: /behavior:development:git --action commit --repo ${args.repo} --branch ${branchName} --message "docs: add architecture overview for ${args.description || 'architecture'}"`,
  { agentType: 'zzaia-document-specialist', label: 'write-sdd' }
)

phase('Plan')
const planResult = await agent(
  `Decompose the architectural design from context: "${context}" into a parallelizable agile hierarchy of work items. Return a JSON object with an "items" array where each item has: id, title, type, parentId (or null), predecessors (array), successors (array), wave (number), and isLeaf (boolean). Do NOT include a repo field — the working repository is the single repo provided to this workflow. Consider parallelization waves and dependencies. Internally, you may use the SlashCommand tool to invoke: /behavior:management:plan --work-description "${context}" to assist with decomposition.`,
  { agentType: 'zzaia-task-clarifier', schema: PLAN_SCHEMA, label: 'generate-plan' }
)

await agent(
  `Use the SlashCommand tool to invoke: /capability:document:write --template implementation-plan --title "${args.description || 'architecture'} Implementation Plan" --context "Work items: ${JSON.stringify(planResult.items)}" --output docs/implementation-plan.md. Then use the SlashCommand tool to invoke: /behavior:development:git --action commit --repo ${args.repo} --branch ${branchName} --message "docs: add implementation plan for ${args.description || 'architecture'}"`,
  { agentType: 'zzaia-document-specialist', label: 'write-plan' }
)

const plan = planResult

phase('Per-Item Docs')
await pipeline(
  plan.items,
  item =>
    agent(
      `For work item "${item.title}" (ID: ${item.id}, Type: ${item.type}), use the SlashCommand tool to invoke the following in sequence:
1. /capability:document:write --template bdd-scenarios --title "${item.title} Specific BDD" --context "Behavior scoped to work item: ${item.title}" --output docs/${item.id}/bdd-specifications.md
2. /capability:document:write --template service-architecture --title "${item.title} Specific SDD" --context "Architecture scoped to work item: ${item.title}" --output docs/${item.id}/service-architecture.md
If applicable based on the item type, also generate data-model and domain-events documentation using the appropriate templates. Return a summary of written document paths.`,
      { agentType: 'zzaia-document-specialist', label: `per-item-docs:${item.id}` }
    )
)

await agent(
  `Use the SlashCommand tool to invoke: /behavior:development:git --action commit --repo ${args.repo} --branch ${branchName} --message "docs: add work item specifications (specific BDD and SDD) for ${args.description || 'architecture'}". This is a LOCAL commit only — do not push to any remote.`,
  { agentType: 'zzaia-document-specialist', label: 'commit-per-item-docs' }
)

return {
  branch: branchName,
  plan: plan.items,
  docsGenerated: true,
}
