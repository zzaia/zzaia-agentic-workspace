#!/usr/bin/env python3
"""Render LaTeX templates with Jinja2 and compile to PDF using tectonic."""

import json
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional


@dataclass
class RenderConfig:
    """Configuration for LaTeX template rendering."""

    template_path: Path
    output_path: Path
    data: Dict[str, Any]


def validate_inputs(template_path: str, output_path: str) -> RenderConfig:
    """Validate and parse input arguments.

    Args:
        template_path: Path to .tex.j2 template file.
        output_path: Target PDF output path.

    Returns:
        RenderConfig with validated paths.

    Raises:
        FileNotFoundError: If template file does not exist.
        ValueError: If template does not have .tex.j2 extension.
    """
    template = Path(template_path).resolve()
    if not template.exists():
        raise FileNotFoundError(f"Template file not found: {template}")
    if not template.name.endswith(".tex.j2"):
        raise ValueError(f"Template must have .tex.j2 extension, got: {template.name}")
    output = Path(output_path).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    return RenderConfig(template_path=template, output_path=output, data={})


def load_template_data(data_json: Optional[str]) -> Dict[str, Any]:
    """Parse JSON template data.

    Args:
        data_json: JSON string with template variables.

    Returns:
        Dictionary of template variables.

    Raises:
        ValueError: If JSON is invalid.
    """
    if not data_json:
        return {}
    try:
        return json.loads(data_json)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON data: {str(e)}")


def render_template(config: RenderConfig) -> Path:
    """Render Jinja2 template to temporary .tex file.

    Args:
        config: RenderConfig with template and data.

    Returns:
        Path to rendered .tex file.

    Raises:
        ImportError: If jinja2 is not installed.
        RuntimeError: If template rendering fails.
    """
    try:
        from jinja2 import Environment, FileSystemLoader, select_autoescape
    except ImportError:
        raise ImportError("jinja2 not installed. Run: pip install jinja2")
    template_dir = config.template_path.parent
    template_name = config.template_path.name
    env = Environment(
        loader=FileSystemLoader(str(template_dir)),
        autoescape=select_autoescape(enabled_extensions=["tex.j2"]),
    )
    try:
        template = env.get_template(template_name)
        rendered = template.render(**config.data)
    except Exception as e:
        raise RuntimeError(f"Template rendering failed: {str(e)}")
    temp_tex = tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".tex",
        delete=False,
        dir=config.output_path.parent,
    )
    temp_tex.write(rendered)
    temp_tex.close()
    return Path(temp_tex.name)


def compile_latex(tex_file: Path) -> Path:
    """Compile LaTeX .tex file to PDF using tectonic.

    Args:
        tex_file: Path to .tex file.

    Returns:
        Path to compiled PDF file.

    Raises:
        FileNotFoundError: If tectonic is not installed.
        subprocess.CalledProcessError: If compilation fails.
    """
    try:
        result = subprocess.run(
            ["tectonic", str(tex_file)],
            cwd=str(tex_file.parent),
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            raise subprocess.CalledProcessError(
                result.returncode,
                result.args,
                output=result.stdout,
                stderr=result.stderr,
            )
    except FileNotFoundError:
        raise FileNotFoundError("tectonic not found. Install via: snap install tectonic")
    pdf_path = tex_file.with_suffix(".pdf")
    if not pdf_path.exists():
        raise RuntimeError(f"PDF compilation did not produce output: {pdf_path}")
    return pdf_path


def main() -> None:
    """Main entry point for template rendering and PDF compilation."""
    if len(sys.argv) < 3:
        print("Usage: python render-latex.py <template.tex.j2> <output.pdf> [data_json]")
        sys.exit(1)
    template_arg = sys.argv[1]
    output_arg = sys.argv[2]
    data_arg = sys.argv[3] if len(sys.argv) > 3 else None
    try:
        config = validate_inputs(template_arg, output_arg)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {str(e)}")
        sys.exit(1)
    try:
        config.data = load_template_data(data_arg)
    except ValueError as e:
        print(f"Error: {str(e)}")
        sys.exit(1)
    try:
        tex_file = render_template(config)
    except (ImportError, RuntimeError) as e:
        print(f"Error: {str(e)}")
        sys.exit(1)
    try:
        pdf_file = compile_latex(tex_file)
    except (FileNotFoundError, subprocess.CalledProcessError) as e:
        print(f"Error: {str(e)}")
        if isinstance(e, subprocess.CalledProcessError) and e.stderr:
            print(f"Details: {e.stderr}")
        sys.exit(1)
    try:
        shutil.move(str(pdf_file), str(config.output_path))
        tex_file.unlink()
    except Exception as e:
        print(f"Error finalizing output: {str(e)}")
        sys.exit(1)
    print(f"PDF generated: {config.output_path}")


if __name__ == "__main__":
    main()
