<div align="center">
  <img src="AppIcon.png" alt="DragScroll Logo" width="128" height="128">
  <h1>DragScroll for macOS</h1>
  <p><strong>The minimal, long-term mouse panning fix for Mac users</strong></p>
  
  <p>
    <a href="https://github.com/RashminDungrani/drag-scroll-mac/releases"><img src="https://img.shields.io/github/v/release/RashminDungrani/drag-scroll-mac?style=flat-square" alt="Release"></a>
    <a href="https://github.com/RashminDungrani/drag-scroll-mac/blob/main/LICENSE"><img src="https://img.shields.io/github/license/RashminDungrani/drag-scroll-mac?style=flat-square" alt="License"></a>
    <img src="https://img.shields.io/badge/macOS-11.0%2B-000000?style=flat-square&logo=apple" alt="macOS 11.0+">
    <img src="https://img.shields.io/badge/Language-Swift-F05138?style=flat-square&logo=swift" alt="Swift">
  </p>
</div>

---

## 🖱️ The Problem: The Mac Mouse Experience
If you've ever used a standard (non-Magic) mouse on a Mac, you probably noticed a glaring issue: **panning and scrolling feel clunky**. While macOS is highly optimized for trackpad gestures, standard mice with scroll wheels lack a native, smooth, multi-directional drag-to-scroll feature (like pressing the middle-click on Windows).

## ✨ The Solution: DragScroll
**DragScroll** is a minimal, native macOS utility written in Swift that fixes this. It allows you to **hold a designated mouse button (default: Button 5) and drag your mouse to seamlessly scroll and pan** in any application. 

It translates your physical mouse movements directly into buttery-smooth native scrolling events, making navigating large documents, web pages, and design canvases an absolute joy. It is designed to be a set-and-forget, long-term solution with an incredibly tiny footprint.

---

## 🚀 Features
- **Global Panning:** Works seamlessly across all your Mac applications.
- **Ultra-Minimal:** Runs in the background, native Swift, no heavy frameworks, taking minimal CPU/RAM.
- **Menu Bar Integration:** A sleek, unobtrusive `⇕` icon in your menu bar to quickly tweak settings.
- **Persistent Configuration:** Remembers your settings across reboots via macOS `UserDefaults`.
- **Advanced Momentum:** Physics-based momentum engine keeps your canvas gliding even after you let go.

---

## 📥 Installation

### Option 1: Download Pre-built Release (Recommended)
1. Go to the [Releases page](../../releases) (replace with actual link).
2. Download the latest `DragScroll.zip`.
3. Unzip the file and drag `DragScroll.app` into your `/Applications` folder.
4. Launch `DragScroll` from your Applications folder or Launchpad.

### Option 2: Build from Source
```bash
git clone https://github.com/RashminDungrani/drag-scroll-mac.git
cd DragScroll
./build.sh
```
The script will automatically compile the Swift code, create a `.app` bundle, generate the icon, and install it to your `/Applications` folder.

---

## 🔒 Permissions
Because DragScroll needs to read your mouse clicks and synthesize scrolling events globally, macOS requires you to grant it **Accessibility** permissions.

Upon first launch, macOS will prompt you. If it doesn't:
1. Open **System Settings** > **Privacy & Security** > **Accessibility**.
2. Click the `+` button and add `DragScroll.app`.
3. Ensure the toggle next to DragScroll is turned **ON**.

---

## 🛠️ Usage & Configuration
DragScroll comes with a menu bar icon (`⇕`) where you can easily toggle:
- Scroll Speed (Slow, Medium, Fast)
- Smoothness (Snappy to Ultra Smooth)
- Reverse Scroll Direction

### Advanced CLI Configuration
For power users who prefer minimal setups, all settings are saved to macOS `UserDefaults`. You can configure DragScroll via the terminal without even touching the menu bar!

**Change the trigger mouse button:**
By default, DragScroll uses Mouse Button 5 (index `4`). To change it to middle-click (`2`), or another side button (`3`), run:
```bash
defaults write com.dragscroll.app button -int 2
```
*(Note: Button 0 is left-click, Button 1 is right-click. Do not use those!)*

**Change speed, smoothness, or reverse direction:**
```bash
defaults write com.dragscroll.app speed -float 4.0
defaults write com.dragscroll.app smoothness -float 0.45
defaults write com.dragscroll.app reverse -bool true
```

*You will need to restart DragScroll for CLI changes to take effect.*

---

## 💡 Contributing & Feature Requests
DragScroll is designed to be minimal. However, if you have ideas that fit a lightweight philosophy (e.g., modifier key support):

1. **Fork** this repository.
2. Create a **Feature Branch** (`git checkout -b feature/AmazingFeature`).
3. **Commit** your changes (`git commit -m 'Add some AmazingFeature'`).
4. **Push** to the branch (`git push origin feature/AmazingFeature`).
5. Open a **Pull Request**.

If you have suggestions or bug reports, please open an issue!

## 📜 License
Distributed under the MIT License. See `LICENSE` for more information.
