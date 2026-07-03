export const meta = {
  name: 'workflows:remote:architect',
  description: 'Orchestrate architectural documentation via pull request with BDD, SDD, plan, and work-item creation using Specification Driven Design',
  whenToUse: 'Document complex architectural requirements through a SDD workflow, generating behavior specifications, architectural overview, implementation plan, and parallelizable work-item hierarchy',
  phases: [
    { title: 'Context' },
    { title: 'Branch & PR' },
    { title: 'Work Item' },
    { title: 'Clarification' },
    { title: 'Behavior Docs' },
    { title: 'Specification Docs' },
    { title: 'Plan' },
    { title: 'Per-Item Docs' },
    { title: 'Create Work Items' },
  ],
}

// args: { project, selectedWorkItem, selectedRepo, selectedBranch, targetBranch, description, workspace: [path], doc: [path], url: [path] }

const REVIEW_GATE_SCHEMA = {
  type: 'object',
  properties: {
    approved: { type: 'boolean' },
    changesRequested: { type: ['string', 'null'] },
  },
  required: ['approved'],
}

const WORK_ITEM_SCHEMA = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    title: { type: 'string' },
    description: { type: 'string' },
  },
  required: ['id', 'title', 'description'],
}

const CLARIFICATION_SCHEMA = {
  type: 'object',
  properties: {
    answers: { type: 'array', items: { type: 'string' } },
  },
  required: ['answers'],
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
          repo: { type: 'string' },
          isLeaf: { type: 'boolean' },
        },
        required: ['id', 'title', 'type', 'wave'],
      },
    },
  },
  required: ['items'],
}

const PR_SCHEMA = {
  type: 'object',
  properties: {
    url: { type: 'string' },
    id: { type: 'string' },
  },
  required: ['url', 'id'],
}

const WORK_ITEM_CREATE_SCHEMA = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    azureId: { type: 'string' },
  },
  required: ['id'],
}

let reviewGateInvoked = false

async function reviewGate(label, prUrl, docsSummary) {
  if (!reviewGateInvoked) {
    log(`NOTE: Every markdown phase's two-step "ask-user-question, mandatory confirm" pair collapses into this single recursive poll-and-revise helper because the script sandbox cannot pause for live chat input — approval must arrive via pull request comments on "${prUrl}". The subagent will poll periodically (approximately every 1 minute) until approval or change requests are found.`)
    reviewGateInvoked = true
  }

  const outcome = await agent(
    `Poll the pull request "${prUrl}" (description, comments, and any linked discussion) for a human review of ${label}: ${docsSummary}. Because this workflow runs non-interactively in the background, there is no live chat prompt available — check periodically (the subagent should use its own tool access to wait/retry, e.g. every ~1 minute) until the human either approves, or requests changes via PR comments. Return whether it is approved and, if not, what changes were requested.`,
    { agentType: 'zzaia-devops-specialist', schema: REVIEW_GATE_SCHEMA, label: `gate:${label}` }
  )

  if (!outcome.approved && outcome.changesRequested) {
    await agent(
      `Apply these requested changes to ${label}: ${outcome.changesRequested}. Commit and push to the documentation branch.`,
      { agentType: 'zzaia-document-specialist', label: `revise:${label}` }
    )
    return reviewGate(label, prUrl, docsSummary)
  }

  return outcome
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
            `Use SlashCommand to invoke: /capability:document:read --file "${path}". Extract and return the key requirements, design principles, constraints, and domain concepts relevant to architectural design from the extracted content.`,
            { agentType: 'zzaia-document-specialist', label: `doc:${path}` }
          )
    )
  )
}

// Gather URLs in parallel
if (args.url && Array.isArray(args.url) && args.url.length > 0) {
  contextAgents.push(
    ...args.url.map(
      url =>
        () =>
          agent(
            `Use SlashCommand to invoke: /behavior:websearch --query "${url}". Extract and return key information, specifications, standards, or patterns relevant to architectural design from the fetched content.`,
            { agentType: 'zzaia-web-searcher', label: `url:${url}` }
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

phase('Branch & PR')
if (!args.selectedRepo) {
  log(`ERROR: selectedRepo is required to proceed. This pilot script requires --selectedRepo to be resolved before running; no interactive ask-user-question fallback exists. Returning early.`)
  return { status: 'missing-repo', message: 'selectedRepo argument is required' }
}

const branchName = args.selectedBranch || await agent(
  `Generate a branch name in the pattern "plan/<slug>" derived from this description: "${args.description || 'architectural-plan'}". Return only the branch name, no explanation.`,
  { agentType: 'zzaia-workspace-manager', label: 'generate-branch-name' }
)

await agent(
  `Use SlashCommand to invoke: /behavior:workspace:repo --action new --repo "${args.selectedRepo}" --branch "${branchName}" --source-branch "${args.targetBranch || 'main'}". Ensure the branch is created and ready for documentation commits.`,
  { agentType: 'zzaia-workspace-manager', label: 'create-branch' }
)

const prResult = await agent(
  `Use SlashCommand to invoke: /behavior:devops:pull-request --action create --portal azure --project "${args.project}" --repo "${args.selectedRepo}" --source-branch "${branchName}" --target-branch "${args.targetBranch || 'main'}" --draft --title "Architecture: ${args.description || 'SDD Documentation'}". Return the PR URL and ID from the command result.`,
  { agentType: 'zzaia-devops-specialist', schema: PR_SCHEMA, label: 'create-pr' }
)

const pr = prResult

phase('Work Item')
let workItem

if (args.selectedWorkItem) {
  workItem = await agent(
    `Use SlashCommand to invoke: /behavior:devops:work-item --action read --id "${args.selectedWorkItem}" --project "${args.project}". Return the work item title, description, and any existing context.`,
    { agentType: 'zzaia-devops-specialist', schema: WORK_ITEM_SCHEMA, label: 'read-work-item' }
  )

  await agent(
    `Use SlashCommand to invoke two separate link commands: (1) /behavior:devops:work-item --action link --id "${args.selectedWorkItem}" --project "${args.project}" --type "artifact" --link "${branchName}"; (2) /behavior:devops:work-item --action link --id "${args.selectedWorkItem}" --project "${args.project}" --type "artifact" --link "${pr.url}". This links the documentation branch and pull request as artifacts to the work item.`,
    { agentType: 'zzaia-devops-specialist', label: 'link-artifacts-to-existing' }
  )
} else {
  workItem = await agent(
    `Use SlashCommand to invoke: /behavior:devops:work-item --action create --project "${args.project}" --type Epic --title "${args.description || 'Architectural Planning'}" --description "Architectural context:\\n${context}\\n\\nDocumentation branch: ${branchName}\\nPull request: ${pr.url}" --status New. Return the created work item ID, title, and description.`,
    { agentType: 'zzaia-devops-specialist', schema: WORK_ITEM_SCHEMA, label: 'create-epic' }
  )

  await agent(
    `Use SlashCommand to invoke two separate link commands: (1) /behavior:devops:work-item --action link --id "${workItem.id}" --project "${args.project}" --type "artifact" --link "${branchName}"; (2) /behavior:devops:work-item --action link --id "${workItem.id}" --project "${args.project}" --type "artifact" --link "${pr.url}". This links the documentation branch and pull request as artifacts to the work item.`,
    { agentType: 'zzaia-devops-specialist', label: 'link-artifacts-to-new' }
  )
}

phase('Clarification')
const clarificationQuestions = await agent(
  `Generate critical clarification questions from this architectural context: "${context}". Return a numbered list of 5-10 key questions that must be answered before proceeding with design.`,
  { agentType: 'zzaia-task-clarifier', label: 'generate-questions' }
)

await agent(
  `Use SlashCommand to invoke: /behavior:devops:work-item --action post-discussion --id "${workItem.id}" --project "${args.project}" --message "Clarification Questions:\\n${clarificationQuestions}". Post these clarification questions as a discussion comment on the work item.`,
  { agentType: 'zzaia-devops-specialist', label: 'post-questions' }
)

const clarificationResult = await agent(
  `Use SlashCommand to invoke: /behavior:devops:work-item --action read-discussion --id "${workItem.id}" --project "${args.project}". Poll the work item discussion to check for answers to the clarification questions (the command should help retrieve discussion content). Return all answers found.`,
  { agentType: 'zzaia-devops-specialist', schema: CLARIFICATION_SCHEMA, label: 'poll-answers' }
)

context = `${context}\n\n### Clarification Answers\n${clarificationResult.answers.join('\n')}`

await agent(
  `Use SlashCommand to invoke: /behavior:devops:work-item --action post-discussion --id "${workItem.id}" --project "${args.project}" --message "Phase 4 Clarification is finished with all questions answered.". Post this confirmation as a discussion comment.`,
  { agentType: 'zzaia-devops-specialist', label: 'post-clarification-done' }
)

phase('Behavior Docs')
const userBddContent = await agent(
  `Use SlashCommand to invoke: /behavior:management:business --context "${context}". Generate business-level behavior flows and user scenarios. Output should describe observable user interactions, expected outcomes, and business value.`,
  { agentType: 'zzaia-task-clarifier', label: 'generate-user-bdd' }
)

await agent(
  `Use SlashCommand to invoke: /capability:document:write --template bdd-scenarios --title "${args.description || 'Architecture'} User BDD Scenarios" --context "${userBddContent}" --output docs/user-bdd-scenarios.md. Write user BDD scenarios to the repository.`,
  { agentType: 'zzaia-document-specialist', label: 'write-user-bdd' }
)

const appBddContent = await agent(
  `Use SlashCommand to invoke: /behavior:management:architect --context "${context}". Generate application-level BDD specifications. Output should describe inter-service interactions, API contracts, event flows, and application-level behaviors.`,
  { agentType: 'zzaia-task-clarifier', label: 'generate-app-bdd' }
)

await agent(
  `Use SlashCommand to invoke: /capability:document:write --template bdd-scenarios --title "${args.description || 'Architecture'} Application BDD Specifications" --context "${appBddContent}" --output docs/application-bdd-specifications.md. Write application BDD specifications to the repository.`,
  { agentType: 'zzaia-document-specialist', label: 'write-app-bdd' }
)

await agent(
  `Use SlashCommand to invoke: /behavior:development:git --action commit-push --repository "${args.selectedRepo}" --branch "${branchName}" --message "docs: add behavior documentation (user and application BDD) for ${args.description || 'architecture'}". Commit both BDD documents with the specified message.`,
  { agentType: 'zzaia-developer-specialist', label: 'commit-behavior-docs' }
)

await reviewGate('behavior documentation', pr.url, 'user BDD + application BDD')

await agent(
  `Use SlashCommand to invoke: /behavior:devops:work-item --action post-discussion --id "${workItem.id}" --project "${args.project}" --message "Phase 5 Behavior Documentation is finished with all documents reviewed and approved.". Post this phase completion message.`,
  { agentType: 'zzaia-devops-specialist', label: 'post-behavior-docs-done' }
)

phase('Specification Docs')
const sddContent = await agent(
  `Use SlashCommand to invoke: /behavior:management:architect --context "${context}". Generate complete system architecture and SDD overview. Include bounded contexts, consistency strategies, event flows, and architectural decision records. Consider Domain Driven Design, Clean Architecture, and SOLID principles.`,
  { agentType: 'zzaia-task-clarifier', label: 'generate-sdd' }
)

await agent(
  `Use SlashCommand to invoke: /capability:document:write --template architecture-overview --title "${args.description || 'Architecture'} Architecture" --context "${sddContent}" --output docs/architecture-overview.md. Write the SDD overview to the repository.`,
  { agentType: 'zzaia-document-specialist', label: 'write-sdd' }
)

await agent(
  `Use SlashCommand to invoke: /behavior:development:git --action commit-push --repository "${args.selectedRepo}" --branch "${branchName}" --message "docs: add architecture overview for ${args.description || 'architecture'}". Commit the SDD document.`,
  { agentType: 'zzaia-developer-specialist', label: 'commit-sdd' }
)

await reviewGate('SDD overview', pr.url, 'architecture-overview.md')

await agent(
  `Use SlashCommand to invoke: /behavior:devops:work-item --action post-discussion --id "${workItem.id}" --project "${args.project}" --message "Phase 6 Specification Documentation is finished with the SDD reviewed and approved.". Post this phase completion message.`,
  { agentType: 'zzaia-devops-specialist', label: 'post-sdd-done' }
)

phase('Plan')
const planResult = await agent(
  `Use SlashCommand to invoke: /behavior:management:plan --work-description "${context}". Decompose the architectural design into a parallelizable agile hierarchy of work items. Return a JSON object with an "items" array where each item has: id, title, type, parentId (or null), predecessors (array), successors (array), wave (number), repo, and isLeaf (boolean). Consider parallelization waves and dependencies.`,
  { agentType: 'zzaia-task-clarifier', schema: PLAN_SCHEMA, label: 'generate-plan' }
)

await agent(
  `Use SlashCommand to invoke: /capability:document:write --template implementation-plan --title "${args.description || 'Architecture'} Implementation Plan" --context "${JSON.stringify(planResult)}" --output docs/implementation-plan.md. Write the implementation plan to the repository, describing work items, dependencies, wave assignments, and parallelization strategy.`,
  { agentType: 'zzaia-document-specialist', label: 'write-plan' }
)

await agent(
  `Use SlashCommand to invoke: /behavior:development:git --action commit-push --repository "${args.selectedRepo}" --branch "${branchName}" --message "docs: add implementation plan for ${args.description || 'architecture'}". Commit the implementation plan document.`,
  { agentType: 'zzaia-developer-specialist', label: 'commit-plan' }
)

await reviewGate('implementation plan', pr.url, 'implementation-plan.md')

await agent(
  `Use SlashCommand to invoke: /behavior:devops:work-item --action post-discussion --id "${workItem.id}" --project "${args.project}" --message "Phase 7 Implementation Plan is finished with the plan reviewed and approved.". Post this phase completion message.`,
  { agentType: 'zzaia-devops-specialist', label: 'post-plan-done' }
)

const plan = planResult

phase('Per-Item Docs')
await pipeline(
  plan.items,
  item =>
    agent(
      `For work item "${item.title}" (ID: ${item.id}, Type: ${item.type}), use SlashCommand to generate Specific BDD and Specific SDD documentation:
1. Invoke /capability:document:write --template bdd-scenarios --title "${item.title} Specific BDD" --context "Behavior scoped to this work item from the broader SDD context" --output docs/${item.id}/bdd-specifications.md
2. Invoke /capability:document:write --template service-architecture --title "${item.title} Specific SDD" --context "Architecture and design details for this work item from the broader SDD context" --output docs/${item.id}/service-architecture.md
3. If applicable for this work item type, optionally invoke:
   - /capability:document:write --template service-data-model --title "${item.title} Data Model" --context "Data ownership and consistency for this work item" --output docs/${item.id}/data-model.md
   - /capability:document:write --template event-notification --title "${item.title} Domain Events" --context "Event catalog for this work item" --output docs/${item.id}/domain-events.md
Write documents to hierarchical paths under "docs/" in repository "${args.selectedRepo}" branch "${branchName}". Return a summary of written document paths.`,
      { agentType: 'zzaia-document-specialist', label: `per-item-docs:${item.id}` }
    )
)

await agent(
  `Use SlashCommand to invoke: /behavior:development:git --action commit-push --repository "${args.selectedRepo}" --branch "${branchName}" --message "docs: add work item specifications (specific BDD and SDD) for ${args.description || 'architecture'}". Commit all generated per-work-item documentation files.`,
  { agentType: 'zzaia-developer-specialist', label: 'commit-per-item-docs' }
)

await reviewGate('per-work-item specifications', pr.url, `${plan.items.length} work-item doc sets`)

await agent(
  `Use SlashCommand to invoke: /behavior:devops:work-item --action post-discussion --id "${workItem.id}" --project "${args.project}" --message "Phase 8 Per-Work-Item Documentation is finished with all ${plan.items.length} work-item specification sets reviewed and approved.". Post this phase completion message.`,
  { agentType: 'zzaia-devops-specialist', label: 'post-per-item-docs-done' }
)

phase('Create Work Items')
const createdWorkItems = await pipeline(
  plan.items,
  item =>
    agent(
      `Use SlashCommand to invoke: /behavior:devops:work-item --action create --project "${args.project}" --type "${item.type}" --title "${item.title}" --description "Work Item: ${item.title}\\nBusiness Context: [extracted from SDD]\\nSuccess Criteria: [extracted from SDD]\\nAcceptance Conditions: [extracted from SDD]\\nDependencies: Predecessors: ${item.predecessors || []}, Successors: ${item.successors || []}\\nWave Assignment: Wave ${item.wave}\\nWorking Repository: ${item.repo}\\nDocumentation: docs/${item.id}/\\nReference: For specific BDD and SDD, see docs/${item.id}/" --status New --parent "${item.parentId || workItem.id}". Create the work item with business context and return the created work item ID.`,
      { agentType: 'zzaia-devops-specialist', schema: WORK_ITEM_CREATE_SCHEMA, label: `create-item:${item.id}` }
    ),
  (created, item) =>
    agent(
      `Use SlashCommand to create dependency links and tag for work item "${created.id}" in project "${args.project}":
${item.predecessors && item.predecessors.length > 0 ? item.predecessors.map(pred => `1. /behavior:devops:work-item --action link --id "${created.id}" --project "${args.project}" --type "predecessor" --link-id "${pred}"`).join('\n') : ''}
${item.successors && item.successors.length > 0 ? item.successors.map(succ => `1. /behavior:devops:work-item --action link --id "${created.id}" --project "${args.project}" --type "successor" --link-id "${succ}"`).join('\n') : ''}
And then: /behavior:devops:work-item --action tag --id "${created.id}" --project "${args.project}" --tag "wave-${item.wave}". Link predecessors/successors and assign wave tag.`,
      { agentType: 'zzaia-devops-specialist', label: `link-item:${item.id}` }
    ).then(() => created)
)

await agent(
  `Use SlashCommand to invoke: /behavior:devops:work-item --action post-discussion --id "${workItem.id}" --project "${args.project}" --message "Complete work-item hierarchy created: ${plan.items.length} items with their IDs, types, dependencies, wave assignments, and documentation folder references.". Post a hierarchy summary in the discussion.`,
  { agentType: 'zzaia-devops-specialist', label: 'post-hierarchy-summary' }
)

await reviewGate('created work items', pr.url, 'work item hierarchy')

await agent(
  `Use SlashCommand to invoke: /behavior:devops:work-item --action update --id "${workItem.id}" --project "${args.project}" --state Active. Update the work item to Active state.`,
  { agentType: 'zzaia-devops-specialist', label: 'set-epic-active' }
)

await agent(
  `Use SlashCommand to invoke: /behavior:devops:work-item --action post-discussion --id "${workItem.id}" --project "${args.project}" --message "Phase 9 Create Work Items is finished, the work-item hierarchy is ready, and the Epic is now in Active state ready for implementation.". Post the final phase completion message.`,
  { agentType: 'zzaia-devops-specialist', label: 'post-final-done' }
)

return {
  workItem,
  pr,
  plan: plan.items,
  createdWorkItems: createdWorkItems.filter(Boolean),
}
