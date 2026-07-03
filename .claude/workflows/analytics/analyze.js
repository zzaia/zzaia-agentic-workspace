export const meta = {
  name: 'workflow:analytics:analyze',
  description: 'Comprehensive dataset download, visualization, and exploration workflow — creates and extends Jupyter notebooks with dataset analysis',
  whenToUse: 'Perform end-to-end dataset analysis: download dataset, create interactive visualizations, and conduct in-depth exploratory analysis with feature assessment',
  phases: [
    { title: 'Download' },
    { title: 'Visualization' },
    { title: 'Exploration' },
  ],
}

// args: { dataset, description }

const DOWNLOAD_SCHEMA = {
  type: 'object',
  properties: {
    notebookPath: { type: 'string' },
  },
  required: ['notebookPath'],
}

const VISUALIZATION_SCHEMA = {
  type: 'object',
  properties: {
    notebookPath: { type: 'string' },
  },
  required: ['notebookPath'],
}

const EXPLORATION_SCHEMA = {
  type: 'object',
  properties: {
    notebookPath: { type: 'string' },
    summary: { type: 'string' },
  },
  required: ['notebookPath', 'summary'],
}

// Helper to derive project name slug from dataset description or URL
function deriveProjectName(datasetOrUrl, description) {
  const source = description || datasetOrUrl || 'dataset'
  return source
    .toLowerCase()
    .replace(/^https?:\/\//, '')
    .replace(/[^\w\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .substring(0, 50)
}

log('AGENT SUBSTITUTION NOTE: Original markdown declares zzaia-notebook-development agent (no longer exists). Using zzaia-developer-specialist for all phases. If a dedicated notebook-development agent is added, update agentType in all agent() calls below.')

phase('Download')
const projectName = deriveProjectName(args.dataset, args.description)
const download = await agent(
  `Create a Jupyter notebook in workspace/${projectName}/datasets/scripts/ that downloads the dataset specified by the user input "${args.dataset}". The notebook should include: (1) dataset download logic with URL handling or API integration as appropriate, (2) error handling and logging for the download process, (3) verification of dataset integrity post-download (file size, checksum, basic schema validation). Return the absolute notebook path in the notebookPath field.`,
  { agentType: 'zzaia-developer-specialist', schema: DOWNLOAD_SCHEMA, label: 'dataset-download' }
)

phase('Visualization')
const visualization = await agent(
  `Extend the Jupyter notebook at ${download.notebookPath} with comprehensive exploratory data visualizations. Load the dataset that was downloaded in the previous step and add: (1) interactive plots using Plotly or Bokeh, (2) statistical summaries (mean, median, std dev, quantiles), (3) distribution insights for each numeric column, (4) correlation heatmaps, (5) categorical value distributions where applicable. Keep the original download code intact and add visualizations as new cells. Return the same notebookPath.`,
  { agentType: 'zzaia-developer-specialist', schema: VISUALIZATION_SCHEMA, label: 'data-visualization' }
)

phase('Exploration')
const exploration = await agent(
  `Further extend the Jupyter notebook at ${visualization.notebookPath} with in-depth dataset analysis. Add: (1) dataset characteristics summary (shape, dtypes, missing values, memory usage), (2) identification of key features and potential machine learning approaches, (3) feature importance analysis if applicable, (4) correlation and multicollinearity reports, (5) data quality assessment and recommendations for data preprocessing. Generate a brief text summary (2-3 sentences) describing the most important findings and dataset readiness for machine learning. Return notebookPath and the summary text.`,
  { agentType: 'zzaia-developer-specialist', schema: EXPLORATION_SCHEMA, label: 'dataset-exploration' }
)

return {
  notebookPath: exploration.notebookPath,
  summary: exploration.summary,
}
