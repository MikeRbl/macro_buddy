# Macrobuddy Design System

## Aesthetic & Theme
- **Style:** Modern Minimalist, Dark Mode First, Liquid Glass (Glassmorphism) accents.
- **Inspiration:** MacroFactor (data-heavy but clean) combined with premium fitness apps.
- **Overall Feel:** Sleek, frictionless, data-driven, and highly legible.

## Color Palette
- **Background:** Deep dark gray/almost black (`#121212` to `#0A0A0A`).
- **Surface/Cards (Liquid Glass):** Semi-transparent white (`rgba(255, 255, 255, 0.05)`) to create depth without solid gray blocks.
- **Borders:** Extremely subtle, 1px translucent borders (`rgba(255, 255, 255, 0.1)`) to define glass edges.
- **Accents (Gradients & Highlights):** 
  - Calories/Energy: Vibrant Coral/Orange (`#FF6B6B` to `#FF8E53`).
  - Workouts/Strength: Electric Teal or Cyan (`#00E5FF`).
  - Body/Weight: Deep Purple (`#B388FF`).
- **Typography:** Pure White (`#FFFFFF`) for primary headers, Light Gray (`#A0A0A0`) for secondary text and labels.

## Typography
- **Font Family:** Inter, Roboto, or system sans-serif.
- **Headers:** Bold, clean, slightly tracked out.
- **Numbers/Data:** Monospaced numerals for macros, weights, and calories so data aligns perfectly vertically.

## Components
- **Cards & Containers:** Rounded corners (`border-radius: 20px`), background blur (backdrop-filter: blur(16px)), subtle inner shadow to simulate glass volume.
- **Buttons:** Pill-shaped (`border-radius: 99px`). Primary buttons use solid accent colors; secondary buttons use glassmorphism.
- **Progress Rings/Bars:** Smooth, rounded caps. Track backgrounds should be very dark, filled with vibrant accent gradients.
- **Bottom Navigation Bar:** Floating pill-shape or seamless dark glass bottom bar. Icons must be minimalist, outlined (not filled unless active).