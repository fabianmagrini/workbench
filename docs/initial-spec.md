# Workbench

## Product Specification v0.1

### Vision

Workbench is a native macOS application for software engineers to orchestrate, monitor, and collaborate with AI coding agents from a single desktop experience.

Rather than replacing the terminal or IDE, Workbench acts as the **control center** for long-running engineering work. It provides visibility into AI agents, background tasks, repositories, prompts, execution history, and approvals while taking advantage of native macOS capabilities.

The design philosophy is inspired by Xcode, Finder, Activity Monitor, and Console: clean, fast, keyboard-first, and optimized for professional developers.

---

# Goals

## Primary Goals

* Native macOS experience
* Beautiful SwiftUI interface
* Fast startup and responsive UI
* Excellent keyboard support
* Multi-window workflow
* First-class support for AI coding agents
* Extensible architecture
* Local-first
* Secure by default

## Non-Goals (Version 1)

* IDE replacement
* Git hosting
* Cloud-based agent execution
* Multi-user collaboration
* Marketplace
* Mobile version

---

# Target Users

### Primary

Professional software engineers using AI coding agents daily.

Examples:

* Claude Code
* Amp
* Codex CLI
* Gemini CLI
* OpenAI Codex
* Local agents

### Secondary

Engineering leaders monitoring long-running automation.

---

# Core Concept

Everything in Workbench revolves around **Workspaces** and **Tasks**.

```
Workspace
    ├── Repository
    ├── Tasks
    ├── Agent Sessions
    ├── History
    └── Settings
```

Each task may launch one or more AI agents.

---

# MVP Features

## Workspace Management

A workspace represents a project.

Properties

* Name
* Repository location
* Git branch
* Preferred agent
* Environment variables
* Tags

Users can:

* Create
* Open
* Pin
* Archive
* Search

---

## Task Management

Tasks represent work given to an agent.

Example

```
Implement JWT refresh flow

Status:
Running

Assigned Agent:
Claude Code

Repository:
/Users/fabian/projects/api
```

Task fields

* Title
* Description
* Prompt
* Repository
* Agent
* Status
* Priority
* Labels
* Created
* Updated

Status

* Draft
* Queued
* Running
* Waiting Approval
* Failed
* Completed
* Cancelled

---

## Agent Sessions

Each execution creates a session.

Tracks

* Logs
* Output
* Files changed
* Runtime
* Cost (future)
* Tokens (future)
* Exit code

---

## Live Console

Streaming output.

Features

* ANSI colors
* Search
* Copy
* Export
* Filter stderr
* Clear

---

## Repository Browser

Simple Finder-like browser.

Supports

* Preview
* Reveal in Finder
* Open in Xcode
* Open in Terminal
* Quick Look

---

## Prompt Editor

Rich editor supporting

* Markdown
* Templates
* Variables
* Prompt history

Future

* Prompt library
* Prompt versioning

---

## History

Timeline of executions.

Allows users to inspect

* previous prompts
* outputs
* execution time
* changed files

---

# macOS Experience

Workbench should feel like a native Mac app.

Use

* NavigationSplitView
* Toolbar
* Sidebar
* Inspector
* Search
* Settings scene
* Commands
* Document Groups (future)

Keyboard shortcuts

⌘N

New Task

⌘R

Run

⌘.

Cancel

⌘F

Search

⌘,

Preferences

---

# Information Architecture

```
Workbench
│
├── Sidebar
│     ├── Workspaces
│     ├── Favorites
│     ├── Recent
│     └── History
│
├── Content
│     ├── Tasks
│     ├── Sessions
│     ├── Files
│     └── Logs
│
└── Inspector
      ├── Details
      ├── Metadata
      ├── Git
      └── Metrics
```

---

# Application Architecture

```
WorkbenchApp
        │
        ▼
AppModel
        │
        ▼
Services
        │
        ├── WorkspaceService
        ├── TaskService
        ├── AgentService
        ├── ProcessService
        ├── GitService
        ├── SettingsService
        └── NotificationService
```

---

# Project Structure

```
Workbench
│
├── App
├── Models
├── Features
│
│   ├── Sidebar
│   ├── Workspace
│   ├── Tasks
│   ├── Sessions
│   ├── Console
│   ├── Files
│   └── Settings
│
├── Services
├── Persistence
├── Utilities
├── Resources
└── Tests
```

---

# Technology Stack

Language

* Swift 6

UI

* SwiftUI

Persistence

* SwiftData

Concurrency

* async/await
* Actors

Packages

* Swift Package Manager

Testing

* XCTest
* Swift Testing

Version Control

* Git

Minimum macOS

* macOS 15+

---

# Data Model

Workspace

```
id
name
repositoryPath
favorite
created
updated
```

Task

```
id
title
prompt
status
priority
workspace
created
updated
```

Session

```
id
task
agent
started
finished
exitCode
status
```

LogEntry

```
id
timestamp
level
message
```

---

# Design Principles

## Native

Use platform controls.

Avoid custom widgets unless necessary.

---

## Keyboard First

Every important action should have a shortcut.

---

## Fast

No unnecessary loading screens.

Instant navigation.

---

## Local First

Data stored locally.

Cloud synchronization can come later.

---

## Extensible

Every agent integration should implement the same protocol.

```
protocol AgentProvider {

    var id: String { get }

    var name: String { get }

    func execute(
        task: Task
    ) async throws -> AgentSession
}
```

---

# Version Roadmap

## Version 0.1

* Workspace management
* Tasks
* SwiftData
* Sidebar
* Native navigation
* Basic settings

---

## Version 0.2

* Process execution
* Streaming logs
* Agent abstraction
* Session history

---

## Version 0.3

* Claude Code support
* Amp support
* Git integration
* Notifications

---

## Version 0.4

* Multiple concurrent agents
* Task queue
* Session comparison
* Prompt templates

---

## Version 1.0

* Polished native UX
* Stable plugin architecture
* Advanced search
* Inspector panels
* Rich execution history
* Excellent performance
* Full keyboard workflow
* Production-ready documentation

---

# Success Criteria

Workbench succeeds when a developer can:

1. Open a repository in seconds.
2. Create an AI task in under 30 seconds.
3. Launch and monitor one or more coding agents.
4. Watch live execution without switching to Terminal.
5. Review changes, logs, and outputs in one place.
6. Keep a searchable history of AI-assisted development work.
7. Feel that Workbench is a natural companion to Xcode and the command line, rather than a replacement for either.

