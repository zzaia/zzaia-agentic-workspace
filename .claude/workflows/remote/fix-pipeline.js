export const meta = {
  name: 'workflows:remote:fix-pipeline',
  description: 'Iterative pipeline repair loop until successful completion',
  whenToUse: 'When debugging and fixing pipeline failures across multiple repositories with automated re-run cycles',
  phases: [
    { title: 'Initialize' },
    { title: 'Debug' },
    { title: 'Fix' },
    { title: 'Configure Template' },
    { title: 'Re-run' },
    { title: 'Poll' },
  ]
}

// args: { portal, project, repo, pipeline, branch, targetBranch, deps, workItem, run, maxIterations, description }

const WORKING_SET_SCHEMA = {
  type: 'object',
  properties: {
    workingSet: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          repo: { type: 'string' },
          branch: { type: 'string' },
        },
        required: ['repo', 'branch'],
      },
    },
  },
  required: ['workingSet'],
}

const RUN_TRIGGER_SCHEMA = {
  type: 'object',
  properties: {
    runId: { type: 'string' },
  },
  required: ['runId'],
}

const ISSUE_REPORT_SCHEMA = {
  type: 'object',
  properties: {
    runId: { type: 'string' },
    issues: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          repo: { type: 'string' },
          step: { type: 'string' },
          error: { type: 'string' },
          severity: { type: 'string' },
        },
        required: ['repo', 'step', 'error', 'severity'],
      },
    },
  },
  required: ['runId', 'issues'],
}

const FIX_SUMMARY_SCHEMA = {
  type: 'object',
  properties: {
    repo: { type: 'string' },
    branch: { type: 'string' },
    modifiedFiles: { type: 'array', items: { type: 'string' } },
    commitSha: { type: 'string' },
    prUrl: { type: 'string' },
  },
  required: ['repo', 'branch', 'modifiedFiles', 'commitSha'],
}

const POLL_RESULT_SCHEMA = {
  type: 'object',
  properties: {
    status: { type: 'string', enum: ['Success', 'Failure'] },
  },
  required: ['status'],
}

// Ensure maxIterations defaults to 5
if (!args.maxIterations) {
  args.maxIterations = 5
}

// === PHASE 1: Initialize ===
phase('Initialize')

let workingSet = []

if (args.deps) {
  // Parse comma-separated repo:branch pairs
  const depPairs = args.deps.split(',').map(pair => {
    const [repo, branch] = pair.trim().split(':')
    return { repo, branch }
  })
  workingSet = [
    { repo: args.repo, branch: args.branch },
    ...depPairs,
  ]
} else {
  // Inspect pipeline YAML to extract working set
  const workingSetResult = await agent(
    `Inspect the pipeline YAML for project "${args.project}" and pipeline "${args.pipeline}" (portal: ${args.portal}). Extract all repository references from resources.repositories and extends.repository blocks. For each detected repo, use the ref field value (strip refs/heads/ prefix if present); if no ref field exists, use the primary branch "${args.branch}". Return an array of {repo, branch} objects representing the complete working set. Always include the primary repo ${args.repo} in the set.`,
    { agentType: 'zzaia-devops-specialist', schema: WORKING_SET_SCHEMA, label: 'extract-working-set' }
  )
  workingSet = workingSetResult.workingSet
}

log(`Working set initialized with ${workingSet.length} repo(s): ${workingSet.map(r => r.repo + ':' + r.branch).join(', ')}`)

// Initialize loop state
let iterationCount = 0
let lastIssueSignature = null
let currentRunId = args.run || null
const allFixSummaries = []

// === MAIN LOOP ===
while (true) {
  // === PHASE 2: Debug ===
  phase('Debug')

  const issueReport = await agent(
    `Invoke the SlashCommand tool to run exactly: /behavior:devops:pipeline --action debug --portal ${args.portal} --project ${args.project} --pipeline ${args.pipeline} --branch ${args.branch}${currentRunId ? ` --run ${currentRunId}` : ''}. Capture all failed steps, errors, and warnings from the output. For each failure, identify which repo in this working set owns the affected file: ${JSON.stringify(workingSet)}. Return runId and an issues array (repo, step, error, severity) in the required schema shape.`,
    { agentType: 'zzaia-devops-specialist', schema: ISSUE_REPORT_SCHEMA, label: 'debug-pipeline' }
  )

  currentRunId = issueReport.runId

  if (issueReport.issues.length === 0) {
    log('No issues detected. Pipeline is healthy.')
    return { status: 'success', iterations: iterationCount, fixSummaries: allFixSummaries }
  }

  // Detect repeated errors
  const currentSignature = buildIssueSignature(issueReport.issues)
  if (currentSignature === lastIssueSignature && lastIssueSignature !== null) {
    log(`Same failures recurred in two consecutive iterations. Unresolvable without human intervention.`)
    return { status: 'unresolvable', iterations: iterationCount, issueReport, fixSummaries: allFixSummaries }
  }
  lastIssueSignature = currentSignature

  // === PHASE 3: Fix ===
  phase('Fix')

  // Group issues by repo
  const issuesByRepo = new Map()
  for (const issue of issueReport.issues) {
    if (!issuesByRepo.has(issue.repo)) {
      issuesByRepo.set(issue.repo, [])
    }
    issuesByRepo.get(issue.repo).push(issue)
  }

  // Sort working set to process dependencies first, primary repo last
  const reposWithIssues = Array.from(issuesByRepo.keys())
  const sortedWorkingSet = workingSet.filter(ws => reposWithIssues.includes(ws.repo))
  sortedWorkingSet.sort((a, b) => {
    if (a.repo === args.repo) return 1
    if (b.repo === args.repo) return -1
    return 0
  })

  const fixResults = await pipeline(
    sortedWorkingSet,
    wsRepo => {
      const issues = issuesByRepo.get(wsRepo.repo)
      const issueDescriptions = issues.map(i => `${i.step}: ${i.error}`).join('; ')

      return agent(
        `Invoke the SlashCommand tool to run exactly: /workflow:remote:implement --portal ${args.portal} --project ${args.project} --repo ${wsRepo.repo} --working-branch ${wsRepo.branch} --target-branch ${args.targetBranch || 'main'} --description "Fix pipeline failures: ${issueDescriptions}"${args.workItem ? ` --work-item ${args.workItem}` : ''} --auto-continue. Capture and return the fix summary with modified files list, commit SHA, and PR URL in the required schema shape.`,
        { agentType: 'zzaia-developer-specialist', phase: 'Fix', schema: FIX_SUMMARY_SCHEMA, label: `fix:${wsRepo.repo}` }
      )
    }
  )

  fixResults.forEach(fix => allFixSummaries.push(fix))

  // === PHASE 4: Configure Template ===
  phase('Configure Template')

  // Detect if any dependency repo (non-primary) was changed
  const changedDepRepos = fixResults.filter(fix => fix.repo !== args.repo)

  if (changedDepRepos.length > 0) {
    for (const depFix of changedDepRepos) {
      await agent(
        `Invoke the SlashCommand tool. First, attempt to run: /behavior:devops:pipeline --action update --portal ${args.portal} --project ${args.project} --pipeline ${args.pipeline} --repo ${depFix.repo} --ref refs/heads/${depFix.branch}. If the update succeeds, return success. If it fails because no resources.repositories entry exists for this repo, fall back and invoke: /behavior:devops:pipeline --action create --portal ${args.portal} --project ${args.project} --pipeline ${depFix.repo}-validation --repo ${depFix.repo} --ref refs/heads/${depFix.branch}. Determine which command to invoke based on whether a resources.repositories entry exists for the repo, then execute the appropriate SlashCommand.`,
        { agentType: 'zzaia-devops-specialist', label: `configure:${depFix.repo}` }
      )
    }
    log(`Updated primary pipeline resource references for ${changedDepRepos.length} dependency repo(s).`)
  }

  // === PHASE 5: Re-run ===
  phase('Re-run')

  const runResult = await agent(
    `Invoke the SlashCommand tool to run exactly: /behavior:devops:pipeline --action run --portal ${args.portal} --project ${args.project} --pipeline ${args.pipeline} --branch ${args.branch}. Capture and return the new run ID in the required schema shape.`,
    { agentType: 'zzaia-devops-specialist', schema: RUN_TRIGGER_SCHEMA, label: 'trigger-run' }
  )

  currentRunId = runResult.runId
  log(`New pipeline run triggered: ${currentRunId}`)

  // === PHASE 6: Poll ===
  phase('Poll')

  if (iterationCount === 0) {
    log(`Polling run ${currentRunId} for completion. NOTE: Polling is delegated entirely to the subagent's own tool loop since the dynamic-workflow script layer has no timer/sleep primitives. The agent will check status every ~1 minute until terminal state is reached.`)
  }

  const pollResult = await agent(
    `Poll the pipeline run ${currentRunId} until it reaches a terminal state (Success or Failure). Check status every ~1 minute by invoking the SlashCommand tool to run: /behavior:devops:pipeline --action debug --portal ${args.portal} --project ${args.project} --pipeline ${args.pipeline} --run ${currentRunId}. Repeat this command on each check until the run status is Success or Failure. Return the final status in the required schema shape: 'Success' or 'Failure'.`,
    { agentType: 'zzaia-devops-specialist', schema: POLL_RESULT_SCHEMA, label: 'poll-status' }
  )

  iterationCount++
  log(`Iteration ${iterationCount} complete. Run status: ${pollResult.status}`)

  // === LOOP CONTROL ===
  if (pollResult.status === 'Success') {
    log(`Pipeline succeeded after ${iterationCount} iteration(s).`)
    return { status: 'success', iterations: iterationCount, fixSummaries: allFixSummaries }
  }

  if (iterationCount >= args.maxIterations) {
    log(`Maximum iterations (${args.maxIterations}) reached. Pipeline still failing after all attempts. Human review required.`)
    return { status: 'max-iterations', iterations: iterationCount, fixSummaries: allFixSummaries }
  }

  // Loop back to Phase 2 (Debug) with the new runId
  log(`Looping back to debug phase for iteration ${iterationCount + 1}.`)
}

// === Helper function: build issue signature for repeated-error detection ===
function buildIssueSignature(issues) {
  const triples = issues.map(i => `${i.repo}:${i.step}:${i.error}`)
  triples.sort()
  return triples.join('|')
}
