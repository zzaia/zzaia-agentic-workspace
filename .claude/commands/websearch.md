---
name: /websearch
description: Standardized web search protocol for comprehensive information gathering
parameters:
  - name: query
    description: Search query or topic to research
    required: true
  - name: focus
    description: Optional focus area or specific aspect to research
    required: false
---

## PURPOSE

Provide standardized, unified web search protocol for comprehensive information gathering with quality validation and cross-referencing.

## EXECUTION

1. **Search Strategy**
   - Prioritize MCP search tools (Tavily, content extraction)
   - Use built-in WebSearch as fallback
   - Apply WebFetch for specific URLs

2. **Information Gathering**
   - Execute comprehensive web searches
   - Verify current information currency
   - Cross-reference multiple sources

3. **Quality Validation**
   - Assess source credibility and authority
   - Ensure information relevance
   - Document search methodology

## AGENTS

- **general-purpose**: Web search execution, content analysis, and information structuring

## WORKFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant C as /websearch Command
    participant GP as General Purpose Agent
    participant W as Web Sources

    U->>C: /websearch <query> [focus]
    C->>GP: Execute search strategy
    GP->>W: Query multiple sources
    W-->>GP: Search results
    GP->>GP: Validate and cross-reference
    GP->>GP: Structure information
    GP-->>C: Formatted results
    C-->>U: Comprehensive search report
```

## PARAMETERS

- `query`: Search query or research topic
- `focus`: Optional specific aspect or focus area for targeted research

## EXAMPLES

```bash
# General web search
/websearch "latest .NET 8 features"

# Focused research
/websearch "microservices architecture" focus="security best practices"

# Technical documentation
/websearch "Entity Framework Core migrations" focus="production deployment"
```

## OUTPUT

- Comprehensive search results with source attribution
- Information quality assessment and credibility ratings
- Cross-referenced findings from multiple perspectives
- Search methodology documentation
- Structured insights and key takeaways