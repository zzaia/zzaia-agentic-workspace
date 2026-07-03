export const meta = {
  name: 'workflows:local:fix-merge',
  description: 'Local-only workflow for resolving merge conflicts — merge from target branch, resolve conflicts, fix post-merge issues, and commit locally without pushing to remote',
  whenToUse: 'Ensure the local worktree/branch exists, merge from a target branch, resolve conflicts, fix any issues that arise, and commit changes locally without any remote interaction',
  phases: [
    { title: 'Setup' },
    { title: 'Merge' },
    { title: 'Review' },
    { title: 'Fix' },
    { title: 'Commit' },
  ],
}

// args: { repo, workingBranch, targetBranch, description }

const CONFLICT_RESOLUTION_SCHEMA = {
  type: 'object',
  properties: {
    resolved: { type: 'boolean' },
  },
  required: ['resolved'],
}

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    issues: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' },
          summary: { type: 'string' },
        },
        required: ['file', 'summary'],
      },
    },
  },
  required: ['issues'],
}

phase('Setup')
await agent(
  `Invoke the SlashCommand tool to run exactly: /behavior:workspace:repo --action new --repo ${args.repo} --branch ${args.workingBranch} --target-branch ${args.targetBranch}. This ensures the local worktree and working branch exist — it is safe to call even if they already exist.`,
  { agentType: 'zzaia-workspace-manager', label: 'ensure-workspace' }
)

phase('Merge')
log('This is a local-only workflow. No remote fetch or pull will occur — the merge will use the target branch\'s current local state as-is.')

await agent(
  `Invoke: SlashCommand("/behavior:development:git --action merge --repo ${args.repo} --branch ${args.workingBranch} --source-branch ${args.targetBranch}"). The command will execute the git merge operation locally.`,
  { agentType: 'zzaia-workspace-manager', label: 'merge-branches' }
)

const conflictResolution = await agent(
  `Resolve all merge conflicts in the working branch '${args.workingBranch}' by examining the context from: ${args.description}. Verify that no unresolved conflicts remain. Return the schema with resolved: true once all conflicts are addressed.`,
  { agentType: 'zzaia-developer-specialist', schema: CONFLICT_RESOLUTION_SCHEMA, label: 'resolve-merge-conflicts' }
)

phase('Review')
const review = await agent(
  `Invoke: SlashCommand("/behavior:development:review --target repo --repo ${args.repo} --branch ${args.workingBranch} --context 'verification of merged related files'"). The command will identify any issues that arose from the merge. Return findings as a structured list with file and summary for each issue in the schema.`,
  { agentType: 'zzaia-workspace-manager', schema: REVIEW_SCHEMA, label: 'review-post-merge' }
)

log('Review complete: this is a local-only workflow without pull request or remote interaction, so no inline comments can be posted — review findings are returned in the workflow result for direct developer action.')

phase('Fix')
if (review.issues.length > 0) {
  const issuesJson = JSON.stringify(review.issues).replace(/'/g, "\\'")
  await agent(
    `Invoke: SlashCommand("/behavior:development:develop --task 'Fix post-merge issues: ${issuesJson}' --repo ${args.repo} --branch ${args.workingBranch}"). The command will apply all fixes to address the identified post-merge issues.`,
    { agentType: 'zzaia-developer-specialist', label: 'fix-post-merge-issues' }
  )
}

const reReview = await agent(
  `Invoke: SlashCommand("/behavior:development:review --target repo --repo ${args.repo} --branch ${args.workingBranch} --context 'verification of post-merge fixes'"). The command will re-run the review to confirm all issues have been resolved. Return findings in the same schema format.`,
  { agentType: 'zzaia-workspace-manager', schema: REVIEW_SCHEMA, label: 'verify-fixes' }
)

phase('Commit')
await agent(
  `Invoke: SlashCommand("/behavior:development:git --action commit --repo ${args.repo} --branch ${args.workingBranch} --message 'fix: resolve post-merge issues'"). The command will create a LOCAL commit only — no push to remote will occur.`,
  { agentType: 'zzaia-workspace-manager', label: 'commit-fixes' }
)

return {
  conflictsResolved: conflictResolution.resolved,
  issuesFound: review.issues,
  verificationReview: reReview.issues,
}
