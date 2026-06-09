# Spec 008: Dashboard

## Overview

Implement a comprehensive dashboard UI for Gaia that displays real-time system status, participant information, and connection monitoring. The dashboard serves as the primary interface when launching the application.

## Objectives

1. Create a unified dashboard layout based on Aither's design patterns
2. Establish design tokens and styling system for Gaia (no third-party UI libraries)
3. Display connection status to critical services (Aither and Hemera)
4. Show participant information with avatars and names
5. Present system health metrics and software version information
6. Provide a "Seminar starten" action button in the header

## Clarifications

### Session 2026-06-06
- Q: What refresh strategy is mandatory for course and participant data from Hemera? -> A: Short-lived cache with revalidation (30-60 seconds).
- Q: How should the dashboard behave when Hemera is unavailable? -> A: Show the last valid cached data and display the warning notice "Daten evtl. veraltet".
- Q: What update strategy applies to connection and system status? -> A: Event-driven updates via SSE push events (no periodic polling).
- Q: How should the dashboard degrade on partial service failures? -> A: Soft-fail; only affected cards show an error while other cards remain usable.
- Q: Who may trigger the "Seminar starten" action? -> A: Authorized role `moderator` only.
- Q: What performance target applies to first usable dashboard view on iPad landscape? -> A: <=2.0 seconds.

## Requirements

### Design & Layout
- Adopt the layout structure from http://localhost:3500 (Aither)
- Extract design information, color schemes, and component patterns from Aither project
- Create Gaia-specific design tokens (colors, typography, spacing, shadows)
- Use only system-inherited styling features (no external UI libraries)
- Ensure responsive and professional appearance for iPad landscape breakpoints (11-inch and 13-inch)

### Dashboard Cards

- Service failures degrade as soft-fail behavior: only affected cards show an error state while unaffected cards remain fully usable.

#### 1. Connection Monitor
- Display connection status to Aither service
- Display connection status to Hemera service
- Use card design and layout patterns from Aither
- Show real-time connection state (connected/disconnected/connecting)
- Update connection and system status event-driven via SSE push events (no periodic polling)
- Include visual indicators (icons/badges) for status

#### 2. Participant Overview
- Display avatar for each participant
- Show participant name
- Responsive grid layout for multiple participants
- Visual consistency with Aither design patterns

#### 3. System Status
- Display health check items
- Show software version information
- Present minimal system metrics in a clear, organized format (software version, service status, last update timestamp)
- Use Aither-inspired card styling

### Navigation & Actions
- Place "Seminar starten" button in the right side of the header
- Allow "Seminar starten" action only for authorized role `moderator`; unauthorized users can see the dashboard but cannot trigger seminar start
- Dashboard loads automatically when launching the application
- Header layout matches Aither design

### Data Fetching from Hemera
- Fetch course data from Hemera on dashboard initialization
- Fetch participant data from Hemera on dashboard initialization
- Display participant names and avatars using fetched data
- Handle loading states while data is being fetched
- If Hemera is unavailable, display the last valid cached course and participant data
- Show a visible warning notice "Daten evtl. veraltet" when fallback cache data is displayed
- Cache fetched course and participant data with a short-lived TTL (30-60 seconds)
- Revalidate cached data after TTL expiration before rendering refreshed dashboard state

### Design Tokens
- Create a centralized design token system for:
  - Color palette
  - Typography scales
  - Spacing system
  - Elevation/shadows
  - Border radiuses
  - Component styles

## Success Criteria

- ✓ Dashboard displays on app launch
- ✓ First usable dashboard view on iPad landscape is rendered within <=2.0 seconds under normal network conditions
- ✓ All three card types (Connection Monitor, Participant Overview, System Status) are rendered
- ✓ Connection status accurately reflects service connectivity
- ✓ Connection and system status updates are delivered event-driven via SSE push events without periodic polling
- ✓ Course and participant data is fetched from Hemera successfully
- ✓ Participant information is displayed with avatars and names from Hemera data
- ✓ System health and version information is visible
- ✓ "Seminar starten" button is positioned in header and navigates authorized users to the existing presentation flow
- ✓ "Seminar starten" can only be triggered by authorized role `moderator`
- ✓ Design tokens are applied consistently across all UI elements
- ✓ UI matches Aither design language and patterns
- ✓ Dashboard uses the same card layout rhythm as Aither with consistent header-to-card and card-to-card spacing defined by dashboard tokens
- ✓ Dashboard applies the same semantic status color mapping as Aither for healthy/degraded/unavailable states
- ✓ Dashboard typography follows the tokenized hierarchy (header, card title, body text) defined for this feature
- ✓ No third-party UI libraries are used
- ✓ Responsive layout works for iPad landscape breakpoints (11-inch and 13-inch)
- ✓ Loading states are displayed while fetching data from Hemera
- ✓ Error states are handled gracefully if Hemera is unavailable
- ✓ Partial service failures apply soft-fail behavior: only impacted cards show errors, while the rest of the dashboard remains usable
- ✓ Hemera course and participant data uses short-lived cache with revalidation every 30-60 seconds
- ✓ If Hemera is unavailable, the dashboard shows last valid cached data and a visible stale-data warning
