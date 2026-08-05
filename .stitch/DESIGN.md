# BookMySpace Design System

## 1. Vision & Concept
BookMySpace is a vibrant, modern mobile application for discovering and booking venues, sports fields, workspaces, fitness classes, and party spaces. The visual aesthetic features sleek glassmorphism, vibrant indigo/purple gradients, pill badges, soft shadows, and clean modern typography.

## 2. Color Palette
- **Primary Gradient**: `linear-gradient(135deg, #7c3aed, #4f46e5)` (Purple to Indigo)
- **Primary Accent**: `#6c3df4`
- **Secondary Accent**: `#4f46e5`
- **Background App**: `#0d0a24` (Dark outer environment background for phone container)
- **Content Background**: `#f4f2fb` (Light violet tint screen background)
- **Card Background**: `#ffffff` (Pure white)
- **Border / Divider**: `#e9e6f5`
- **Text Ink (Primary)**: `#17132b`
- **Text Muted**: `#6f6a8f`

### Status & Category Badges
- **Venue**: `#efe9ff` bg / `#6c3df4` text
- **Class**: `#e0edff` bg / `#1d4ed8` text
- **Event**: `#d9f7ef` bg / `#0f766e` text
- **Featured**: `#fff3d6` bg / `#b45309` text
- **Available**: `#e6f9ee` bg / `#16a34a` text
- **Unavailable**: `#fde8ee` bg / `#e11d48` text

## 3. Typography
- **Font Family**: `'Plus Jakarta Sans', system-ui, -apple-system, sans-serif`
- **Headings**: Extra Bold (800), tracking -0.3px to -0.6px
- **Body**: Medium / SemiBold (500/600), font-size 13px - 14px
- **Small Labels**: Bold / Extra Bold (700/800), 9.5px - 11px uppercase

## 4. UI Components & Layout Guidelines
- **Mobile Container**: 400px fixed width preview or 100% responsive mobile layout with 46px border radius header style.
- **Top Navigation Bar**: Floating glassmorphism bottom navigation (`rgba(255, 255, 255, 0.92)` blur `14px`) with 5 tabs: Home (active), Explore, Bookings, Host, Profile.
- **Header Section**: Location picker ("Bengaluru, KA") with gradient pin icon + Notification bell button with alert badge.
- **Greeting Banner**: "Good evening, Alex ⚡ / What are you planning today?".
- **Search Box**: Rounded 16px white card input field with subtle shadow and search icon.
- **Category Grid**: 4 columns grid featuring 8 tiles with large emojis & bold text:
  1. 🏰 Venues
  2. ⚽ Sports
  3. 💼 Work
  4. 🧘 Classes
  5. 🥳 Parties
  6. 🎟️ Events
  7. 📸 Studios
  8. 🏕️ Stays
- **Featured Horizontal Scroll**: Mini event/venue cards (`min-width: 208px`) with dynamic gradient header thumbnails, date tag, title, rating, and price.
- **Venue Row Cards**: Detailed horizontal item cards with 82x88 rounded gradient image thumbnail, category badge, title, location/distance meta, rating stars, price per hour/day, and green availability chip.

## 5. Design System Block for Stitch Prompts
```text
DESIGN SYSTEM TOKENS:
- Theme: Light Violet Tint (#f4f2fb) with Dark Gradient Accents (#7c3aed to #4f46e5)
- Typography: Plus Jakarta Sans, bold display headings, tracking -0.4px
- Primary Action: Indigo/Purple Gradient (#6c3df4 / #4f46e5) with 15px rounded buttons & soft drop shadow
- Cards: White background (#ffffff) with 1px border (#e9e6f5) and 20px rounded corners
- Badges: Pill-shaped status/category tags with soft tinted backgrounds (.b-venue, .b-class, .b-event, .b-feat, .avail)
- Mobile Viewport: 390px mobile layout with top status bar / dynamic island and bottom floating navigation bar
```
