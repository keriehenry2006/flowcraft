# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FlowCraft is a web-based Process Flow Management System for visualizing and managing business processes. It's built with vanilla JavaScript, HTML5, and CSS, using Supabase as the backend for authentication, database, and real-time features.

## Architecture

### Technology Stack
- **Frontend**: Vanilla JavaScript (ES6+), HTML5, CSS3
- **Backend**: Supabase (PostgreSQL + Auth + Real-time API)
- **Dependencies**: Supabase JS SDK, Anime.js, SheetJS
- **No build system**: Direct deployment, no compilation required

### Core Components
- **`index.html`** - Main application entry point and project manager
- **`Diagram.html`** - Interactive process flow visualization interface
- **`flowcraft-error-handler.js`** - Universal error handling and utilities library
- **Authentication pages**: `confirm.html`, `reset.html` (Polish UI)
- **Data management**: `import_test_data.html` for imports
- **Testing**: `test_integration.html`, `test_redirect.html`

### Database Schema (3-tier hierarchy)
```
auth.users (Supabase Auth)
  ↓
projects (user-owned containers)
  ↓
sheets (workspaces with custom fields)
  ↓
processes (flow steps with dependencies)
```

All tables use Row-Level Security (RLS) for user data isolation.

## Error Handling Library

The `flowcraft-error-handler.js` provides enterprise-grade error handling:

### Key Functions
- **`executeSupabaseRequest()`** - Supabase requests with timeout and retry logic
- **`showNotification()`** - Toast notification system (success/error/warning/info)
- **`validateEmail/Password/ProcessData()`** - Client-side validation
- **`showLoading/hideLoading()`** - Professional loading states with blur effects
- **`sanitizeInput()`** - XSS protection

### Usage Pattern
```javascript
// Enhanced requests with retry logic
const result = await window.FlowCraftErrorHandler.executeSupabaseRequest(
    () => supabaseClient.from('processes').select('*'),
    { maxRetries: 3, timeout: 10000, loadingMessage: 'Loading processes...' }
);

// Notifications
window.FlowCraftErrorHandler.showNotification('Success!', 'success');
```

## UI/UX Standards

### Design System
- **Theme**: Futuristic 2025 design with dark theme and neon accents
- **Colors**: CSS variables system for consistent theming
- **Typography**: Custom font stack with fallbacks
- **Interactions**: Smooth transitions, hover effects, glass morphism

### Form Validation
- **HTML5 validation attributes** for all inputs
- **Real-time validation** with visual feedback (green/red borders)
- **Pattern validation** for specific fields (process names, times, dependencies)
- **Custom validation messages** for better UX

### Loading States
- **Backdrop blur effects** during operations
- **Button state changes** (e.g., "AUTHENTICATING...")
- **Progress indicators** for long operations
- **Empty states** and error states for data displays

## Development Workflow

### No Build Process
- Edit files directly in the repository
- Test changes by opening HTML files in browser
- Deploy by uploading static files to hosting platform

### Testing
- **Integration tests**: Use `test_integration.html` for form validation and API testing
- **Manual testing**: Open relevant HTML files in browser
- **Database testing**: Use Supabase dashboard for SQL queries

### Common Tasks
- **Add new features**: Extend existing HTML files or create new ones
- **Database changes**: Update `supabase_migrations.sql` and apply via Supabase dashboard
- **UI changes**: Modify CSS in HTML files (styles are inline or embedded)
- **Error handling**: Use the established `FlowCraftErrorHandler` patterns

## Security Considerations

### Input Sanitization
- All user inputs must be sanitized using `sanitizeInput()`
- XSS protection for custom fields and dynamic content
- Validate data on both client and server sides

### Authentication
- Use Supabase Auth for user management
- Check authentication status with `checkAuth()`
- Implement proper session handling

### Database Security
- Row-Level Security (RLS) policies enforce user data isolation
- All queries filtered by `auth.uid()` automatically
- No direct database access from frontend

## Process Management Features

### Process Data Structure
- **Process names**: Uppercase letters, numbers, hyphens, underscores only
- **Working days**: 1-31 for current month, -1 to -31 for previous month
- **Dependencies**: Comma-separated process names
- **Custom fields**: JSONB storage for flexible data

### Validation Rules
- Working day cannot be 0
- Process names must be unique within a sheet
- Dependencies must reference existing processes
- Time format: 24-hour HH:MM

## Language Notes

The application has mixed language support:
- **Code and comments**: English
- **Some UI elements**: Polish (confirm.html, reset.html, FUNKCJONALNOSC_ULEPSZENIA.md)
- **Error messages**: Primarily English with some Polish elements

When adding new features, follow the established language patterns for consistency.