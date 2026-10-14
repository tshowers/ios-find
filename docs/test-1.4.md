# Find 1.4 test checklist

Test this on a **real iPhone** (and an **iPad** for the last section) before submitting **1.4 (build 8)**. Most of 1.4 uses Siri, sensors, notifications and system features that the Simulator can't do.

Tick each box as you go. If something fails, write what happened under **Problems found** at the bottom.

---

## Before you start

- [ ] **Backend PR #33 is merged and deployed** (taliferrotech, "keep business locations' coordinates"). Without it, "How far?" never appears.
- [ ] **Web PR #15 is deployed** (find.taliferro.tech), for the web check in section 8.
- [ ] Run the `claude/find-1.4-extensions` branch on your iPhone from Xcode (or install the TestFlight build).
- [ ] **Info** tab says **Version 1.4 (8)**.
- [ ] Start with **"Use my location" off** and **"Adapt to what I'm doing" off** (Info tab).
- [ ] iPhone is on **iOS 18 or later** for the Control Center test (section 3).

---

## 1. Searching and results

### Exact answers
- [ ] `15% of 240` → instant answer card showing **36**.
- [ ] `20% tip on $85 split 3 ways` → tip and per-person split.
- [ ] `days until Christmas` → date math answer.
- [ ] `sunset today` → sunrise/sunset card.
- [ ] `60 mph in km/h` → conversion card; the unit menus offer more than 2 choices.
- [ ] Tap **Conversion** on Home (`100 USD to EUR`) → live currency rate.

### Result pages
- [ ] Any web result shows a short **"why this result"** line (e.g. "Verified business · Top pick of 8").
- [ ] Swipe left and right between results; **Back/Next** buttons work.
- [ ] **All** tab shows the grid of every result.
- [ ] Action tiles appear only when they make sense: **Site / Copy / Save** on web results, plus **Go / Point / Call** on places.
- [ ] **Save** opens Docs' "Save to Knowledge" page with the title and answer filled in.

### Ask about this result
- [ ] On a result, type in **Ask about this result** (e.g. "what are the hours?") → an answer from that page, with a way back.

### News and sports
- [ ] Tap **News** and **Sports** on Home → headline pages with source and "4h ago" times; **Read** opens the article.
- [ ] **Sports** includes **ESPN** and **NPR** stories alongside CBS Sports, BBC Sport, Sky Sports, MLB.com and FOX Sports. Stories without a photo (ESPN, most NPR Sports) come **last**, at most 6. The footer credits every source.
- [ ] **News** includes **NPR** stories, most with a photo.
- [ ] On a network that blocks ESPN or NPR (or a very weak signal), Sports/News still load the other sources with no error.

---

## 2. Location, distances and "How far?"

- [ ] `restaurants near me` → asks for location the first time; results show distances and **Open now / Closed now**.
- [ ] In **All**, the **Open now** button filters nearby results.
- [ ] Info → turn **"Use my location"** on → permission prompt (if not already allowed); now a plain search like `bonhomie coffee` shows distances too. Turn it back **off**.

### "How far?" (the reported bug)
With "Use my location" **off**:
- [ ] Search `bonhomie coffee` → the result shows **2 LOCATIONS** with a **How far?** button and no distances yet.
- [ ] Tap **How far?** → each location gets a distance (e.g. "1.8 mi"), **nearest first**, and the button disappears.
- [ ] Deny location for Find in Settings, try again → a short note says location is off.
- [ ] Swipe to another result and back → the distances still belong to the right business.

### Point
- [ ] On a place result (e.g. `bonhomie coffee`), tap **Point**.
- [ ] A big arrow appears with the distance. Turn slowly in a circle: the arrow keeps pointing at the place.
- [ ] Facing the place → the circle turns **green**, says **Straight ahead**, and you feel a light tap.
- [ ] With 2 locations it points at the **nearest** one and shows its name.
- [ ] **Directions** opens Apple Maps; **Done** closes.
- [ ] Try a single-address place (e.g. `pike place market`) → still points correctly (the address is looked up on the phone).

---

## 3. Siri, Control Center and iPhone search

New Siri phrases can take a minute after install. Opening the app once helps.

### Siri
- [ ] "Hey Siri, **ask Find** how many feet in a mile" → Siri speaks the answer **and shows a card** (label, answer, source).
- [ ] "Hey Siri, **search Find**" → Siri asks "What do you want to find?" → answer it.
- [ ] Ask about a place (e.g. "ask Find bonhomie coffee") → card shows the top result and its website.
- [ ] "Hey Siri, **save that to Knowledge in Find**" → Find opens, then Docs' save page with that answer filled in. Siri says "Saving … to Knowledge."
- [ ] Fresh install (or before ever asking): "save that to Knowledge in Find" → "There's nothing to save yet."

### Control Center / Action button (iOS 18)
- [ ] Control Center → long-press empty space → **Add a Control** → search "Find" → add **Search with Find**.
- [ ] Tap it with Find **closed** → Find opens on a new search with the **keyboard up**.
- [ ] Tap it with Find **open on a result** → same: new search, keyboard up.
- [ ] Add it to the **Lock Screen** and test from there.
- [ ] iPhone 15 Pro or later: Settings → Action Button → Controls → **Search with Find** → press the Action button.
- [ ] Action button → Shortcut → **Ask Find** → press it → Siri asks what to find (voice search).

### Spotlight (iPhone search)
- [ ] Search `bonhomie coffee` in Find. Go Home, swipe down, type **bonhomie** → the Find search appears with its top answer underneath.
- [ ] Tap it → Find opens and runs that search.
- [ ] Watch something (section 4) → it appears in iPhone search as "Watching in Find".
- [ ] History → **Clear** → those searches disappear from iPhone search (can take a few seconds).

---

## 4. Watch a find

- [ ] On a result, tap **Watch** → notification permission is asked the **first** time only → button changes to **Watching**.
- [ ] **History** tab shows a **Watching** list at the top.
- [ ] When a watch changes, a notification arrives and the History tab shows a badge.
- [ ] Tap the notification with Find **closed** → Find opens and runs that search.
- [ ] Remove / renew a watch from the Watching list.

---

## 5. Share, share extension and widget

- [ ] **Share** tab on a result → a `find.taliferro.tech/s/…` link. Send it in Messages → it previews the result.
- [ ] In Safari, select some text → Share → **Find** → Find's answer appears in the sheet.
- [ ] Share a web page from Safari → Find → answer in the sheet.
- [ ] Add the **Find widget** (small and medium) to the Home Screen.
- [ ] Widget search box opens Find on a new search.
- [ ] After a watch changes, the widget shows the latest change; tapping it opens **History**.

---

## 6. Sensors and "Adapt to what I'm doing"

### Tilt navigation (existing)
- [ ] Turn on **tilt navigation** → flick the phone left/right/up/down → moves between results.

### Adapt to what I'm doing
- [ ] Info → turn on **"Adapt to what I'm doing"** → **Motion & Fitness** permission prompt.
- [ ] Deny it → a red note explains how to turn it on in Settings, and the switch stays off.
- [ ] Allow it → switch stays on.
- [ ] **Walking** (walk for a minute first): `bonhomie coffee` → **How far?** → each distance also shows "**x min walk**". Point also shows the walking time.
- [ ] **Driving** (as a **passenger**, never the driver): search something → Find **reads the answer aloud**, music/Maps turn down, and a **"Reading the answer · Stop"** bar shows. **Stop** works.
- [ ] While it's reading, **turn the phone face-down** → it stops.
- [ ] Sitting still → nothing is read aloud.
- [ ] Turn the switch **off** → no more reading aloud.

### Shake
- [ ] On a result page, **shake** the phone → light buzz, results clear, new search with the keyboard up.
- [ ] Shaking while typing does **not** show "Undo Typing".
- [ ] With **tilt navigation on**, shaking does nothing.

---

## 7. Info tab

- [ ] Shows the mission line: *"Our mission is to make search obsolete."* with "Written in 2010. Still the plan." underneath, above the TODD line.
- [ ] "Use my location" and "Adapt to what I'm doing" switches both work (sections 2 and 6).
- [ ] Taliferro links (company, privacy, terms) open.
- [ ] Check in both **Light** and **Dark** mode.

---

## 8. iPad and web

### iPad
- [ ] Home, results, **All** grid and Info look right in portrait and landscape.
- [ ] Siri card, Spotlight, Point (if the iPad has a compass; otherwise it shows the distance and says there's no compass).
- [ ] Share extension and widget.

### Web (find.taliferro.tech)
- [ ] `bonhomie coffee` → **How far?** → browser asks for location → distances, nearest first.
- [ ] About panel shows the mission line.

---

## 9. Before submitting to the App Store

- [ ] Version **1.4**, build **8** in Xcode (all three targets: app, share extension, widget).
- [ ] **App Store Connect privacy label** matches the privacy manifest: coarse location and search history, used for app functionality, not linked to you, no tracking. (Motion & Fitness and Spotlight stay on the phone, so they add nothing.)
- [ ] "What's New" text mentions: Siri answer card and "Save that to Knowledge", Search with Find control, Find in iPhone search, How far?, Point, Adapt to what I'm doing, Watch a find, sharing and the widget.
- [ ] Merge **PR #3**, archive, upload, submit.

---

## Problems found

| Section | What happened | Device / iOS |
|---|---|---|
| | | |
