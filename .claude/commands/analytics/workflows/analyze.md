---
name: /analyze
description: Comprehensive dataset download, visualization, and exploration workflow
version: 1.0
agents:
  - zzaia-notebook-development
---

# Command: /analyze

## Overview
The `/analyze` command provides a structured workflow for dataset analysis, encompassing download, visualization, and exploration phases.

## Workflow Phases

### 0. Dataset Download
- **Agent**: @agent-zzaia-notebook-development
- **Purpose**: Create a Jupyter notebook to download the specified dataset
- **Steps**:
  1. Prompt user for dataset source and specific requirements
  2. Generate notebook with dataset download script
  3. Include error handling and logging for download process
  4. Verify dataset integrity post-download

### 1. Dataset Visualization
- **Agent**: @agent-zzaia-notebook-development
- **Purpose**: Create interactive visualizations of the downloaded dataset
- **Steps**:
  1. Load downloaded dataset
  2. Generate comprehensive exploratory data visualizations
  3. Create interactive plots using libraries like Plotly or Bokeh
  4. Include statistical summaries and distribution insights

### 2. Dataset Exploration
- **Agent**: @agent-zzaia-notebook-development
- **Purpose**: Perform in-depth dataset analysis and feature assessment
- **Steps**:
  1. Analyze dataset characteristics
  2. Identify key features and potential machine learning approaches
  3. Generate feature importance and correlation reports
  4. Prepare dataset for potential machine learning tasks

## Usage
```
/analyse [dataset_name_or_url]
```

## Output
- Jupyter notebook in `workspace/projectName/datasets/scripts/`
- Visualization reports
- Dataset exploration summary

## Considerations
- Requires active internet connection
- Depends on dataset availability from supported sources
- User interaction may be required during the process