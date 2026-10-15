# Animation for PeopleGone — Research and Plan

**For:** the owner. **Written by:** the UI/UX design lead, 2026-10-15.
**In one line:** a small number of calm, useful animations — each one either teaches the user something, confirms something, or shows that something changed. Nothing that only decorates. Nothing that lies.

Words I use, in plain words:

- **Micro-interaction** — a tiny movement after you tap something. Example: a button dips a little when you press it, so your finger feels an answer.
- **Crossfade** — one thing fades out while the next fades in, in the same place.
- **Spring** — a movement that settles like a real object, smooth at the end, instead of moving like a robot at one speed. Both Google and Apple now build movement this way.
- **Shared element** — a photo that grows from a small square into the full screen, so you see it is the same photo. Google Photos and Apple Photos do this when you tap a photo.
- **Haptic** — a tiny vibration from the phone, like a soft click you feel, not hear.
- **Reduced motion** — a phone setting for people who get dizzy or sick from screen movement. The app must respect it: less movement, or none.

---

## 1. What the newest design world says (2026)

I read the 2026 trend reports and the two phone systems' own design rules. The short version:

1. **The big shift of 2026: animation must have a job.** The trend writers (UX Pilot's 2026 mobile trends; this year's UI/UX trend round-ups) all say the same thing — small animations are now used to *confirm, guide, and explain*, not to decorate. Movement with no job is the new bad taste. It is what people now call slop.
2. **Google's newest system (Material 3 Expressive, now the Android default) uses springs for everything.** Buttons change shape a little when pressed. Things settle instead of stopping dead. But note: Google's own rules keep the bouncy, playful springs for small fun parts. Serious apps use the calm version — smooth, no visible bounce. Critics already call the bouncy version childish for work apps. We take the calm version.
3. **Apple's rules for iOS 26 say the same in different words:** movement should be *purposeful* (it tells you something), *short*, *reversible* (the way a screen comes in is the way it goes back), and *never block the user* — you can always tap during an animation. Also: do not animate things people touch fifty times a day more than a little.
4. **Both systems demand respect for reduced motion.** In 2026 this is not extra credit. It is the baseline.
5. **The photo-app pattern that never died: the shared-element grow.** Tap a photo in Google Photos or Apple Photos and it grows into the full screen. Users read it instantly: *same photo, now bigger.* It is the most useful animation a photo app can have.

So the plan below is not "add the trendy things." It is: take the few movements that do real work in a photo app, in the calm form both Google and Apple now recommend, and refuse the rest.

## 2. The rules every animation here must pass

1. **It must say something true.** A movement can show a change, confirm a tap, or teach a gesture. It can never fake work. (Example of a lie we will not ship: a line that pretends the server is finding people one by one, when the answer arrived all at once.)
2. **It must be short.** Feedback: under 0.2 seconds. Screen changes: under 0.35 seconds. Only two slow moments are allowed in the whole app, and both are named below.
3. **It must never block.** The user can tap again at any time. No animation is a waiting room.
4. **It must be cheap.** We animate only size-by-transform and fade — the two things phones do almost for free. The three places that move real photos are flagged, with the fix, in §4.
5. **Reduced motion turns it down or off.** Movement becomes a short fade or an instant change. Teaching movements (below) never run at all.
6. **No celebration, no confetti, no sparkles.** Settled by the owner before, and it stays settled. A check mark that quietly confirms "saved" is fine — it is a receipt, not a party.

## 3. Screen by screen — what to add, and what to keep away

### Everywhere
- **One screen-change style for the whole app.** Screens fade in with a very small slide, about 0.25 seconds, always the same. Going back reverses it. *Why it feels good:* your brain stops re-learning where it is. *Example:* opening Settings feels like opening History — same movement, same speed.
- **Buttons and chips dip when pressed.** A tiny shrink (to 98%) and a spring back. *Why:* every tap gets an answer. This is the single cheapest "this app feels made, not generated" signal there is.
- **A tiny haptic tick on the big confirmations only** — tapping a person on the review screen, pressing the big Remove button, a save finishing. Not on every tap. *Cost:* none. *Why:* your finger believes the tap landed before your eyes check.

### Home
- **The demo card teaches itself, once.** The first time the demo card shows in a session, its before/after handle slides slowly to one side and back to the middle, one time, about a second. Then it never moves on its own again, and any touch stops it. *Practical example:* a new user who never touched the handle now knows it drags — no text needed. With reduced motion on, it never moves.
- **The job banner arrives like news.** When a background clean finishes, the banner slides down and fades in at the top of Home, and its icon changes to the green check. *Why:* the change of state is the message; the movement says "look here, something finished" exactly once.
- **History on Home appears as one calm block** — a single fade-in when it first loads. No per-photo parade. A line of photos dancing in one by one is the most copied template look there is; we refuse it.
- **Keep away:** counting-up numbers on the saves line (it pretends data is arriving; nothing is), any movement on the wordmark, a looping demo that slides forever (it becomes wallpaper, and drains attention and battery).

### The pick flow
- **The picked photo grows into the next screen.** After the system picker, your photo expands smoothly into the analysing screen — the shared-element grow. *Why:* it teaches the whole app's idea in one second — *this photo goes in, this photo comes back clean.* This is the one "wow" moment we allow ourselves, and it is also information.
- **Cost flag (honest):** flying a full-resolution photo can stutter on mid-range phones. The fix is standard: fly a smaller copy made for the screen, swap in the full photo when it lands. If it still cannot stay smooth, we fall back to the plain fade — feel never beats smoothness.

### Review screen (S4 Proposal)
- **The results arrive in one beat.** When the server's answer comes back, all outlines on the photo and all the person cards fade in together, fast. *Why one beat:* the answer truly arrived all at once. Animating people in one-by-one would be theatre lying about how the app works.
- **Tapping a person feels physical.** Tap a person (or their card): the outline colour melts from red to green (or back), the card's ring and its Remove/Keep word change with a tiny spring, and the sentence at the top calmly crossfades to the new count. *Practical example:* you tap three people off, and the sentence quietly walks from "5 people will be removed" to "2 people will be removed" — you trust the count because you watched it change. This is the most-touched interaction in the app, so it stays under 0.2 seconds and can be interrupted mid-way — tap fast, it keeps up.
- **Keep away:** outlines that "draw themselves" like a pen tracing (slow, and it pretends the app is drawing live), cards that fly in from the photo, any bounce.

### Processing
- **Stage words crossfade when the real stage changes.** "Connecting…" fades into "Uploading… 40%", which fades into "Finding people and removing them…" — only when the real state changes, because that is what a crossfade is *for*: showing a change. About 0.2 seconds.
- **The thin light beam stays exactly as it is** — it is already ruled: it means "working", it never means a percentage. With reduced motion on, it stops moving and becomes a still line.
- **Keep away:** numbers that glide upward between real values (a percentage may only ever show what the bytes have truly done — the moment it glides ahead of the truth, it is a lie with good manners), spinning logos, a photo that slowly zooms while waiting (it pretends something is happening to the photo; nothing is), anything timed by a clock instead of by events.

### Result
- **The payoff: one slow dissolve from Before to After.** The first time a result opens, the original photo melts into the cleaned photo, about half a second, one time. *Practical example:* you watch the crowd leave the photo. It is the product's whole promise, shown once, honestly — both pictures are the real pictures. After that, the hold-to-compare and the slider are yours, manual, as now. Never loops.
- **Cost flag:** same as the pick flow — dissolve smaller screen copies, not the full files.
- **Save gives a receipt, not a party.** When a save finishes, the Save button quietly changes into a check with the word "Saved" for about a second, then settles back. Plus the haptic tick. No bounce, no confetti — a receipt.
- **The compare handle teaches itself once.** First time on a result, the handle nudges a short way and comes back, once. Same teaching idea as the demo card. Then never again.
- **Keep away:** the before/after playing by itself in a loop (it turns your photo into an advert), any glow or shine sweep over the result.

### Brush (Touch up)
- **Undo shows what it undid.** Press Undo and the removed stroke fades out in about 0.15 seconds instead of vanishing. You see exactly which stroke left. Clear fades all strokes together, same idea.
- **The reflection guide outline fades in** when Brush opens from the reflection warning — new information arriving gets a small arrival. The outline itself stays still after that: a moving dashed line marching around it forever is an old editor cliché and a small, endless cost.
- **The brush-size dot grows and shrinks smoothly** as you move the size slider — it already previews the size; it should glide, not jump between sizes.
- **Keep away:** strokes that animate themselves, any marching-ants movement, brush "sparkle" on the painted area.

### History
- **Tap a photo, it grows.** Tiles expand into the full photo view with the shared-element grow — the photo-app pattern users already know from Google Photos. Same cost fix as the pick flow.
- **Deleting a photo is visible.** After you confirm a delete, the tile fades and shrinks away and the grid closes the gap calmly. You saw it leave; you are sure it is gone. That is information, not decoration.
- **Keep away:** the grid animating in photo-by-photo every time you open History (a screen you visit often must open *now*), any tilt or 3D card tricks.

### Settings
- **Dark mode melts, it does not snap.** Switching the theme crossfades the whole app between light and dark in about a quarter of a second. It costs almost nothing (only colours change) and it is the kind of small smoothness people describe as "this app feels expensive" without knowing why.
- Everything else in Settings keeps the standard switch and list behaviour. A settings page is a tool cupboard, not a stage.

## 4. The honest costs

- **Three movements touch real photos** — the pick-flow grow, the Result dissolve, the History grow. On a mid-range Android phone, moving full-resolution photos can drop frames. The known fix (fly smaller copies made for display, swap on landing) is part of the plan, not an afterthought. If a movement cannot hold smooth frames on a mid-range phone after that fix, it gets cut and the plain fade takes its place. Smooth beats fancy, every time.
- **Everything else moves only small controls** with fades and transforms — near-zero cost, no battery story worth telling.
- **Springs cost nothing extra.** They are a way of timing movement, not extra work per frame.
- **Reduced motion is a requirement, not a phase two.** Every movement above names what it becomes when the setting is on.

## 5. The whole plan on one page

| Where | Movement | Its job |
|---|---|---|
| Everywhere | One fade-and-small-slide for screens; buttons dip when pressed | Orientation; every tap answered |
| Big moments | Tiny haptic tick (toggle, confirm, saved) | The finger believes the tap |
| Home demo | Handle sweeps once, then never again | Teaches the drag |
| Home banner | Slides in when a job's state changes | Announces a real change |
| Pick flow | Picked photo grows into the next screen | Teaches "your photo goes in, comes back" |
| Review (S4) | Results fade in as one beat; taps melt colours; count crossfades | Honest arrival; trustworthy counts |
| Processing | Stage words crossfade on real changes; beam unchanged | Shows real state changes only |
| Result | One Before→After dissolve; Save becomes "Saved" briefly; handle nudges once | The payoff; the receipt; teaches compare |
| Brush | Undo fades the stroke; guide outline fades in; size dot glides | Shows what changed |
| History | Tile grows into the photo; delete visibly closes the gap | The known photo pattern; deletion you can see |
| Settings | Theme change crossfades | Cheap smoothness |

**Deliberately not in the plan:** confetti and celebration of any kind; sparkles and shine sweeps; shimmering fake-content placeholders (the grey shimmer look that users turned on Google for); one-by-one reveals that fake the server's timing; looping movement on any photo; bouncy springs; 3D tilts and parallax. If it does not teach, confirm, or show a change — it is not in the app.
