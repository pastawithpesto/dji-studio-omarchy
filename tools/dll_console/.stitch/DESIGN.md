---
name: DLL Research Console
colors:
  canvas: "#090f17"
  panel: "#101a27"
  panel-raised: "#142131"
  border: "#233347"
  text: "#e7eef8"
  text-secondary: "#9aabc0"
  accent: "#62d9e8"
  reviewed: "#75d5a3"
  pending: "#f0c477"
  blocked: "#ef8d94"
---

# DLL Research Console design system

## 1. Visual Theme & Atmosphere

The console is a precise, quiet research workbench. A deep navy canvas holds a
blueprint map of DLL work areas. Fine borders, compact text, and soft light define
the surfaces. Cyan marks the current selection. Status colors have fixed meanings.
The interface uses CSS shapes and line icons. It does not need bitmap assets.

This document records the implemented interface. It follows Google's
[Stitch extract-design-md skill](https://github.com/google-labs-code/stitch-skills/blob/main/plugins/stitch-design/skills/extract-design-md/SKILL.md).
The source is `static/style.css`, `static/index.html`, and `static/app.js`.
No live Stitch generation service was used.

## 2. Color Palette & Roles

| Role | Value | Use |
| --- | --- | --- |
| Canvas | `#090f17` | Page background |
| Raised canvas | `#0d1521` | Secondary background |
| Rail | `#0b121c` | DLL catalog |
| Panel | `#101a27` | Primary content surfaces |
| Raised panel | `#142131` | Active and raised surfaces |
| Soft panel | `#111d2a` | Small controls |
| Border | `#233347` | Control and panel boundaries |
| Soft border | `#1a2939` | Separators |
| Primary text | `#e7eef8` | Main labels |
| Secondary text | `#9aabc0` | Supporting labels |
| Dim text | `#72859b` | Low-priority metadata |
| Cyan | `#62d9e8` / `#153947` | Selection, focus, and active state |
| Green | `#75d5a3` / `#17352e` | Recorded approval and online state |
| Amber | `#f0c477` / `#392f20` | Pending work and unknown limits |
| Red | `#ef8d94` / `#39252e` | Blocked work and failure |

Pair each state color with text. Research approval does not imply implemented
code or reference parity. Each work card shows these three states separately.

## 3. Typography Rules

Use the existing sans-serif stack: Inter, ui-sans-serif, system-ui,
-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif. No font download is
required. Use SFMono-Regular, Consolas, Liberation Mono, monospace for hashes,
addresses, and the generated task.

The body is 13px with a 1.45 line height. DLL titles are 19px at weight640.
Panel titles are 13px at weight630. Work card titles are 11px at weight660.
Compact metadata is 8px to10px. Eyebrows use uppercase letters with .12em
spacing. Keep full technical strings in details, even when list labels truncate.

## 4. Component Stylings

Panels use a 12px radius, a one-pixel border, and a dark translucent fill.
Controls use six-pixel to nine-pixel radii. Selected DLL rows have a cyan left
edge. Selected work cards have a clear cyan outline. Each card includes a label,
research state, three phase chips, and an address or missing-work count.

The binary view uses proportional PE section bars. It represents file structure,
not measured research coverage. The export view uses aligned name, ordinal,
address, and forwarder columns. The details panel lists source facts, missing
work, and evidence links. Evidence opens as plain text in a local dialog.

The command drawer groups selection, model, action, and directions on the left.
A read-only generated task fills the right side. The cyan Queue task button is
enabled only after the preview matches the current inputs. Unsupported or
unavailable controls have a visible explanation. Job controls restore keyboard
focus after polling. Focus outlines are two-pixel cyan lines with a two-pixel
offset. Reduced-motion preferences remove animations.

## 5. Layout Principles

The desktop shell has a 68px header, a main workspace, and a 258px command drawer.
It fills the viewport with a minimum height of846px. The main grid row can shrink
to zero, so long DLL lists scroll inside their panel.
The DLL rail is 244px wide. The workspace holds the visual map and a 304px detail
panel. Activity, usage, and workers sit below the map. Internal lists scroll so
the core controls remain easy to locate.

Work cards use one auto-fill grid across all source groups. Each card shows its
group label. The work map has a minimum card width of275px. Major responsive
breakpoints are1680px,1240px,960px, and700px. Wide screens use wider cards.
Medium screens reduce rail and detail widths. Small screens stack panels and
the command drawer. The minimum page width is360px. Keep the map, details, and
command task in a clear reading order.

## 6. Design System Notes for Stitch Generation

Retain the navy and cyan palette, fixed status meanings, and compact research
workbench layout. Use small line icons and CSS shapes. Keep surfaces quiet.
Do not add decorative photographs, large marketing copy, or invented coverage
percentages. The original DLL bytes, reviewed evidence, missing work, and agent
controls must remain the main content. Preserve exact technical names.

Make selected parts and their command preview easy to compare. Preserve visible
keyboard focus, text status labels, responsive stacking, and reduced motion.
Use real source data for every status and usage value. Show unavailable values
as unknown. Never use mock progress as a real research claim.
