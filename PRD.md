# Product Requirement Document (PRD)
## Project: Jinatra Neubrutalist Training App (Android APK)
**Version**: 1.0.0  
**Target Platform**: Android (Standalone APK for F-Droid and direct device installation)  
**Architecture**: LocalStorage-First Offline PWA / Mobile Webview App  
**Design System**: Jinatra Neubrutalist Product System v1.1  

---

## 1. Executive Summary & Product Vision
The goal of this application is to deliver a raw, high-utility, industrial Neubrutalist workout tracking app for Android devices. Unlike standard bloated gym apps, this app starts as a clean slate (custom routines created entirely by the user) and operates completely offline with LocalStorage persistence.

It integrates workout split building, live session execution with set tracking and rest timers, nutrition/calorie tracking, body/BMI metrics logging, and an accountability system for missed workouts—all wrapped in the strict **Jinatra Neubrutalist Product System v1.1**.

---

## 2. Design System & Aesthetics Guidelines

The app must strictly implement **Jinatra Neubrutalist Product System v1.1**:

### Color Palette & Ratios
- **Sweet Cream (`#FFEACF`)**: App canvas background (60% coverage, never pure white).
- **Paper (`#FFFFFF`)**: Card fills and input interiors (20% coverage, always inside an Ink border, never full-bleed).
- **Mist Teal (`#E0F0EE`)**: Secondary surfaces, list item highlights, hover fills.
- **Deep Teal (`#0A756C`)**: Primary action buttons, active navigation states, table/card headers (12% coverage).
- **Ink (`#1A1A1A`)**: Structural element on everything—every border, every shadow, all body text.
- **Signal (`#FF6B35`)**: Warm orange focus rings, warnings, maximum 1 key highlight per view (<3% coverage).

### Typography
- **Headings**: `Archivo` (Grotesque, heavy weight, tight tracking `-2%`, line-height `1.02`).
- **Body & Controls**: `Inter` (Regular/Bold, line length max 68 chars).
- **Data, Tags & Timers**: `JetBrains Mono` (Bold 700, uppercase labels, timers, numbers).

### Structural Rules & Motion
- **Border Radius**: Strictly `0px` across the entire app.
- **Borders**: `3px` solid Ink (`#1A1A1A`) on cards, buttons, inputs; `4px` on modals/heroes; `2px` on internal dividers.
- **Shadows**: Hard offset down-right, zero blur, zero spread (`3px 3px 0 #1A1A1A` for controls, `6px 6px 0 #1A1A1A` for cards, `10px 10px 0 #1A1A1A` for heroes).
- **Press Animation**: On click/tap, elements translate down-right by their shadow offset (`transform: translate(3px, 3px); box-shadow: 0 0 0 #1A1A1A;`) over 60ms.

---

## 3. Screen Hierarchy & Navigation (5-Tab System)

The app utilizes a fixed Neubrutalist Bottom Navigation Bar across 5 main views:

### Tab 1: Routines & Workout Builder (Custom Slate)
- **Clean Slate Start**: No pre-filled routines or default bloat. User builds their splits from scratch.
- **Routine Split Management**: Create, rename, duplicate, and delete custom workout routines (e.g. 5-Day Push/Pull/Legs, Upper/Lower, Full Body).
- **Training Day Editor**:
  - Add/Remove days (e.g., Saturday Push, Monday Legs).
  - Assign custom day tags (e.g. `PUSH`, `LEGS-MODIFIED`).
  - Warm-up list editor (duration, exercise name, repetitions).
  - Exercise list editor: Exercise name, target sets & reps, target weight (kg/lb), notes, YouTube form video URL attachment.
  - Conditioning Finisher list editor (rounds, exercise, work/rest duration).

### Tab 2: Today & Live Workout Mode
- **Active Workout Player**: Real-time mode when executing a training session.
- **Set Completion Tracking**: Checkboxes for each set with instant tactile press feedback.
- **Weight & Rep Logger**: Record actual weight lifted and reps achieved per set.
- **Neubrutalist Rest Timer**:
  - Built-in timer modal/bar (30s, 60s, 90s, custom presets).
  - Large JetBrains Mono digital countdown.
  - Visual Signal highlight ring and audio/vibration alert upon completion.

### Tab 3: Food & Calorie Logger
- **Daily Meal Logger**: Record breakfast, lunch, dinner, snacks, and protein shakes.
- **Nutrient Tracking**: Log total calories, protein (g), carbs (g), and fats (g).
- **Calorie Budget Bar**: Neubrutalist progress bar (`#0A756C` fill inside `#1A1A1A` border) displaying consumed vs. daily target calories.
- **Calories Burned Log**: Manual log for estimated exercise/cardio energy expenditure.

### Tab 4: Body Metrics & BMI Tracker
- **Body Weight Logger**: Log daily/weekly body weight entries with automated timestamps.
- **BMI Calculator**: Real-time BMI calculation based on user height & latest weight entry, displaying standard category status.
- **Metric History Log**: Historical data table with trends.

### Tab 5: Calendar & Accountability Log
- **Training Calendar Grid**: Monthly calendar view highlighting completed workouts (Teal), rest days (Mist), and missed scheduled days (Signal Orange).
- **Streak & Consistency Tracker**: Visual counter tracking consecutive active training weeks.
- **Missed Workout Alerts**: Status badges prompting accountability for missed workout days.
- **Historical Workout Archive**: Tap any calendar date to view the complete log of exercises, sets, weights, and total volume.

---

## 4. Technical Specifications & Storage Architecture

### Offline Storage (LocalStorage Engine)
All data must persist locally without requiring any remote server or cloud account:
- `jinatra_routines`: Collection of user routines, days, exercises, warm-ups, finishers.
- `jinatra_workout_logs`: History of completed workouts, set logs, volume lifted.
- `jinatra_nutrition_logs`: Daily food logs, calorie targets, macro intake.
- `jinatra_body_logs`: Weight history, height setting, calculated BMI records.
- `jinatra_accountability`: Active streak count, missed workout occurrences.

### Backup & Export / Import
- **JSON Export**: Users can export all app data to a `.json` backup file.
- **JSON Import**: Users can restore data from a backup file (critical for F-Droid / offline users changing devices).

---

## 5. Non-Functional Requirements
- **Performance**: 60fps interaction rendering, instantaneous tab transitions (120ms max).
- **Mobile Responsive**: Built specifically for Android viewport dimensions (360px–430px width).
- **Accessibility**: High contrast copy (Ink on Cream 14:1 ratio), focus rings (`3px` Signal outline) on all keyboard/accessible controls.
- **Build Target**: Capacitor/Vite Android APK package ready for F-Droid repository distribution.
