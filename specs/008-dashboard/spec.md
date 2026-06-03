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

## Requirements

### Design & Layout
- Adopt the layout structure from http://localhost:3500 (Aither)
- Extract design information, color schemes, and component patterns from Aither project
- Create Gaia-specific design tokens (colors, typography, spacing, shadows)
- Use only system-inherited styling features (no external UI libraries)
- Ensure responsive and professional appearance

### Dashboard Cards

#### 1. Connection Monitor
- Display connection status to Aither service
- Display connection status to Hemera service
- Use card design and layout patterns from Aither
- Show real-time connection state (connected/disconnected/connecting)
- Include visual indicators (icons/badges) for status

#### 2. Participant Overview
- Display avatar for each participant
- Show participant name
- Responsive grid layout for multiple participants
- Visual consistency with Aither design patterns

#### 3. System Status
- Display health check items
- Show software version information
- Present system metrics in a clear, organized format
- Use Aither-inspired card styling

### Navigation & Actions
- Place "Seminar starten" button in the right side of the header
- Dashboard loads automatically when launching the application
- Header layout matches Aither design

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
- ✓ All three card types (Connection Monitor, Participant Overview, System Status) are rendered
- ✓ Connection status accurately reflects service connectivity
- ✓ Participant information is displayed with avatars and names
- ✓ System health and version information is visible
- ✓ "Seminar starten" button is positioned in header and functional
- ✓ Design tokens are applied consistently across all UI elements
- ✓ UI matches Aither design language and patterns
- ✓ No third-party UI libraries are used
- ✓ Responsive layout works across screen sizes
