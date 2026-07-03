export const meta = {
  name: 'workflow:analytics:explorate',
  description: 'Comprehensive research workflow for domain, problem, and dataset exploration with optional auto-selection',
  whenToUse: 'Explore viable data science and software engineering problem domains, refine selected domains into technical problems, and discover suitable datasets — with auto-selection fallback when interactive selection is unavailable',
  phases: [
    { title: 'Domain Exploration' },
    { title: 'Problem Refinement' },
    { title: 'Dataset Exploration' },
  ],
}

// args: { domain, description, selectedDomain, selectedProblem, selectedDataset }

const DOMAINS_SCHEMA = {
  type: 'object',
  properties: {
    domains: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          viabilityScore: { type: 'number' },
          description: { type: 'string' },
        },
        required: ['name', 'viabilityScore', 'description'],
      },
    },
  },
  required: ['domains'],
}

const PROBLEMS_SCHEMA = {
  type: 'object',
  properties: {
    problems: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          description: { type: 'string' },
          technicalApproach: { type: 'string' },
        },
        required: ['title', 'description', 'technicalApproach'],
      },
    },
  },
  required: ['problems'],
}

const DATASETS_SCHEMA = {
  type: 'object',
  properties: {
    datasets: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          source: { type: 'string' },
          suitabilityScore: { type: 'number' },
          url: { type: 'string' },
        },
        required: ['name', 'source', 'suitabilityScore', 'url'],
      },
    },
  },
  required: ['datasets'],
}

log(`DESIGN NOTE: This workflow runs non-interactively without a live chat channel. Each phase (Domain Exploration → Problem Refinement → Dataset Exploration) automatically proceeds with args.selectedDomain, args.selectedProblem, or args.selectedDataset if provided, otherwise defaults to the #1 ranked item from that stage's results. The full ranked lists are always returned in the final result, allowing a human to review all options and re-invoke this workflow with explicit selected* overrides if the auto-picked item was not the desired choice.`)

phase('Domain Exploration')

const domainContext = args.domain || args.description || 'commercially viable problems in data science and software engineering'

const domainsResult = await agent(
  `Identify top commercially viable problem domains in data science and software engineering. Context: ${domainContext}. Return a JSON object with a "domains" array, where each domain has: name (string), viabilityScore (0-100 number), and description (string). Rank domains by viability score descending.`,
  { agentType: 'zzaia-domain-exploration', schema: DOMAINS_SCHEMA, label: 'explore-domains' }
)

const chosenDomain = args.selectedDomain
  ? domainsResult.domains.find(d => d.name === args.selectedDomain) || domainsResult.domains[0]
  : domainsResult.domains[0]

log(`Domain Exploration: Selected domain "${chosenDomain.name}" (viability score: ${chosenDomain.viabilityScore})`)

await agent(
  `Write a comprehensive markdown document about the following domain to the file current-domain.md in the appropriate workspace analytics folder. Domain: ${JSON.stringify(chosenDomain)}. Include domain name, commercial viability assessment, key characteristics, and market opportunity.`,
  { agentType: 'zzaia-document-specialist', label: 'write-domain-doc' }
)

phase('Problem Refinement')

const problemContext = `Domain: ${chosenDomain.name}\nDescription: ${chosenDomain.description}`

const problemsResult = await agent(
  `Transform the following domain into comprehensive technical problem definitions with solution approaches. Context: ${problemContext}. Return a JSON object with a "problems" array, where each problem has: title (string), description (string), and technicalApproach (string describing solution methodology). Rank problems by technical feasibility and commercial potential descending.`,
  { agentType: 'zzaia-problem-exploration', schema: PROBLEMS_SCHEMA, label: 'explore-problems' }
)

const chosenProblem = args.selectedProblem
  ? problemsResult.problems.find(p => p.title === args.selectedProblem) || problemsResult.problems[0]
  : problemsResult.problems[0]

log(`Problem Refinement: Selected problem "${chosenProblem.title}"`)

await agent(
  `Write a comprehensive markdown document about the following problem to the file current-problem.md in the appropriate workspace analytics folder. Problem: ${JSON.stringify(chosenProblem)}. Include problem title, detailed description, technical approach, and solution methodology.`,
  { agentType: 'zzaia-document-specialist', label: 'write-problem-doc' }
)

phase('Dataset Exploration')

const datasetContext = `Domain: ${chosenDomain.name}\nProblem: ${chosenProblem.title}\nTechnical Approach: ${chosenProblem.technicalApproach}`

const datasetsResult = await agent(
  `Find and evaluate datasets from UCI Machine Learning Repository, Kaggle, Google Datasets, and Hugging Face suited to the following problem. Context: ${datasetContext}. Return a JSON object with a "datasets" array, where each dataset has: name (string), source (string: UCI|Kaggle|Google|HuggingFace), suitabilityScore (0-100 number), and url (string). Rank datasets by suitability score descending.`,
  { agentType: 'zzaia-dataset-exploration', schema: DATASETS_SCHEMA, label: 'explore-datasets' }
)

const chosenDataset = args.selectedDataset
  ? datasetsResult.datasets.find(d => d.name === args.selectedDataset) || datasetsResult.datasets[0]
  : datasetsResult.datasets[0]

log(`Dataset Exploration: Selected dataset "${chosenDataset.name}" from ${chosenDataset.source} (suitability score: ${chosenDataset.suitabilityScore})`)

await agent(
  `Write a comprehensive markdown document about the following dataset to the file current-dataset.md in the appropriate workspace analytics folder. Dataset: ${JSON.stringify(chosenDataset)}. Include dataset name, source, suitability assessment, and usage considerations.`,
  { agentType: 'zzaia-document-specialist', label: 'write-dataset-doc' }
)

return {
  chosenDomain,
  chosenProblem,
  chosenDataset,
  allDomains: domainsResult.domains,
  allProblems: problemsResult.problems,
  allDatasets: datasetsResult.datasets,
}
