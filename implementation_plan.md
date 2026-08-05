# Implementation Plan - BookMySpace Home Screen (Stitch Build Loop)

This plan outlines the execution of the **Stitch Build Loop** skill to generate Screen 1 (Home Screen) of **BookMySpace**, closely matching the layout, features, and design tokens of the prototype in [`bookmyspace-app.html`](file:///c:/Users/windows/Desktop/apple/bookmyspace-app.html).

---

## User Review Required

> [!IMPORTANT]
> - The Stitch Loop uses a baton-passing system (`.stitch/next-prompt.md`). Once Screen 1 (Home Screen) is generated and integrated, the baton will be prepared for Screen 2 (`explore` / search & filtering screen).
> - Target Device: `MOBILE` (matching the phone viewport frame in the prototype).

---

## Proposed Changes

### Stitch Infrastructure Setup

#### [NEW] [DESIGN.md](file:///c:/Users/windows/Desktop/apple/.stitch/DESIGN.md)
- Define design tokens, color mode (dark/light themes matching prototype primary `#6c3df4`, dark background `#0d0a24` / card `#ffffff`), typography (`Plus Jakarta Sans`), glassmorphism effects, chip styles, badge colors (`.b-venue`, `.b-class`, `.b-event`, `.b-feat`), and micro-animations.

#### [NEW] [SITE.md](file:///c:/Users/windows/Desktop/apple/.stitch/SITE.md)
- Document the site vision, sitemap (Home, Explore, Detail, Bookings, Profile), and roadmap.

#### [NEW] [next-prompt.md](file:///c:/Users/windows/Desktop/apple/.stitch/next-prompt.md)
- Initialize initial baton for Screen 1:
  - `page: index`
  - Prompt: Detailed prompt requesting mobile home screen for BookMySpace with location bar, greeting, search input, category grid (Venues, Sports, Work, Classes, Parties, Events, Studios, Stays), featured horizontal carousel cards, filter tabs, and venue row cards with ratings & availability badges.

#### [NEW] [metadata.json](file:///c:/Users/windows/Desktop/apple/.stitch/metadata.json)
- Store Stitch project ID, design theme configuration, and screen mappings.

---

### Execution Steps (Stitch Build Loop Workflow)

1. **Stitch Project Initialization**:
   - Call `StitchMCP:create_project` for "BookMySpace Mobile App".
   - Retrieve project details via `StitchMCP:get_project` and save metadata to `.stitch/metadata.json`.

2. **Generate Screen 1 (Home Screen)**:
   - Call `StitchMCP:generate_screen_from_text` using the enhanced prompt from `.stitch/next-prompt.md`.
   - Save generated HTML output to `.stitch/designs/index.html` and preview image to `.stitch/designs/index.png`.

3. **Site Integration & Staging**:
   - Copy/integrate `.stitch/designs/index.html` into `site/public/index.html`.
   - Ensure clean navigation placeholders and styling fidelity matching `bookmyspace-app.html`.

4. **Update Site Documentation & Pass Baton**:
   - Update `.stitch/SITE.md` marking Screen 1 (Home) as completed (`[x]`).
   - Write next task baton to `.stitch/next-prompt.md` with `page: explore` for Screen 2 (Explore & Search Screen).

---

## Verification Plan

### Automated / Tool Verification
- Execute `StitchMCP` tool calls (`create_project`, `generate_screen_from_text`, `get_project`) and verify successful responses.
- Verify file generation for `.stitch/DESIGN.md`, `.stitch/SITE.md`, `.stitch/next-prompt.md`, `.stitch/metadata.json`, `.stitch/designs/index.html`, and `site/public/index.html`.

### Manual Verification
- Inspect generated `index.html` against `bookmyspace-app.html` to confirm matching sections: Location header, greeting, search bar, 8 category tiles, featured horizontal scroll items, and venue row cards.
