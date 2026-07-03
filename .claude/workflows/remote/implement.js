export const meta = {
  name: 'workflows:remote:implement',
  description: 'Dynamic-workflow rewrite of workflow:remote:implement.md — orchestrates single-repo implementation from work item through pull request publication',
  whenToUse: 'Implement a work item end-to-end: retrieve requirements, create branch, write documentation, implement with tests, review, fix issues, and publish PR',
  phases: [
    { title: 'Work Item' },
    { title: 'Branch' },
    { title: 'Documentation' },
    { title: 'Implement' },
    { title: 'Commit & PR' },
    { title: 'Review' },
    { title: 'Apply Fixes' },
    { title: 'Publish' },
  ],
}

// args: { workItem, portal: 'azure'|'github', project, repo, targetBranch, workingBranch, description }

const WORK_ITEM_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    description: { type: 'string' },
    type: { type: 'string' },
    acceptanceCriteria: { type: 'array', items: { type: 'string' } },
  },
  required: ['title', 'description', 'type', 'acceptanceCriteria'],
}

const DOCUMENTATION_SCHEMA = {
  type: 'object',
  properties: {
    path: { type: 'string' },
  },
  required: ['path'],
}

const PR_RESULT_SCHEMA = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    url: { type: 'string' },
  },
  required: ['id', 'url'],
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

const CONFLICT_CHECK_SCHEMA = {
  type: 'object',
  properties: {
    hadConflicts: { type: 'boolean' },
  },
  required: ['hadConflicts'],
}

phase('Work Item')
const workItem = await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:devops:work-item --action read --id ${args.workItem} --project ${args.project} --platform ${args.portal}. MANDATORY: for non-Bug types, the description must contain complete SDD documentation with all ADRs — fail loudly if missing. Return title, full description, type, and acceptance criteria.`,
  { agentType: 'zzaia-devops-specialist', schema: WORK_ITEM_SCHEMA, label: 'work-item' }
)

await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:devops:work-item --action update --id ${args.workItem} --project ${args.project} --platform ${args.portal} --state Active. Confirm state is now Active.`,
  { agentType: 'zzaia-devops-specialist', label: 'work-item-activate' }
)

phase('Branch')
await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:workspace:repo --action new --repo ${args.repo} --branch ${args.workingBranch} --target-branch ${args.targetBranch}. Confirm the branch exists and is ready for code changes.`,
  { agentType: 'zzaia-workspace-manager', label: 'feature-branch' }
)

phase('Documentation')
const kebabCase = (str) => str.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '')
const kebabCaseTitle = workItem.type !== 'Bug' ? kebabCase(workItem.title) : null

const documentation = workItem.type !== 'Bug'
  ? await agent(
      `Invoke the SlashCommand tool to run exactly: /capability:document:write --template service-architecture --title "${workItem.title}" --output "./docs/${kebabCaseTitle}.md". Write SDD following existing conventions. Return the path field with the written file location.`,
      { agentType: 'zzaia-document-specialist', schema: DOCUMENTATION_SCHEMA, label: 'sdd-documentation' }
    )
  : { path: null }

phase('Implement')
const taskDescription = documentation.path
  ? `${args.description}\n\nReference SDD: ${documentation.path}`
  : args.description

await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:development:develop --task "${taskDescription}" --repo ${args.repo} --branch ${args.workingBranch}. Acceptance Criteria: ${JSON.stringify(workItem.acceptanceCriteria)}. Implement with comprehensive testing following language-specific standards and architectural patterns.`,
  { agentType: 'zzaia-developer-specialist', label: 'feature-implementation' }
)

phase('Commit & PR')
await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:development:git --action commit-push --repository ${args.repo} --branch ${args.workingBranch} --message "feat: ${args.description} [#${args.workItem}]". Confirm changes are committed and pushed.`,
  { agentType: 'zzaia-workspace-manager', label: 'commit-implementation' }
)

const pr = await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:devops:pull-request --action create --portal ${args.portal} --project ${args.project} --repo ${args.repo} --source-branch ${args.workingBranch} --target-branch ${args.targetBranch} --work-item ${args.workItem} --draft true. Return PR id and full URL.`,
  { agentType: 'zzaia-devops-specialist', schema: PR_RESULT_SCHEMA, label: 'create-draft-pr' }
)

phase('Review')
const review = await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:development:review --target repo --path ./workspace/${args.repo}.worktrees/${args.workingBranch}. Return structured list of issues with file, line number, and summary for each finding.`,
  { agentType: 'zzaia-code-reviewer', schema: REVIEW_SCHEMA, label: 'code-review' }
)

await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:devops:pull-request --action update --portal ${args.portal} --project ${args.project} --repo ${args.repo} --pr ${pr.id} --publish-review true. Post the code review findings as inline PR comments. Issues to post: ${JSON.stringify(review.issues)}`,
  { agentType: 'zzaia-devops-specialist', label: 'post-review-comments' }
)

log(`Review complete: ${review.issues.length} issues found and posted to PR. NOTE: dynamic workflows run non-interactively — there is no manual review confirmation gate here. This script always proceeds automatically to fix all posted issues (if any exist). Human review of the final PR is the real checkpoint.`)

phase('Apply Fixes')
if (review.issues.length > 0) {
  await agent(
    `Invoke the SlashCommand tool to run exactly: /behavior:development:develop --task "Fix all review issues: ${JSON.stringify(review.issues)}" --repo ${args.repo} --branch ${args.workingBranch}. Apply all fixes following the issues list.`,
    { agentType: 'zzaia-developer-specialist', label: 'fix-review-issues' }
  )

  const conflictCheck = await agent(
    `Check for merge conflicts between "${args.workingBranch}" and "${args.targetBranch}" in repo "${args.repo}". If conflicts exist, invoke the SlashCommand tool to run exactly: /workflow:fix-merge --repo ${args.repo} --working-branch ${args.workingBranch} --target-branch ${args.targetBranch}. Return whether conflicts were present and resolved.`,
    { agentType: 'zzaia-developer-specialist', schema: CONFLICT_CHECK_SCHEMA, label: 'check-resolve-conflicts' }
  )

  await agent(
    `Invoke the SlashCommand tool to run exactly: /behavior:development:git --action commit-push --repository ${args.repo} --branch ${args.workingBranch} --message "fix: apply review feedback [#${args.workItem}]". Confirm all fixes are committed and pushed.`,
    { agentType: 'zzaia-workspace-manager', label: 'commit-fixes' }
  )

  await agent(
    `Invoke the SlashCommand tool to run the following commands in sequence:
     1. /behavior:devops:work-item --action update --id ${args.workItem} --project ${args.project} --platform ${args.portal} --description "Updated with review feedback and implementation fixes"
     2. /behavior:devops:work-item --action update --id ${args.workItem} --project ${args.project} --platform ${args.portal} --state Resolved
     Confirm both updates complete.`,
    { agentType: 'zzaia-devops-specialist', label: 'update-workitem-resolved' }
  )

  await agent(
    `Invoke the SlashCommand tool to run exactly: /behavior:devops:pull-request --action comment --portal ${args.portal} --project ${args.project} --repo ${args.repo} --pr ${pr.id} --message "All review issues resolved. Work item description updated to reflect changes." Confirm comment is posted.`,
    { agentType: 'zzaia-devops-specialist', label: 'post-fix-comment' }
  )
}

phase('Publish')
await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:devops:pull-request --action update --portal ${args.portal} --project ${args.project} --repo ${args.repo} --pr ${pr.id} --draft false. Publish PR and confirm it is ready for review.`,
  { agentType: 'zzaia-devops-specialist', label: 'publish-pr' }
)

return {
  workItem,
  pr,
  review,
}
