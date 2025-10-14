# C4 Architecture Diagrams for Generative AI UI System

## Context Diagram
```mermaid
C4Context
    title System Context Diagram for Generative AI UI System

    Person(developer, "Developer", "Uses web interface to view agent-generated content in real-time")

    System_Boundary(genui_boundary, "Generative AI UI System") {
        System(genui_system, "Generative AI UI", "Real-time web interface for multi-session agent conversations with Linear-inspired design")
    }

    System_Ext(claude_agents, "Claude Code Agents", "Autonomous agents (zzaia-developer, zzaia-tester, zzaia-documentation) generating conversational content")
    SystemDb_Ext(sqlite_cache, "Local SQLite Cache", "Persistent storage for conversation sessions and messages (30-day retention)")

    Rel(developer, genui_system, "Views agent conversations in browser", "HTTPS/WSS (ports 3000)")
    Rel(claude_agents, genui_system, "Publishes content to sessions", "REST API (port 3001)")
    Rel(genui_system, sqlite_cache, "Stores and retrieves session data", "SQLite driver")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Container Diagram
```mermaid
C4Container
    title Container Diagram for Generative AI UI System

    Person(developer, "Developer", "Views agent conversations in web browser")
    System_Ext(claude_agents, "Claude Code Agents", "Publishes conversational content to sessions")

    Container_Boundary(genui_containers, "Generative AI UI System") {
        Container(nextjs_app, "Next.js Web Application", "Next.js 14+, React 18, Tailwind CSS", "Provides Linear-inspired UI with sidebar session list, read-only chat interface, glowing status indicators")

        Container(mcp_server, "MCP Server", "Node.js 20+, Express/Fastify", "Core orchestration: routes requests, transforms markdown to HTML, manages session lifecycle")

        Container(websocket_handler, "WebSocket Handler", "ws/Socket.io", "Manages real-time persistent connections and broadcasts messages to session-specific rooms")

        Container(rest_api, "REST API", "Express/Fastify Routes", "Endpoints: POST /api/publish, GET /api/sessions, GET /api/conversations/{sessionId}")

        Container(transform_engine, "Content Transform Engine", "marked, highlight.js", "Transforms agent markdown to sanitized HTML with syntax highlighting and design system classes")

        ContainerDb(sqlite_cache, "Local Cache", "SQLite", "Tables: sessions, messages, session_metadata | Indexes: sessionId, timestamp | 30-day retention policy")
    }

    Rel(developer, nextjs_app, "Views conversations", "HTTPS (port 3000)")
    Rel(nextjs_app, websocket_handler, "Subscribes to session updates", "WebSocket/WSS")
    Rel(nextjs_app, rest_api, "Fetches session history", "GET /api/sessions, /api/conversations")

    Rel(claude_agents, rest_api, "Publishes content", "POST /api/publish {sessionId, content}")

    Rel(rest_api, mcp_server, "Routes publish requests")
    Rel(mcp_server, transform_engine, "Transforms markdown")
    Rel(transform_engine, mcp_server, "Returns sanitized HTML")
    Rel(mcp_server, sqlite_cache, "Writes messages/sessions", "INSERT")
    Rel(mcp_server, websocket_handler, "Broadcasts to session room")

    Rel(rest_api, sqlite_cache, "Queries session history", "SELECT")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="1")
```

## Deployment Diagram
```mermaid
C4Deployment
    title Deployment Diagram for Generative AI UI System (Local Development)

    Deployment_Node(dev_machine, "Developer Machine", "macOS/Linux/Windows") {
        Deployment_Node(localhost, "Localhost Environment", "127.0.0.1") {

            Deployment_Node(node_runtime_ui, "Node.js Runtime (UI)", "Node.js 20+, Port 3000") {
                Container(nextjs_deployed, "Next.js Web App", "Next.js 14+", "Serves UI and static assets")
            }

            Deployment_Node(node_runtime_mcp, "Node.js Runtime (MCP)", "Node.js 20+, Port 3001") {
                Container(mcp_deployed, "MCP Server", "Express/Fastify + WebSocket", "Handles API and real-time messaging")
            }

            Deployment_Node(filesystem, "File System", ".claude/generative-ui/cache/") {
                ContainerDb(sqlite_deployed, "SQLite Database", "SQLite 3", "genui.db file with sessions and messages")
            }
        }

        Deployment_Node(claude_code, "Claude Code Terminal", "Terminal Process") {
            Container(agents_deployed, "Agent Executors", "Node.js", "zzaia-* agents running tasks")
        }

        Deployment_Node(browser, "Web Browser", "Chrome/Firefox/Safari") {
            Container(browser_app, "Browser Client", "JavaScript/WASM", "Renders UI and WebSocket client")
        }
    }

    Rel(browser_app, nextjs_deployed, "HTTPS", "Views UI")
    Rel(browser_app, mcp_deployed, "WebSocket/WSS", "Real-time updates")
    Rel(agents_deployed, mcp_deployed, "HTTPS POST", "Publishes content")
    Rel(mcp_deployed, sqlite_deployed, "SQLite Driver", "Reads/writes data")
    Rel(nextjs_deployed, mcp_deployed, "Internal", "API proxy")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="2")
```

## Architecture Decision Record (ADR)
1. **WebSocket over HTTP Polling**
   - Real-time updates
   - Low latency
   - Efficient resource utilization

2. **SQLite for Caching**
   - Lightweight
   - Zero-configuration
   - Embedded storage
   - Easy local persistence

3. **Localhost-Only Design**
   - Enhanced security
   - Development-focused architecture
   - Simplified authentication

## Key Integration Points
- Agent → MCP Server: REST Publish
- MCP Server → Frontend: WebSocket Broadcast
- Frontend → SQLite: Session Retrieval

## Performance Targets
- Publish Latency: <100ms
- Concurrent Sessions: 100+
- Message Retention: 30 days
- Virtual Scroll Performance: 1000+ messages

## Security Constraints
- Localhost binding
- Bearer token authentication
- Content sanitization
- No external data exposure