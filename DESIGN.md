### **Design System: Analytical Elegance**

#### **1\. Visual Theme & Core Philosophy**

This system treats the map and transaction data as the primary hero elements. The interface itself must retreat into the background, operating as a highly tuned, invisible lens for complex financial datasets.

- **The Data-Ink Ratio:** Maximize the screen real estate dedicated directly to data.
- **Cinematic Pacing:** Utilize full-width section layouts to let the product (the map) breathe without structural distraction.
- **Flat Architecture:** The UI is fundamentally flat, communicating hierarchy through crisp border lines and background color grouping, deliberately avoiding skeuomorphism.

#### **\---**

**2\. The Dual-Mode Color System**

The palette strictly separates structural backgrounds, interactive triggers, and data visualization.

**Structural Canvas (Light Mode)**

- **Primary Background:** Light Gray (\#f5f5f7) for the main canvas, preventing the sterility of pure white.
- **Surface Background:** Pure White (\#ffffff) for elevated data cards and transaction lists.
- **Primary Text:** Near Black (\#1d1d1f) for comfortable, long-form reading.
- **Secondary Text & Neutral Elements:** Neutral Gray (\#747780) for muted labels, timestamps, inactive icons, and secondary data points.
- **Structural Lines:** Light Gray (\#E9ECEF) for crisp 1px borders and dividers.

**Structural Canvas (Dark Mode)**

- **Primary Background:** Pure Black (\#000000) for deep, immersive map views.
- **Surface Background:** Dark Surface 1 (\#272729) for transaction cards and bottom sheets.
- **Primary Text:** Pure White (\#ffffff) for maximum contrast.
- **Secondary Text & Neutral Elements:** Neutral Gray (\#747780) for muted labels, timestamps, inactive icons, and secondary data points.
- **Structural Lines:** Dark Border (\#CED4DA adjusted to a low-opacity white, e.g., rgba(255,255,255,0.1)) for subtle sectioning.

**Universal Accent & Data Colors**

- **Interactive Only (Primary):** Apple Blue (\#0071E3) is the _only_ chromatic color allowed for UI interactions, buttons, and focus states.
- **Data Visualization:** Reserved entirely for map markers, charts, and spend categories.
  - Positive/Credit: Energy Green (\#00CC96).
  - Active/Selected (Secondary): Transition Teal (\#00B3E6).
  - Warning/Debit (Tertiary): Commodity Rust (\#C25100).

#### **\---**

**3\. Typography Rules**

The typography blends consumer readability with mathematical alignment.

- **Primary Font Family (Text):** Space Grotesk
  - Apply universal negative letter-spacing (-0.374px to \-0.28px depending on size) for a tightly machined, efficient feel.
  - Use extremely tight line-heights (1.07 to 1.14) for large map overlay headings.
- **Secondary Font Family (Data):** Inter.
  - Any numerical value, financial figure, or coordinate must use monospace tabular lining to ensure perfect vertical decimal alignment in transaction lists.
- **Alignment:** Numerical data must always be right-aligned; standard text is strictly left-aligned.

#### **\---**

**4\. Component Stylings**

| Component                 | Styling Rules                                                                                                                                             |
| :------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Primary Buttons (CTA)** | Background: \#0071E3. Text: \#ffffff. Border-radius: 980px (full pill shape) to create an approachable action.                                            |
| **Secondary Buttons**     | Border-radius: 980px. Background: Transparent. Border: 1px solid \#0071E3. Text: \#0071E3.                                                                |
| **Data Cards**            | Background: Surface Color. Radius: 2px for razor-sharp, institutional edges. Border: 1px solid structural line. Shadow: strictly none.                    |
| **Navigation & Modals**   | Background: Translucent dark rgba(0, 0, 0, 0.8) combined with a heavy glass blur (backdrop-filter: blur(20px)), ensuring it floats cleanly above the map. |
| **Tooltips / Markers**    | This is the _only_ component permitted to use a drop shadow (0px 4px 12px rgba(0,0,0,0.15)) to maintain legibility directly over map elements.            |

#### **\---**

**5\. Layout & Spacing Principles**

- **Edge-to-Edge Maps:** The map canvas should bleed entirely to the edges of the screen, underneath the translucent navigation glass.
- **Vertical Architecture:** Avoid horizontal carousels on mobile; stack transaction data linearly and logically in vertical flows.
- **Whitespace over Lines:** Use generous padding (16px to 24px) inside transaction cards to separate independent datasets mechanically, minimizing the need for heavy visual dividers.
- **Micro-Interactions:** Transitions (like tapping a map marker to reveal the transaction sheet) must be rapid (under 100ms) to ensure immediate data retrieval without a sluggish feel.
