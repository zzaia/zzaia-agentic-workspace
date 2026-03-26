#!/usr/bin/env python3
"""Generate diagram PNG from Mermaid, Graphviz, D2, PlantUML, or Diagrams source using local renderers."""

import shutil
import subprocess
import sys
import tempfile
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

PLANTUML_KEYWORDS = ["@startuml"]

DIAGRAMS_KEYWORDS = ["from diagrams import", "from diagrams."]

RendererType = Literal["mermaid", "graphviz", "d2", "plantuml", "diagrams"]


@dataclass
class DiagramConfig:
    """Configuration for diagram generation."""

    code: str
    output_path: Path
    renderer: RendererType


def detect_renderer(code: str) -> RendererType:
    """Detect diagram renderer from source code syntax.

    Args:
        code: Diagram source code.

    Returns:
        Renderer name: 'mermaid', 'graphviz', 'd2', 'plantuml', or 'diagrams'.
    """
    stripped = code.strip()
    if any(stripped.startswith(kw) for kw in GRAPHVIZ_KEYWORDS):
        return "graphviz"
    if any(stripped.startswith(kw) for kw in PLANTUML_KEYWORDS):
        return "plantuml"
    if any(kw in stripped for kw in DIAGRAMS_KEYWORDS):
        return "diagrams"
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


def render_d2(config: DiagramConfig) -> None:
    """Render D2 diagram to PNG using the d2 CLI.

    Uses ELK layout engine by default for cleaner architecture diagrams.

    Args:
        config: DiagramConfig with D2 code and output path.

    Raises:
        FileNotFoundError: If d2 CLI is not installed.
        RuntimeError: If rendering fails.
    """
    result = subprocess.run(["which", "d2"], capture_output=True)
    if result.returncode != 0:
        raise FileNotFoundError("d2 not installed. Run: curl -fsSL https://d2lang.com/install.sh | sh -s --")
    with tempfile.NamedTemporaryFile(suffix=".d2", mode="w", delete=False) as tmp:
        tmp.write(config.code)
        tmp_path = Path(tmp.name)
    try:
        proc = subprocess.run(
            ["d2", "--layout=elk", "--theme=0", str(tmp_path), str(config.output_path)],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(f"D2 rendering failed: {proc.stderr}")
    finally:
        tmp_path.unlink(missing_ok=True)


def render_diagrams(config: DiagramConfig) -> None:
    """Render diagram using the Python diagrams package (diagrams-as-code).

    Executes the provided Python code in a temporary directory and moves the
    generated PNG to the desired output path. Injects show=False automatically
    to prevent browser opening.

    Args:
        config: DiagramConfig with Python diagrams code and output path.

    Raises:
        FileNotFoundError: If diagrams package is not installed.
        RuntimeError: If rendering fails or no PNG is produced.
    """
    check = subprocess.run(["python3", "-c", "import diagrams"], capture_output=True)
    if check.returncode != 0:
        raise FileNotFoundError("diagrams not installed. Run: pip install diagrams")
    code = config.code
    if "show=" not in code:
        code = code.replace("Diagram(", "Diagram(show=False, ", 1)
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_py = Path(tmp_dir) / "diagram.py"
        tmp_py.write_text(code)
        proc = subprocess.run(
            ["python3", str(tmp_py)],
            capture_output=True,
            text=True,
            cwd=tmp_dir,
        )
        if proc.returncode != 0:
            raise RuntimeError(f"Diagrams rendering failed: {proc.stderr}")
        pngs = list(Path(tmp_dir).glob("*.png"))
        if not pngs:
            raise RuntimeError("No PNG output produced by diagrams execution")
        config.output_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(pngs[0], config.output_path)


def render_plantuml(config: DiagramConfig) -> None:
    """Render PlantUML diagram to PNG using the plantuml CLI.

    Args:
        config: DiagramConfig with PlantUML code and output path.

    Raises:
        FileNotFoundError: If plantuml CLI is not installed.
        RuntimeError: If rendering fails.
    """
    result = subprocess.run(["which", "plantuml"], capture_output=True)
    if result.returncode != 0:
        raise FileNotFoundError("plantuml not installed. Run: sudo apt-get install -y plantuml")
    with tempfile.NamedTemporaryFile(suffix=".puml", mode="w", delete=False) as tmp:
        tmp.write(config.code)
        tmp_path = Path(tmp.name)
    try:
        proc = subprocess.run(
            ["plantuml", "-png", "-o", str(config.output_path.parent), str(tmp_path)],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(f"PlantUML rendering failed: {proc.stderr}")
        generated = tmp_path.parent / (tmp_path.stem + ".png")
        if generated.exists() and generated != config.output_path:
            generated.rename(config.output_path)
    finally:
        tmp_path.unlink(missing_ok=True)


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
    elif config.renderer == "d2":
        render_d2(config)
    elif config.renderer == "plantuml":
        render_plantuml(config)
    elif config.renderer == "diagrams":
        render_diagrams(config)
    else:
        raise ValueError(f"Unsupported renderer: {config.renderer}")
    if not config.output_path.exists():
        raise RuntimeError(f"Output PNG not created: {config.output_path}")


def main() -> None:
    """Main entry point for diagram generation."""
    if len(sys.argv) < 3:
        print("Usage: generate-diagram.py <diagram_code> <output.png> [mermaid|graphviz|d2|plantuml]")
        sys.exit(1)
    code = sys.argv[1]
    output_path = Path(sys.argv[2]).resolve()
    renderer_arg = sys.argv[3] if len(sys.argv) > 3 else None
    renderer: RendererType = renderer_arg if renderer_arg in ("mermaid", "graphviz", "d2", "plantuml", "diagrams") else detect_renderer(code)
    config = DiagramConfig(code=code, output_path=output_path, renderer=renderer)
    try:
        generate(config)
    except (ImportError, RuntimeError, ValueError, FileNotFoundError) as e:
        print(f"Error: {str(e)}")
        sys.exit(1)
    size_kb = output_path.stat().st_size // 1024
    print(f"Diagram generated ({renderer}): {output_path} [{size_kb}KB]")


if __name__ == "__main__":
    main()
