# Phase 2: HF Browse + Compatibility UI - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-08
**Phase:** 02-hf-browse-compatibility-ui
**Areas discussed:** Browse layout, Search behavior, Model detail view, Recommendations UX

---

## Browse Layout

### List style?
| Option | Description | Selected |
|--------|-------------|----------|
| Compact list rows | Fits many, quick scanning | |
| Cards | Larger, richer detail per model | ✓ |
| You decide | Claude picks | |

**User's choice:** Cards

### Badge style?
| Option | Description | Selected |
|--------|-------------|----------|
| Color dot + label | Green dot "Runs Well" | |
| Pill badge | Colored pill with text | |
| Speed estimate | Show tok/s range | |

**User's choice:** Custom — "Pill badge with estimated tokens per second colored green or yellow"

### Default sort?
| Option | Description | Selected |
|--------|-------------|----------|
| Compatibility first | Runs Well first | ✓ |
| Popularity (HF likes) | Most popular first | |
| You decide | Claude picks | |

**User's choice:** Compatibility first

### Row metadata?
| Option | Description | Selected |
|--------|-------------|----------|
| File size | e.g. "4.2 GB" | ✓ |
| Parameter count | e.g. "7B params" | ✓ |
| Quantization | e.g. "Q4_K_M" | ✓ |
| Download count | HF download stats | ✓ |

**User's choice:** All four

---

## Search Behavior

### Search type?
| Option | Description | Selected |
|--------|-------------|----------|
| Live search | Results update as you type | ✓ |
| Submit search | Tap button to search | |
| You decide | | |

### GGUF filtering?
| Option | Description | Selected |
|--------|-------------|----------|
| Server-side | HF API filters | ✓ |
| Client-side | Fetch all, filter locally | |
| You decide | | |

### Empty state?
| Option | Description | Selected |
|--------|-------------|----------|
| Curated recommendations | Show recs as landing | |
| Search prompt | Clean search bar | |
| You decide | Claude picks | ✓ |

---

## Model Detail View

### Layout?
| Option | Description | Selected |
|--------|-------------|----------|
| Sheet/overlay | Slides up | |
| Full screen push | NavigationStack push | |
| You decide | Claude picks | ✓ |

### Verdict prominence?
| Option | Description | Selected |
|--------|-------------|----------|
| Hero section at top | Large verdict first | |
| Inline with specs | Mixed into spec list | ✓ |
| You decide | | |

### Detail content?
| Option | Description | Selected |
|--------|-------------|----------|
| Model description | HF card excerpt | ✓ |
| GGUF file variants | Per-variant compatibility | ✓ |
| Storage impact | "Uses X GB, you have Y GB" | ✓ |
| Download button | CTA for Phase 3 | ✓ |

---

## Recommendations UX

### Placement?
| Option | Description | Selected |
|--------|-------------|----------|
| Top of browse | Horizontal scroll above list | |
| Separate tab | Own tab | |
| Default landing | Recs ARE the home screen | ✓ |
| You decide | | |

### Source?
| Option | Description | Selected |
|--------|-------------|----------|
| Compatibility + popularity | Algorithmic, always fresh | ✓ |
| Curated list | Hand-picked per chip tier | |
| You decide | | |

### Count?
**User's choice:** 4-6 models

---

## Claude's Discretion

- Navigation pattern for detail view
- Default landing layout
- Empty/loading/error state designs

## Deferred Ideas

None
