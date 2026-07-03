export const meta = {
  name: 'workflows:local:implement',
  description: 'Local-only workflow for iterative development — orchestrates single-repo implementation with branch creation, documentation, implementation, review, and local commit without DevOps portal interaction',
  whenToUse: 'Implement a feature locally: create branch, write documentation, implement with tests, review, fix issues, and commit locally without touching DevOps portals or creating pull requests',
  phases: [
    { title: 'Branch' },
    { title: 'Documentation' },
    { title: 'Implement' },
    { title: 'Review' },
    { title: 'Apply Fixes' },
    { title: 'Commit' },
  ],
}

// args: { repo, workingBranch, targetBranch, description, skipDocumentation? }

const DOCUMENTATION_SCHEMA = {
  type: 'object',
  properties: {
    path: { type: 'string' },
  },
  required: ['path'],
}

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    issues: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          file: { type: 'string' },
          line: { type: 'number' },
          summary: { type: 'string' },
        },
        required: ['id', 'file', 'line', 'summary'],
      },
    },
  },
  required: ['issues'],
}

// Helper to convert description to kebab-case
function toKebabCase(str) {
  return str
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .trim()
}

phase('Branch')
await agent(
  `Invoke: SlashCommand("/behavior:workspace:repo --action new --repo ${args.repo} --branch ${args.workingBranch} --target-branch ${args.targetBranch}"). Confirm the branch exists locally and is ready for code changes.`,
  { agentType: 'zzaia-workspace-manager', label: 'feature-branch' }
)

phase('Documentation')
let docPath = null
if (!args.skipDocumentation) {
  const kebabCaseName = toKebabCase(args.description)
  const documentation = await agent(
    `Invoke: SlashCommand("/capability:document:write service-architecture '${args.description}' --output ./docs/${kebabCaseName}.md"). The command will write Service Design Document (SDD) following existing conventions. Confirm the file path in the result for the 'path' field.`,
    { agentType: 'zzaia-document-specialist', schema: DOCUMENTATION_SCHEMA, label: 'sdd-documentation' }
  )
  docPath = documentation.path
}

phase('Implement')
const taskDescription = docPath
  ? `${args.description}\n\nReference SDD: ${docPath}`
  : args.description

await agent(
  `Invoke: SlashCommand("/behavior:development:develop --task '${taskDescription.replace(/'/g, "\\'")}' --repo ${args.repo} --branch ${args.workingBranch}"). The command will execute full implementation with comprehensive testing, language-specific standards, and architectural patterns.`,
  { agentType: 'zzaia-developer-specialist', label: 'feature-implementation' }
)

phase('Review')
const review = await agent(
  `Invoke: SlashCommand("/behavior:development:review --target repo --repo ${args.repo} --branch ${args.workingBranch}"). The command will review all code changes. Extract findings and return as structured list with file, line number, and summary for each issue in the schema.`,
  { agentType: 'zzaia-code-reviewer', schema: REVIEW_SCHEMA, label: 'code-review' }
)

log(`Review complete: ${review.issues.length} issues found. NOTE: This is a local-only workflow — there is no pull request to post inline comments to. Review findings are returned in the workflow result for the developer to address directly.`)

phase('Apply Fixes')
if (review.issues.length > 0) {
  const issuesJson = JSON.stringify(review.issues).replace(/'/g, "\\'")
  await agent(
    `Invoke: SlashCommand("/behavior:development:develop --task 'Fix all review issues: ${issuesJson}' --repo ${args.repo} --branch ${args.workingBranch}"). The command will apply all review feedback and fixes to the codebase.`,
    { agentType: 'zzaia-developer-specialist', label: 'fix-review-issues' }
  )
}

phase('Commit')
await agent(
  `Invoke: SlashCommand("/behavior:development:git --action commit --repo ${args.repo} --branch ${args.workingBranch} --message 'feat: ${args.description}'"). The command will create a LOCAL commit only without pushing to remote.`,
  { agentType: 'zzaia-workspace-manager', label: 'commit-implementation' }
)

return {
  branch: args.workingBranch,
  docPath,
  review,
}
