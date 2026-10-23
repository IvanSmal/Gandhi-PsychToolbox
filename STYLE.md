# Style guide

MathWorks publishes no official style guide for user code. This project follows
the widely-used conventions from Richard Johnson's *MATLAB Programming Style
Guidelines* plus the patterns MathWorks uses in its own OOP toolboxes.

## Naming

| Element | Convention | Example |
|---|---|---|
| Classes | `PascalCase` | `RewardHandler` |
| **Public properties** | **`PascalCase`** | `obj.TrialNumber` |
| Private properties | `lowerCamelCase` | `obj.checkeyeCounter` |
| Methods | `lowerCamelCase` | `startTrial`, `checkEye` |
| Functions | `lowerCamelCase` | `setupDaq`, `rigIniPath` |
| Local variables | `lowerCamelCase` | `trialNumber` |
| Constants | `UPPER_SNAKE_CASE` | `CONFIG_SECTIONS` |

PascalCase for **public properties** is the MATLAB-specific one that surprises
people from other languages, but it is what every MathWorks object does
(`fig.Position`, `app.UIFigure`, `obj.SampleRate`) and what App Designer already
generates for components.

## Terminology

| Term | Means |
|---|---|
| **display** | the TV the ANIMAL looks at (Psychtoolbox screen 1, `gr.window_main`) |
| **monitor** | the screen the EXPERIMENTER sees (Psychtoolbox screen 0, `gr.window_monitor`) |
| **stim** | NEURAL stimulation (`@internal/stim.m`). Never the visual display. |

## DO NOT RENAME without updating the matching string

This codebase ships MATLAB **source code as text** between four processes over
UDP, where the receiver `eval`s it. Renaming any identifier below will not
produce a compile error, a lint warning, or a grep hit from a rename tool. It
breaks at runtime, in another process, inside a swallowed `try/catch`, in a
terminal nobody is watching.

Everything in this section was enumerated from the actual call sites.

### A. Cross-process contract

`graphics` properties addressed as text by `mh.evalgraphics(...)` and by the
command strings `@internal/gettarg.m` builds:

    diode_color   trialstarted   activestatename   flipped
    window_main   window_monitor target            functionsbuffer
    movie         texture        monitortexture

The UDP wire protocol variable names — `classes/@internal/Screen.m` emits them
as source text, `GraphicsHandler.executeScreen` declares and `eval`s them:

    args_udp   outs_udp   additionalinfo_udp   commandID_udp

Values the helper processes send back for MHost2 to `eval`:

    mh.graphicssent   mh.readyforflip   isGraphicsReady     (GraphicsHandler)
    app.insToTxtbox   app.TotalrewardsEditField.Value       (RewardHandler)
    GenerateSound_udp                                       (makesound -> SoundGenerator)

### B. Parameter names appearing in `exist(...)`

Renaming the parameter without the string makes the check silently false, so the
default branch always runs. In `deg2pix` that would reinterpret cartesian input
as polar — wrong numbers, no error.

    GraphicsHandler.m  allargs          deg2pix.m    coordType, screenParams
    MHost2             howmany          reward.m     identifier
    MHost2             isGraphicsReady  checkeye.m   pos

### C. User-authored expression contract

`target.custompath_x` / `custompath_y` are user-written expressions `eval`d as
`@(mh,t,x)` / `@(mh,t,y)`. Those three argument names are a contract with every
custom path expression the lab has written, including files not in this repo.

### D. Serialized data

Property names of `trial`, `internal`, `target`, `interval`, `data` and
`experiment` are baked into every saved `.mat`. Renaming one means historical
sessions no longer load. `savestate` copies the class definitions next to the
data for this reason, but analysis code would still need to handle both spellings.

## Migration order

Work outward from lowest risk:

1. **Local variables** — invisible outside their function, never serialized.
2. **Private properties** not listed above.
3. **Function file names** — grep-able, but check the lists above first.
4. **Public properties and method names** — last, and only with a compatibility
   shim for loading old data.

## How to verify a rename

For a **pure** function (no UDP, no hardware, no handle mutation), prove
equivalence rather than eyeballing it:

1. Copy the pre-change and post-change versions side by side under distinct names.
2. Run both over a grid of inputs covering every branch — including empty, `NaN`,
   multi-row, and each argument count, since `nargin` selects different paths.
3. Compare with `isequaln`, and compare error identifiers too.
4. Only install once the mismatch count is zero.

This is how `deg2pix`/`pix2deg` (119 cases) and `FakeSaccades`/`data` (49 cases)
were migrated.

For anything impure, that option does not exist. Verify instead by confirming the
identifier appears in none of the lists above, parse-checking the file, and
reading the diff.

## Editing the `.mlapp` files

App Designer stores code in **three** containers, and a patch must be applied to
whichever one holds it or the file's two internal copies desync — silently:

    code.EditableSectionCode   properties blocks and non-callback methods
    code.StartupCallback.Code  startupFcn
    code.Callbacks(i).Code     one entry per component callback

Editing only `matlab/document.xml` leaves `appdesigner/appModel.mat` stale.
Use `appdesigner.internal.serialization.FileReader`/`FileWriter` and write with
`writeMLAPPFile(text, appData, metadata)`.

Never commit an export named `MHost2.m`: MATLAB resolves a `.m` before a
`.mlapp`, so it shadows the app and the app cannot launch at all. That is why
App Designer's own export renames the class to `MHost2_exported`.
