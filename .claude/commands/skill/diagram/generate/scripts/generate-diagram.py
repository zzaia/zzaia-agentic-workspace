#!/usr/bin/env python3
"""Generate diagram PNG from Mermaid or Graphviz source using local renderers."""

import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

MERMAID_KEYWORDS = [
    "graph ", "flowchart ", "sequenceDiagram", "classDiagram",
    "stateDiagram", "erDiagram", "gantt", "pie ", "pie\n",
    "C4Context", "C4Container", "C4Component", "C4Dynamic",
    "mindmap", "gitgraph", "timeline", "architecture-beta",
    "block-beta", "xychart-beta", "sankey-beta", "quadrantChart",
    "requirementDiagram", "journey",
]

GRAPHVIZ_KEYWORDS = ["digraph ", "graph {", "strict digraph", "strict graph"]


@dataclass
class DiagramConfig:
    """Configuration for diagram generation."""

    code: str
    output_path: Path
    renderer: Literal["mermaid", "graphviz"]


def detect_renderer(code: str) -> Literal["mermaid", "graphviz"]:
    """Detect diagram renderer from source code syntax.

    Args:
        code: Diagram source code.

    Returns:
        Renderer name: 'mermaid' or 'graphviz'.
    """
    stripped = code.strip()
    if any(stripped.startswith(kw) for kw in GRAPHVIZ_KEYWORDS):
        return "graphviz"
    return "mermaid"


def render_mermaid(config: DiagramConfig) -> None:
    """Render Mermaid diagram to PNG using mmdc.

    Args:
        config: DiagramConfig with code and output path.

    Raises:
        ImportError: If mmdc is not installed.
        RuntimeError: If rendering fails.
    """
    try:
        from mmdc import MermaidConverter
    except ImportError:
        raise ImportError("mmdc not installed. Run: pip install mmdc")
    try:
        converter = MermaidConverter()
        converter.to_png(config.code, output_file=config.output_path)
    except Exception as e:
        raise RuntimeError(f"Mermaid rendering failed: {str(e)}")


def render_graphviz(config: DiagramConfig) -> None:
    """Render Graphviz DOT diagram to PNG.

    Args:
        config: DiagramConfig with DOT code and output path.

    Raises:
        ImportError: If graphviz is not installed.
        RuntimeError: If rendering fails.
    """
    try:
        import graphviz
    except ImportError:
        raise ImportError("graphviz not installed. Run: pip install graphviz")
    try:
        source = graphviz.Source(config.code, format="png")
        rendered = Path(
            source.render(
                filename=config.output_path.stem,
                directory=str(config.output_path.parent),
                cleanup=True,
            )
        )
        if rendered != config.output_path and rendered.exists():
            rendered.rename(config.output_path)
    except Exception as e:
        raise RuntimeError(f"Graphviz rendering failed: {str(e)}")


def generate(config: DiagramConfig) -> None:
    """Generate diagram PNG based on renderer type.

    Args:
        config: DiagramConfig with code, output path, and renderer.

    Raises:
        ValueError: If renderer is unsupported.
        RuntimeError: If output PNG was not created.
    """
    config.output_path.parent.mkdir(parents=True, exist_ok=True)
    if config.renderer == "mermaid":
        render_mermaid(config)
    elif config.renderer == "graphviz":
        render_graphviz(config)
    else:
        raise ValueError(f"Unsupported renderer: {config.renderer}")
    if not config.output_path.exists():
        raise RuntimeError(f"Output PNG not created: {config.output_path}")


def main() -> None:
    """Main entry point for diagram generation."""
    if len(sys.argv) < 3:
        print("Usage: generate-diagram.py <diagram_code> <output.png> [mermaid|graphviz]")
        sys.exit(1)
    code = sys.argv[1]
    output_path = Path(sys.argv[2]).resolve()
    renderer_arg = sys.argv[3] if len(sys.argv) > 3 else None
    renderer = renderer_arg if renderer_arg in ("mermaid", "graphviz") else detect_renderer(code)
    config = DiagramConfig(code=code, output_path=output_path, renderer=renderer)
    try:
        generate(config)
    except (ImportError, RuntimeError, ValueError) as e:
        print(f"Error: {str(e)}")
        sys.exit(1)
    size_kb = output_path.stat().st_size // 1024
    print(f"Diagram generated ({renderer}): {output_path} [{size_kb}KB]")


if __name__ == "__main__":
    main()
