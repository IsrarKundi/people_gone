"""
PeopleGone Phase 0 Worker Package
Containerized GPU-accelerated image processing pipeline for background person removal.
"""

from .pipeline import process, PipelineConfig

__all__ = ["process", "PipelineConfig"]
