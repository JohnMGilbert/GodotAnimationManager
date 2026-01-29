# Godot Animation Manager

A standalone **Godot 4.x** tool for building, previewing, and exporting 2D animation sequences without writing code.  
Designed for artists, designers, and small teams who want a visual, asset-centric workflow that integrates cleanly with Godot projects.

<img width="1511" height="910" alt="Screenshot 2025-12-07 at 12 49 57 PM" src="https://github.com/user-attachments/assets/69f1b52a-7e63-4285-bf4f-74c0de979df7" />

---

## Overview

Godot Animation Manager is a desktop application built with **Godot Engine 4.x** that allows users to:

- Import sprite and audio assets  
- Organize assets with tags and metadata  
- Visually construct animation sequences using a builder grid  
- Preview animations (including audio) in real time  
- Export animations in a format ready to be used inside a Godot project  

The tool is especially suited for **non-programmers** or mixed-discipline teams where artists and designers need to assemble animations independently of game logic.

---

## Key Features

- **Visual Animation Builder**
  - Drag-and-drop sprites and audio into a grid-based sequence editor
  - Reorder and adjust frames without touching code

- **Asset Management**
  - Centralized asset browser for sprites and audio
  - Tagging system for organizing assets
  - Multi-select tagging and bulk tag assignment

- **Preview System**
  - Real-time animation preview
  - Adjustable preview FPS (frames per second)
  - Audio playback synced with animation frames

- **Project Integration**
  - Link projects directly to an existing Godot repository
  - Export animation data for use in Godot scenes

- **Configurable Settings**
  - Grid cell size
  - Preview frame rate
  - Repository path selection

---

## Tech Stack

- **Engine:** Godot Engine 4.x (Mono build)  
- **Language:** GDScript  
- **Target Platform:** Desktop (macOS tested, cross-platform by design)

---

## Getting Started

### Prerequisites

- Godot Engine **4.x (Mono)**  
- A local Godot project (optional, but recommended for export integration)

### Running the Tool

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/godot-animation-manager.git
