# Research: Controller Design

## Decision 1: Use a split architecture with an iPad controller shell and a Gaia server-side bridge

- Decision: Keep controller models, navigation logic, and Aither integration orchestration in SwiftPM targets, render the coach UI in a dedicated iPad shell, and route all upstream Aither access through a Gaia-managed bridge.
- Rationale: Gaia already owns server-side Aither credentials, and the repository explicitly avoids shipping secret-bearing tokens in a client app bundle.
- Alternatives considered: Direct iPad client calls to Aither; rejected because they would require client-visible credentials or a second interactive auth model that is not part of the clarified scope. Reusing the current authentication HTTP shell as the controller UI; rejected because the feature needs an iPad-optimized presentation controller rather than another server-rendered auth surface.

## Decision 2: Introduce a dedicated controller manifest contract with placeholder-capable supplemental text

- Decision: Define a Gaia controller manifest that returns ordered slides, active slide index, 16:9 aspect-ratio metadata, and supplemental text for the right panel, where that text may come from upstream notes later or from a Gaia-managed placeholder for now. Gaia continues to use the existing HTML slide-view route for raw slide content delivery.
- Rationale: Aither's current `slides/status` and `slides/view` routes do not expose notes or a stable ordered manifest for navigation. A placeholder-capable manifest unblocks the controller implementation without waiting for the final notes domain model.
- Alternatives considered: Blocking implementation until real notes exist; rejected because it delays UI and bridge work unnecessarily. Deriving the deck by scraping file names from status output or output directories; rejected because it couples Gaia to Aither storage internals. Embedding notes inside the HTML payload; rejected because it mixes presentation markup with controller-only data and makes note rendering brittle.

## Decision 3: Render the slide preview in a WebKit-backed 16:9 container bounded to 75% width

- Decision: Use a WebKit-backed HTML viewport constrained to a 16:9 frame and cap that frame at 75% of the iPad width, leaving the remainder for notes and controls.
- Rationale: Aither already renders slides as HTML with a 1920x1080 layout. A WebKit-backed preview preserves that fidelity better than native reimplementation and directly satisfies the clarified ratio constraint.
- Alternatives considered: Rasterizing slides to images; rejected because it would diverge from the live HTML output and complicate future animation or media support. Re-implementing slide layout natively; rejected because it creates a second renderer.

## Decision 4: Prefetch only the active, previous, and next slide HTML documents

- Decision: Gaia prefetches the current slide plus adjacent slides and updates local navigation state only after the bridge acknowledges the active slide change.
- Rationale: Adjacent prefetching is enough to meet the controller responsiveness target for tens of slides while avoiding the memory cost of preloading an entire deck on iPad.
- Alternatives considered: Fetch on every tap with no prefetch; rejected because it risks visible lag. Preload the complete deck; rejected because it increases memory pressure and startup cost without clear benefit for the expected deck size.

## Decision 5: Keep loading and error states explicit and layout-stable

- Decision: Show spinner or skeleton loading states, display inline error messages when manifest or slide payloads fail, and keep button placement and notes panel geometry stable throughout those states.
- Rationale: This matches the clarifications and prevents stale or misleading slide previews while preserving operator confidence during live usage.
- Alternatives considered: Reusing the last successful slide during failure; rejected because it can desynchronize the visible preview from the active slide index. Clearing the entire layout on failure; rejected because it would displace controls and reduce usability.

## Decision 6: Limit navigation to the visible forward and backward buttons

- Decision: Support slide progression only via visible previous and next buttons beneath the viewport.
- Rationale: The clarified scope excludes gestures, hardware keyboard shortcuts, and remote-control input, which simplifies testing and reduces accidental navigation during live coaching.
- Alternatives considered: Swipe gestures and keyboard shortcuts; rejected because they are explicitly out of scope for this feature.