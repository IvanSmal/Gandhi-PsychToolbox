# Handoff — Ubuntu_dev VM on batistaserver

Last updated: 2026-10-27: movie timing, which movie frame was on screen at
every flip (§14), on branch `movie-timing` (cut from `main` after PR #49 merged
`steady-targets`), pushed, no PR yet. Tested on rig2 the same day, and rig2
was left on this branch at the user's request (§14).
2026-10-23: exact repeats of failed trials with a per-task
repeat count (§13), and before it the trial loop made faster (§12), on branch
`steady-targets` (cut from `main` after PR #48 merged `ai-assisted-2`), merged.
Earlier that day: one timeline for every saved time (§11), with
`documentation/timing.md`. Before it (2026-10-22): all 7
note-list items done; items 2, 4–7 committed, the last one tagged `v0.1.0`
(§8); stimulus timing and the `d.timestamps` fix (§9, `649fa08`); Trellis
Scope rework (§10). All of it, and the tag, pushed to GitHub.
**Access details** (addresses, accounts, keys, sudo setup, ports, the licence,
a security note) are not in this file because the GitHub repo is public. They
are in `HANDOFF-VM.private.md`, kept outside the repo: `~/HANDOFF-VM.private.md`
in the VM, and the Claude Code project folder on Windows. Ask the user if you
do not have it.

Written for a fresh Claude Code session with no prior context. Companion to
`HANDOFF.md` (rig work); its hard constraints still apply — above all, never
touch rig2.

---

## 1. What this is

A libvirt/KVM Ubuntu VM that runs this repo's MHost2 + GraphicsHandler with no
rig hardware, in MHost2's **Demo mode** (simulated xippmex). It is for task
logic and layout, not timing: there is no GPU, Psychtoolbox renders in software
at ~12 fps with no vsync.

**Status: works end to end.** In demo mode, 45 trials of the GoNoGo test set
ran, were saved, and GraphicsHandler drew T0 / T1 / photodiode square on the
animal display (verified from a full-resolution capture: T0 at the true centre
960,736).

Since then the VM has been the test bed for the user's 7-point note list
(§8, §9): seven commits on `ai-assisted-2` and the tag `v0.1.0`, made in the
VM and pushed to GitHub on 2026-10-22. MHost2 and GraphicsHandler were left running in demo mode
in the VM (started by the session; safe to close).

---

## 2. Access and locations

| What | Value |
|---|---|
| Host | `batistaserver`, Ubuntu 24.04, reached over Tailscale (address, user, sudo rules: private notes) |
| VM | libvirt domain `Ubuntu_dev`, Ubuntu 24.04.5 desktop, 2 vCPU / 16 GB, user `batista`, on the host's default NAT net (address: private notes) |
| SSH | Windows `~/.ssh/config` aliases `batistaserver` and `ubuntu-dev` (ProxyJump); key: private notes |
| sudo in VM | private notes |
| Viewer | SPICE (address and port: private notes; autoport — ask `virsh -c qemu:///system domdisplay Ubuntu_dev`). Windows launcher: `Desktop\Ubuntu_dev VM.bat` (looks the port up, starts the VM if off, `--auto-resize=never`) |
| Other consoles | private notes |
| Repo in VM | `~/Documents/MATLAB/Gandhi-PsychToolbox`, branch `steady-targets` (§12; cut from `main` @ `c724798`, the merge of PR #48 = `ai-assisted-2` §8-§11; tag `v0.1.0` is on `070ea05`), **= GitHub** (pushed from the Windows checkout, last on 2026-10-23; for another branch, put its name in the commands below). The VM has no GitHub credentials; to publish later VM commits, from the Windows checkout (which sits on `ai-debugged` with someone's uncommitted work: never check out or merge there): `git fetch ubuntu-dev:Documents/MATLAB/Gandhi-PsychToolbox +refs/heads/ai-assisted-2:refs/remotes/vm/ai-assisted-2` (add `refs/tags/<tag>:refs/tags/<tag>` for a new tag), check it fast-forwards GitHub's branch and holds no VM-only line, then `git push origin refs/remotes/vm/ai-assisted-2:refs/heads/ai-assisted-2` and delete the `vm/` ref. Push only when the user says so. The end-to-end test in §1 ran on `ai-debugged` @ `c3d7353` |
| MATLAB | R2025b Update 4, `/usr/local/MATLAB/R2025b` |
| PTB | 3.0.21 manual install, `~/Documents/MATLAB/Psychtoolbox` |
| Test material | `~/Documents/Experiment/{Parameters,Tasks/CirCularGonoGO,Custom Functions}` (copied from `for claude/`) |
| Session data | `~/Documents/Data_default/` |

VM autostart is off. Start: `virsh -c qemu:///system start Ubuntu_dev` on the
host (the host user is in the `libvirt` group, no sudo needed).

---

## 3. How to run it

1. Double-click `Ubuntu_dev VM.bat` on the Windows desktop.
2. Log in as `batista`, session **Ubuntu on Xorg** (gear icon; GDM remembers
   it). PTB and the mouse/clipboard fixes need Xorg.
3. Double-click **MHost2** on the VM desktop (`~/.local/bin/mhost2-launch.sh`:
   starts `matlab -nodesktop -r MHost2` from `Main code` in a terminal that
   stays open after exit).
4. Click **Demo mode** in "Trellis not found".
5. File → Import Custom Functions → `~/Documents/Experiment/Custom Functions`
   (needed by the CW/CCW tasks; `.Custom_Functions` is per session).
6. START.

---

## 4. What was changed (all VM-local, all reversible)

### Host (batistaserver)
- Rig key added to the host user's `~/.ssh/authorized_keys`.
- Domain XML backup: `~/Ubuntu_dev.xml.bak-20261021`. Server mouse mode was
  tried and reverted; the live XML equals that backup.

### VM system
- Packages: `openssh-server`, `spice-vdagent`, `mesa-utils`, `xdotool`,
  `python3-tk`; the user also ran a full `apt upgrade`.
- MATLAB toolboxes added with mpm (`~/Downloads/mpm/mpm`): Instrument Control
  (`udpport`, required), Curve Fitting (`smooth` in LiveAnalysis), Statistics &
  ML (`normrnd` in FakeSaccades).
- `toolbox/local/pathdef.m` now owned by `batista` and holds PTB 3.0.21 and
  `genpath("Main code")`. Original: `pathdef.m.orig-before-ptb`.
- `/usr/lib/x86_64-linux-gnu/libglut.so.3 -> libglut.so.3.12.0` (PTB moglcore).
- `/usr/local/bin/gnome-terminal`: wrapper that unsets `LD_LIBRARY_PATH`, then
  runs `/usr/bin/gnome-terminal`.
- `/etc/X11/xorg.conf.d/90-ptbxorg.conf` (PTB XOrgConfCreator file, two X
  screens via ZaphodHeads) edited: `Screen1 Absolute 1360 0` instead of
  `RightOf`; Virtual-1 `PreferredMode 1360x768` + `Enable`; Virtual-2
  `PreferredMode 1920x1080` + `Enable`. Original: `~/90-ptbxorg.conf.bak-20261021`.
- `/etc/X11/xorg.conf.d/91-vm-pointer.conf`: new, SPICE pointer mapping (§6).

### VM user `batista`
- `~/.ssh/authorized_keys` (rig key).
- `~/.matlab/R2025b_licenses/`: the lab's MATLAB licence (details: private
  notes). The expired one is still in `matlabroot/licenses` (harmless).
- `~/.local/lib/vdagent-onescreen/` + `~/.config/autostart/spice-vdagent.desktop`
  (clipboard fix, §6).
- `~/.config/autostart/vm-screen1-mode.desktop`: `xrandr` screen 1 → 1920x1080
  at login.
- `~/Desktop/MHost2.desktop`, `~/.local/bin/mhost2-launch.sh`.
- `~/.local/share/applications/gandhi-{mhost2,parameters,graphicsinfo,monitor,trellisscope}.desktop`:
  written at run time by `windowIdentity` (§8, item 5), not by hand.
- `~/mlapp_backups/`: a timestamped copy of `MHost2.mlapp` from before each
  scripted edit.

### Repo in the VM (do not commit any of this)
- `Main code/inis/FilePaths.ini`, `ScreenParams.ini`, `RigConfig.ini` written
  from the examples. **`RigConfig.ini` is not gitignored.** RigConfig uses
  rig1's geometry plus `display_xres/yres/refresh = 1920/1080/60`, and a
  `[stim]` section (new on `ai-assisted-2`) set to `127.0.0.1:2028` so a stim
  task in the VM can never reach real hardware — without it
  `stimDestination.m` defaults to the rig stim PC.
- `GraphicsHandler.m`: one uncommitted line after `SkipSyncTests`:
  `Screen('Preference', 'ConserveVRAM', 64); % this is only for vms`.
  The VM's pre-existing copy of that edit is also in `stash@{0}`. Every commit
  must leave it out (recipe in §8).
- Local `main` was fast-forwarded to GitHub's `783f4a9` by the picker test
  (it was 15 behind at `eecfd35`).
- `HANDOFF-VM.md` (this file) is committed on `ai-assisted-2` since
  2026-10-22, at the user's request. The repo is public: never put access
  details in it (they go in `HANDOFF-VM.private.md`, outside the repo). Edit
  it in the VM and commit it like any other file; the Windows checkout (on
  `ai-debugged`) keeps an untracked copy in step.

---

## 5. Open items

1. **MHost2 does not recover from a mid-trial error.** After any error in
   `Run_Experiment` (e.g. custom functions not imported), every later trial
   fails within a second with `target "T0" has not been fetched for this
   trial. Fetched so far: (none)` — the new trial starts with the old trial's
   state and skips its setup block. Only restarting MHost2 clears it. Also, the
   first START after an error only runs the recovery path and returns. Leads in
   `MHost2_exported.m`: catch block ~L822–842 (`app.mhpass =
   copy(app.mhbackup)`), backup taken ~L779, `app.errored` branch ~L294.
   `copy()` is shallow, so handle members (`mh.trial`) are shared with the
   backup. Not fixed — user deferred it. This bug applies to the rig too.
2. **Rendering is software, ~12 fps.** The VM's GL is llvmpipe. Only MATLAB's
   bundled Mesa 17 (auto-selected by MATLAB's launcher) works with PTB 3.0.21;
   on system Mesa 25.2 PTB segfaults inside `libGLX_mesa` (tried
   `ConserveVRAM` 0/64/65/524288/2^27, `LIBGL_DRI3_DISABLE`, softpipe). Options:
   newer PTB, or virgl/egl-headless via the host's RTX 3050 (host NVIDIA driver
   reports a driver/library mismatch — needs a host reboot first).
3. Compiled RewardHandler / SoundGenerator are not installed; their terminal
   tabs fail at startup. Nothing else depends on them.
4. GDM still defaults to Wayland (`WaylandEnable=false` in
   `/etc/gdm3/custom.conf` would fix it). Screen lock + 5-min blank are on — the
   user was asked to change those themselves.
5. The fixed X layout in §4 was verified live, not yet across a fresh login.
   If clicks drift after a login, re-run the calibration (§6).
6. MHost2's `-logfile` stops capturing console output partway through a
   session; use the error logs in `Main code/ErrorLogs/` instead.
7. NeuroDebian PTB packages are installed but version-mismatched (3.0.19 MEX vs
   3.0.22 M-files) and not on the path. Leave them off the path or remove.
8. No libvirt snapshot exists yet; suggest one now that the VM works.
9. **Before the §8/§9 commits run on a rig** (they are on GitHub; a rig gets
   them with File → Switch Branch or `git fetch`, tags included): check the
   stimulus timing against the photodiode and a Trellis recording (§9);
   rebuild the compiled RewardHandler
   (the Stop Reward fix is mostly in RewardHandler.m; UDP port 2026 must be
   free), and `sudo apt install xdotool` (plus `x11-utils` for `xprop`) or the
   windows keep the generic dock icon.
10. The first reward after MHost2 starts never reaches "Total reward"
    (pre-existing, minor, not fixed).
11. A security issue in one of MHost2's UDP listeners (details: private
    notes). Worth fixing.
12. In the VM, GraphicsHandler's render loop sometimes stalls for up to 5 s
    (software GL), so screen changes can lag well behind MHost2. Do not read
    timing from the VM.
13. `wmctrl` is not installed in the VM; use `xdotool` / `xprop`.

---

## 6. Why things are the way they are (learned the hard way)

- **"Main code" must be on the saved path.** MHost2's property defaults call
  `IniConfig()` before `startupFcn` adds anything, so a bare
  `matlab -r MHost2` fails with `Invalid default value for property 'ini'`.
- **Keep MATLAB's bundled libstdc++ and Mesa.** Removing
  `sys/os/glnxa64/libstdc++.so.6` makes MATLAB pick system GL and PTB crashes
  (open item 2). But that old libstdc++ also leaks into `system()` children, so
  `gnome-terminal` dies with `GLIBCXX_3.4.31 not found (libvte)` and MHost2
  can never start GraphicsHandler — hence the wrapper in `/usr/local/bin`.
- **`ConserveVRAM 64` is VM-only.** On Linux it means "use the Mesa X11
  software renderer"; without it PTB aborts on the VM.
- **Clipboard:** stock spice-vdagent 0.22.1 segfaults with more than one X
  screen (skips XRandR setup, then reads `res->noutput` through NULL on
  graphics-device-info). The LD_PRELOAD shim makes it see screen 0 only;
  selections are per display, so copy/paste still covers both screens.
- **Mouse (client mode, never captured — by design):** X spreads absolute
  pointers across the whole two-screen desktop, while SPICE sends display-1
  coordinates. `91-vm-pointer.conf` scales by 1360/3280 and 768/1080 and adds a
  2 px hotspot offset; a calibration run put every click within 0–2 px. The
  matrix is only right for screen 0 1360x768 + screen 1 1920x1080 at x=1360.
  `RightOf` placed screen 1 by screen 0's size at X start, which is the SPICE
  window size (`Xorg.0.log`: `initial mode 1280x800`) — hence `Absolute`.
  Server mouse mode was jumpy on Windows virt-viewer; do not go back to it.
- **Display 2 "Display output is not active"** = Virtual-2 had no mode
  (disconnected at X start). Fixed by `Enable` + `PreferredMode` + the login
  `xrandr`.
- Domain XML changes need a full stop/start (`systemctl poweroff` in the
  guest, then `virsh start`), not a guest reboot.
- Never `pkill -f` a pattern that appears in your own ssh command line — it
  kills the ssh shell (happened twice). Use exact PIDs or a `^/path` anchor.
- Windows batch `for /f` treats `=` as a separator: use `-o "BatchMode yes"`.
- New scp (SFTP) wants paths with spaces quoted, not backslash-escaped.
- **Editing `MHost2.mlapp` without App Designer** (from MATLAB in the VM): read
  with `appdesigner.internal.serialization.FileReader` (`readMATLABCodeText`,
  `readAppDesignerData`, `readAppMetadata`), write with `FileWriter(f).
  writeMLAPPFile(code, ad, md)`, then read back and compare. Change both copies
  of the code: the code text, and App Designer's own cell arrays of lines
  (`ad.code.EditableSectionCode` for methods, `ad.code.StartupCallback.Code`
  for startupFcn). Split with `split(string(txt), eol)`, never `strsplit` — it
  drops every blank line (cost a restore from backup once). Back up to
  `~/mlapp_backups/` first. `MHost2_exported.m` must equal the code text with
  `MHost2_exported` for `MHost2`; patch it the same way.
- Claude's Edit tool strips trailing whitespace on blank lines, and this repo
  has a lot of it: check `git diff` for whitespace-only noise and restore it.
- Run `checkcode` on any MHost2 change before restarting it: a broken edit
  makes the idle loop error ~70 times a second.
- Anything MATLAB starts with `system()` (gnome-terminal, xdotool, xprop)
  needs `unset LD_LIBRARY_PATH` first, for the libstdc++ reason above.
- GNOME's dock groups windows by X `WM_CLASS` and takes the icon from the
  `.desktop` file whose `StartupWMClass` matches. A uifigure's `Icon` never
  reaches the dock; `xdotool set_window --class` on a mapped window does.
- MATLAB's `system()` gives commands a terminal (`[ -t 1 ]` is true), so
  `git diff` / `log` / `show` start a pager and hang forever: always
  `git --no-pager` from MATLAB.
- A running MATLAB keeps the copy of a function file it already loaded:
  edits to `branchPicker.m` etc. show only after MHost2 restarts.
- `xdotool windowclose` destroys a MATLAB window without running its close
  request: MHost2 stays alive invisibly and GraphicsHandler is never told to
  exit. Close MHost2 from its own window or File → Exit.
- Each picker switch leaves the previous terminal open at "Press Enter to
  close" (the launcher keeps it for reading errors).
- The user sometimes works in the VM while a session runs. Before killing a
  MATLAB, check it is one you started (`ps -o lstart`) — a user's MHost2 was
  killed by mistake once.

---

## 7. Driving the VM from a session

- Screenshots: on the host, `virsh -c qemu:///system screenshot Ubuntu_dev
  out.ppm --screen 0|1` (screen 1 = animal display), convert with PIL.
- Clicks/keys: `xdotool` in the VM with `DISPLAY=:0
  XAUTHORITY=/run/user/1000/gdm/Xauthority`; raise MHost2 by clicking its
  title bar first — other windows open on top of START.
- GUI processes started over SSH must run in the user session:
  `systemd-run --user` with `XDG_RUNTIME_DIR=/run/user/1000` and
  `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`.
- What the state machine is sending: `sceneRead(sceneOpen(false))` from a
  separate MATLAB — `seq` should climb while trials run.
- Ubuntu may pop up an "Upgrade Available" prompt over the windows, so clicks
  miss. Answer "Ask Me Later" (changes nothing); never upgrade.
- A test-restart helper that kills every shell under the terminal server also
  closes the reward handler's terminal: start it again (below) before testing
  rewards.
- GraphicsHandler console: start it with `-logfile` (e.g. `/tmp/gh.log`);
  MHost2 reconnects to a restarted GraphicsHandler without a restart of its own.
- RewardHandler from source against the demo xippmex: `cd /tmp; matlab
  -nodesktop -logfile /tmp/rh.log -r "addpath('<repo>/demo_xippmex');
  RewardHandler"` (in the user session, as above).

---

## 8. The user's note list (2026-10-21)

The user asked to go slow: investigate, propose, wait for a yes, implement,
test in the VM, commit only when asked. "Gooey" in their notes was
voice-to-text for GUI; all items are software. Commits are on `ai-assisted-2`,
made in the VM and pushed to GitHub (§2).

| # | Item | Result |
|---|---|---|
| 1 | Reward button at idle | Already works (6/6 in demo mode). Only the "Total reward" glitch (open item 10) |
| 2 | Stop Reward button | Fixed, `f27ea6a` (`rewcheck.m`, `RewardHandler.m`). Stop closes the valve and sends `stop` to RewardHandler's new stop port **2026**; RewardHandler polls it while the valve is open, ends early, and logs/returns only the time the valve was open ("stopped early; Xs requested"). Its valve re-open branch is left as is, by the user's choice |
| 3 | Targets left on screen at idle | Already fixed by `c3d7353` (stoptrial publishes the final frame, stale frames blank after 1 s, blank on leaving a trial). The VM clears ~0.5 s late (software rendering) |
| 4 | Cursor visibility | `cafe606`. Cursors always draw on the monitor window. File → Cursors on Display ▸ Cursor 1–5 also draws a cursor on the animal display, during trials only (blank between trials). Saved as `display=0/1` under `[cursorN]` in `ScreenParams.ini`, applied live through `evalgraphics` |
| 5 | One dock icon per window | `00f3688`. `background_functions/windowIdentity.m` gives MHost2, Parameters, Graphics Info, the PTB monitor window and Trellis Scope their own WM_CLASS and `.desktop` entry; icons are letter tiles in `assets/icons/` (replace a PNG to change it). MHost2's window title is now "MHost2" (was " ") |
| 6 | Git branch picker in a menu | `4ac2b36`. File → Switch Branch… (`background_functions/branchPicker.m`): every local and GitHub branch, newest first, with status (current / same as GitHub / N behind: will update / N not on GitHub / on GitHub), refreshed from GitHub on open; refused while trials run. All checks run before anything closes: a branch with its own copy of an ignored rig file (`rig1`, `fps`, … track `ScreenParams.ini`) is refused; uncommitted changes → set aside (stash) / carry over (refused if the branch changes those files) / cancel. Then MHost2 closes through its own close request (GraphicsHandler exits with it), and a terminal waits for that MATLAB to exit, runs `git switch --no-overwrite-ignore` (+ `--track` or a fast-forward), and starts MHost2 again; on failure it restores the stash and restarts on the old branch. Tested in the VM: rig1 refused (and refused again by git itself in the terminal), carry-over refused / allowed, stash, restart, trials-running refusal, `main` fast-forwarded by 15. Only branches that contain it have the menu (not `main` / `ai-debugged` yet) |
| 7 | Version number on the main screen | `070ea05`, tagged **`v0.1.0`**. `background_functions/codeVersion.m` works it out from git once per run (`describe --tags --match "v[0-9]*" --dirty` + branch). Title bar, for users (the user asked for version and branch only): `MHost2 v0.1.0 (ai-assisted-2)`; `MHost2 (main)` on a branch with no tag in its history. Full form, for tracing results to code, at the top of each `description.txt` when trials stop and in every error log: e.g. `v0.1.0+4 (ai-assisted-2, 4ac2b36)  modified` ("modified" = tracked files edited locally; the VM always shows it). Semantic versions, 0.x until 1.0.0; a new version = `git tag -a v0.2.0` on a commit + push the tag, nothing to edit in code |

Also, after the list: `6b623d2` moves Graphics Info's Grid units dropdown onto
the photodiode row (it overlapped the State box), at the user's request.

**Committing in the VM** (keeps the ConserveVRAM line out): copy
`GraphicsHandler.m` aside, drop the line with `grep -vxF "$VMLINE"`, `git add
--` explicit paths only (never `-A`; `RigConfig.ini` is not ignored), commit
with `-c user.name=IvanSmal -c user.email=smalianchuk.ivan@gmail.com -F msg`,
copy the file back, then check `git show HEAD:<GraphicsHandler path> | grep -c
ConserveVRAM` is 0 and `git diff` is that one line.

---

## 9. Stimulus timing (2026-10-22, `649fa08`)

> **Names and clocks changed on 2026-10-23 (§11):** every saved time is now
> ms since the trial start on the NIP clock. `requested` / `displayed` /
> `delay` / `onset_tick` / `onset` below became `requested_ms` /
> `displayed_ms` / `delay_ms` / `displayed_tick`; `d.timestamps` became
> `data.time_ms`; state and target times moved into each object. The method
> described here is unchanged. `documentation/timing.md` is the reference.

Goal (the user's): know exactly when each stimulus appeared on the display,
without working backwards from command IDs. Designed with the user first
(they chose: photodiode only on state changes; a `'Tag'` option on
`mh.Screen`; NIP/Trellis time as well; column name `photon_tick`).

Replaces `data.graphics_fliptimes`, `data.graphics_commands` and
`data.DiodeFlipStates` (old trial files are plain structs, so they still load).
Kept for now: target `timestamp`/`moving_position`, state times, `d.timestamps`
(now correct, see below).

New trial fields (structs of column arrays):
- `stimulus_events`: one row per item appearing/disappearing and per state
  change (`tag photodiode`, `event state`): tag, kind, event, state,
  requested / displayed (Psychtoolbox `GetSecs`, which on Linux is Unix-epoch
  seconds), delay, flip, frame_id, onset_tick (NIP 30 kHz), photon_tick (when
  light appeared; NaN without a photodiode signal), x_deg, y_deg, rect_px,
  missed. A change gone before the next flip keeps displayed = NaN.
- `stimulus_frames.<item>`: one row per flip it was on screen (position as
  drawn, both clocks, state); `stimulus_frames.photodiode`: one row per colour
  change.
- `clock_sync`: `[GetSecs tick]` pairs from every NIP read, the fit
  (`tick = ticks_per_s*GetSecs + tick_at_0`), photodiode delay calibration,
  `trace_start_tick` (NIP tick of `d.photodiode(1)` / `d.eyepos(:,1)`),
  `trial_start_tick` (NIP tick of `start_autogenerated`) and
  `trial_start_sample` (the eye/photodiode sample at the trial start).

How: targets drawn at their `getpos` rectangle and `mh.Screen(..., 'Tag', name)`
commands are listed per published frame (`background_functions/frameItems.m`,
persistent state for speed); `publishFrame` logs changes (`stimulusRequests`);
GraphicsHandler logs each flip (`gr.flipLog`) and, in `dumpdata`, builds the
tables (`background_functions/buildStimulusTiming.m`, a pure function).
`nipTick` now also logs the clock pairs. Files: Screen.m, internal.m,
starttrial.m, stimulusRequests.m (new), target.m (one call in getpos),
data.m, graphics.m, nipTick.m, frameItems.m (new), buildStimulusTiming.m
(new), GraphicsHandler.m, MHost2 (.mlapp + export: end-of-trial block, and
the `savestate` re-dump check, which was inverted).

Tested: synthetic trial with known answers (`test_buildStimulusTiming.m` in
the session scratchpad: delay 12.49 ms recovered from a 12 ms photodiode
step, NIP onset within 6 ticks, blinks/short states never displayed, missed
flips, leftovers, demo sine rejected); every drawing command's position;
~100 demo trials in the VM with a temporary tagged cue and moving T1 (test
task restored afterwards). Cost in MHost2's loop (VM): ~+35 us per frame
without timed items, ~+75 us with a target and a tag (publish itself ~300 us).
NOT tested: a real photodiode / Trellis recording (photon_tick is NaN in demo
mode); check on rig1 against the .nev/.nsx files.

`d.timestamps` fix (same commit): the eye/photodiode trace starts with the
first NIP read, BEFORE the ITI wait, but `d.timestamps` assumed sample 1 =
`start_autogenerated`, so eye/photodiode times were late by the remaining ITI
plus setup (VM: median ~0.55 s, 0.05-0.75 s) and disagreed with cursor
times. Now `starttrial` records the NIP tick of the trial start and the
samples are placed by the NIP clock: pre-trial samples get earlier times
(negative relative to `tstarttime`), and `clock_sync.trial_start_sample` is
the sample at the trial start (for code that indexes samples). VM check,
25/25 trials: that sample carries `floor(tstarttime*1000)`; the trial-start
tick agrees with the clock fit of the first state frame within ~2 ms.
Recordings made before this commit still have the shift; only the Trellis
files (NIP-timed analog, state markers since 2026-09-13) can realign them.

Gotchas from this work:
- GraphicsHandler's helpers are NESTED functions: a variable name used in
  both the main loop and a helper is the same variable (`nm` is overwritten
  by `drawFrame`). Use fresh names or `frame.*` fields.
- Object property access and struct-array growth are slow in the 1 kHz loop
  (a few us each); keep per-frame state in a function's persistent variables
  with fixed buffers, as `frameItems` does. Cross-process benchmarks in the VM
  are noisy (background load); compare inside one process (stub swap).
- MATLAB's current folder shadows the path: a stale copy of a function in the
  working directory silently wins.

---

## 10. Trellis Scope rework, phase 1 (2026-10-22, `6465d07`, pushed)

`Main code/Utilities/TrellisScope.m` rewritten (the data-source half is
unchanged). The window opens with one plot; "+ Add plot" adds more; each plot
has Modify / Remove. Modify docks the settings panel on the left for that
plot: up to 5 channels drawn on the same axes, align state, pre/post, hold
trials, colour by channel (default; older trials fainter) or by task, Y range,
mark other states. Apply changes only that plot (its held trials restart).
Spike channels are rasters on a right-hand axis, a block of rows per channel.
One shared buffer holds the union of all plots' channels. Channel colours
come from the name (eye/photodiode fixed), so they match across plots and
sessions. The layout is saved per computer in
`fullfile(prefdir, 'TrellisScopeLayout.mat')` (VM: `~/.matlab/R2025b/`) on
every change and on close, and restored on open (channels the computer does
not offer are dropped).

Bug found while testing: a timer tick can run in the middle of any callback
(seen between two property assignments), so every change to the plots or the
acquired channels takes `holdTicks()` first; ticks skip while it is held.

Tested: scripted runs with the synthetic source (add / apply / colour by task
/ remove / save / restore, 6 runs, no tick errors), then live in the VM from
MHost2's Utils menu with demo trials (eye, photodiode, spike rasters, real
state onsets, Modify/Apply/Remove/Close, close and reopen restoring the
layout). In the VM, clicks take 10-20 s to act while trials run (load ~14 on
2 vCPUs); not a scope problem.

Phase 2 (target positions as a function of time, a Targets button in
Modify) is next and needs a proposal first (§ the session's design:
renderer publishes each flip's targets; scope puts them on the NIP clock).

### Phase 2: target positions (2026-10-22, `a8de13d`, pushed; user testing on a live rig)

- **Renderer:** GraphicsHandler (`publishTargetFlips`, called from
  `logFlip`) keeps the last second of display flips (counter, onset GetSecs,
  each target / 'Tag'ged item's box centre in px) and publishes them about
  every 100 ms and on the trial's blank flip to
  `background_functions/targetFlipsPath.m` (`/dev/shm/gandhi_target_flips.bin`).
  Cost: ~0.3 ms per publish in the VM. Its helper variables are `tf*`-prefixed
  (nested-function sharing, §9 gotcha).
- **Scope:** every read pairs GetSecs with the newest sample's NIP time; the
  minimum difference over 20 s is the offset that puts flip onsets on the NIP
  clock. Positions go through `pix2deg` with the rig geometry read once.
  Modify → "Targets..." lists every target seen (plus saved ones); ticked
  ones are drawn on the left axis (X dashed, Y dash-dot, a dot per flip),
  applying at once, to held trials too. X/Y follows the eye channels unless
  chosen. A line breaks only where a flip did not show the target (flip
  counters). Each target in a plot gets its own colour. Selections are saved
  with the layout. Windows are held 0.3 s longer while target data flows.
- **Tested in the VM:** a scripted stand-in publisher (19-23 points per run,
  0.000 ms placement error); live against MHost2 + the new GraphicsHandler
  (3 runs: 51, 38 and 31 target points, every one matched to the trial file's
  `stimulus_frames`, time within ±0.02 ms, positions identical); the Targets
  list clicked through in the GUI; phase-1 regression run clean.

---

## 11. One timeline for every saved time (2026-10-23)

The user asked for the confusing timing to be fixed: a session's data held
times on three clocks (`getsecs` wall-clock seconds since midnight,
Psychtoolbox `GetSecs`, NIP ticks) in many places. Their principle:
**universality over brevity**. Each target and state should carry all of its
own information, and anything should be comparable with anything else.
Duplicates are fine if they are interpretable and comparable.
`documentation/timing.md` describes every field and how it is calculated.

- **The timeline:** every saved `*_ms` is ms since the trial start (when
  `setstate('start_autogenerated')` ran), on the NIP clock.
  `trial.start_tick` is that moment as a NIP tick
  (`tick = start_tick + 30*ms`). `*_tick` columns are NIP ticks.
- **Live code uses `GetSecs` only** (`setstate`, `checkint`, `getpos`, the
  ITI, cursor sampling); `getsecs` is gone from the trial path. The reward
  handler and the udp cursor slot still use it internally, which is not saved.
  Task files only call `checkint`, so they needed no change.
- **Saving:** `savestate` saves `trialRecord(mh.trial, screenparams)`, a
  **struct** (no longer the `trial` handle object), with every time
  converted. Its clock fit is `nipClock.m` (moved out of
  `buildStimulusTiming`) and is saved in `clock_sync.fit`. GraphicsHandler's
  `dumpdata` then calls `buildStimulusTiming(flips, trial, geom)` (new
  signature), which adds the displayed / photon side and reuses that same
  fit. `objectTiming.m` copies each item's rows into `trial.targets.<name>`
  (`events`, `frames`, plus `computed` = every `getpos` position) and
  `trial.tags.<name>`, and each state change's display times into
  `trial.state.<name>`. One row per entry: `requested_ms`, `displayed_ms`,
  `photon_ms`, `delay_ms`, and `code`.
- **Renamed or removed:**
  - `trial.tstarttime` / `tstoptime` → `start_tick`, `start_clock`, `stop_ms`
  - `state.X.time` → `requested_ms`
  - `targets.X.timestamp` / `moving_position` → `computed`
  - `data.timestamps` → `data.time_ms`
  - `cursor.timestamps` → `time_ms` (analog cursors from the NIP tick of the
    read)
  - stimulus table columns, as in the note in §9
  - `internal.stimStartTick`, `senttimestamp`, `lastsenttime` are gone
- **New along the way:** items wholly off the display get `photon_ms = NaN`
  (the off-screen "Toff" target had a wrong value). Each shown frame has a
  `requested_ms` (when MHost2 published it), from a new `generated` field in
  GraphicsHandler's flip log.
- **Files:**
  - `background_functions/`: `trialRecord.m`, `objectTiming.m`, `nipClock.m`
    (new); `buildStimulusTiming.m`, `GraphicsHandler.m`
  - `classes/`: `trial.m`, `data.m`, `target.m`, and in `@internal/`:
    `internal.m`, `setstate.m`, `checkint.m`, `starttrial.m`,
    `stimulusRequests.m`, `Screen.m`
  - MHost2 (.mlapp + export): cursor recording, the ITI, the trial stop,
    the end-of-trial block, `savestate` (3 places), the failed-trial reset
    list
- **Tested:**
  - A synthetic trial with known answers, 50/50: the start within 6 ticks,
    eye / cursor / getpos times within 1 ms, state entries and repeats,
    objects equal to the flat tables, off-screen NaN, demo sine rejected,
    no clock pairs, empty flip log, a raw trial object. The test is
    `test_trialTiming.m` in the session scratchpad, not in the repo.
  - 25 demo trials in the VM after a restart: all in the new form; states and
    targets match their table rows; shown positions match the last `getpos`
    before the frame within pixel rounding (median 0.03 deg).
  - STOP saved normally.
  - Finalize's combining loop, run on copies of old and new trial files mixed
    (old trial objects still load and combine; the new fields are empty).
- **NOT tested:**
  - photon times with a real photodiode, and the Trellis files: needs rig1.
  - In the VM, `start_autogenerated` and `stop_autogenerated` usually show
    displayed = NaN, because the VM's ~12 fps never draws them.
- **Breaks:** analysis scripts that read the old names, for sessions recorded
  from now on (timing.md has the old → new table).
  `e.LastParameters` is still the live object at Stop (GetSecs values, the
  trial in progress); that is a separate problem, left out of this change.

---

## 12. A faster trial loop (2026-10-23, branch `steady-targets`)

The user's requirement: state checks (one pass of MHost2's trial loop) should
take under 1 ms, and the added complexity must not have slowed them.
Measured first:
- **Rig** (2026-10-22 recordings, from the frame number on each flip): median
  1.04 ms, 90% 2.1 ms, 99% 5.6 ms, 39% under 1 ms.
- **VM**, with temporary timers between the loop's sections: median 2.0 ms,
  73% of it in the task (eye reads, `checkeye`'s conversions) and 16% in
  publishing the frame (`memmapfile`).

Changed (all checked against the old code):
1. `eyeinfo`: x and y in ONE xippmex read; the channels are worked out once
   (no `xippmex('elec','analog')` per read); `readMouseSlot` keeps "mouse mode
   off" for 0.25 s instead of decoding the slot on every eye read.
   `geteye` 383 -> 45 us. 24/24 equal to the old two-read formula with a stub
   xippmex. In demo mode x and y now get different simulated signals (the demo
   xippmex gives a channel its signal by its position in the request).
2. `deg2pix` / `pix2deg`: the usual calls are computed for all rows at once;
   everything else still runs the original row-by-row code (kept as local
   functions). `rigGeometry.m` caches the ini's `[for deg2pix]` values (calls
   without screen parameters parsed the ini each time: 1.4 ms -> 9 us).
   39,150 cases compared with the committed versions, 0 differ.
3. Shared-memory slots: `sceneSlot.m` (new handle class) reads and writes the
   `/dev/shm` file with `fread` / `fwrite` instead of `memmapfile` (write
   240 -> 33 us, read 214 -> 35 us). Layout version 3: bytes, 4 MB file (an old
   2 MB slot is rebuilt). Found and fixed while testing:
   - a seek straight back to the start of the file is served from the C
     library's read buffer (stale data): `sceneRead` seeks to the end first;
   - the old check (seq at both ends) let frames mixed from two writes
     through, in the old code too (2 and 1 corrupt frames in two-process
     tests): now a sequence lock (head = -seq while writing);
   - a saved and reloaded copy of a slot (MHost2 loads `e.mat`, whose
     `LastParameters` holds its internal object) closed the live slot when
     cleared: the open file is `Transient`, a loaded copy opens its own.
   GraphicsHandler shows the last good frame again if a read keeps failing
   (slot busy for over 2 ms; 0.02% of reads under heavy test load) instead of
   leaving the trial.
4. MHost2: the reward checks (two GUI values and the reward-handler port) run
   every 5 ms instead of every pass.
5. MHost2: the "Check time was slow" warning compared seconds with 10, so it
   never fired. Now one info-box line per trial when passes took over 10 ms
   (leaving out the setup passes and the last one).
6. MHost2 saves each pass's duration as `data.loop_ms` (documented in
   `documentation/timing.md`).

Result in the VM (same tasks; stress = Trellis Scope with 4 plots, 9 spike
channels and targets, 2 analog cursors, Graphics Info on):

| Run | Median | Mean | 99% | Under 1 ms | Over 8.3 ms |
|---|---|---|---|---|---|
| Baseline, before | 1.99 ms | 2.73 ms | 10.0 ms | 0% | 1.4% |
| Baseline, after | 0.78 ms | 1.08 ms | 3.7 ms | 81% | 0.3% |
| Stress, before | 2.60 ms | 4.67 ms | 21.5 ms | 0% | 7.6% |
| Stress, after | 1.21 ms | 2.55 ms | 12.0 ms | 38% | 2.1% |

Also tested: 261 trials saved complete with `data.loop_ms`; Trellis Scope gets
states, targets and trial names over the new slots; STOP then START; Reward at
idle and in trials (reward handler from source). NOT tested on a rig yet:
check `data.loop_ms` there. **Updating a rig:** close MHost2, GraphicsHandler
and Trellis Scope and start them together; the slot files change format.

Looked at next, not built: moving-target smoothness. In the rig data the
path maths is exact; a shown position lags where it should be by the frame's
age (median 3.9 ms, sd 3.8, r = 0.99 with the error), plus the 1-1-2 refresh
rhythm. Proposed: a steady 60 fps and positions for the moment of display. The
user decided none of this is serious enough to change.

---

## 13. Repeating failed trials exactly (2026-10-23, branch `steady-targets`)

The user's requirement: a failed trial can be repeated X times, each repeat
exactly the same as the failed trial. Before: the trial loop drew a new trial
type, then restored `copy(app.mhbackup)` (the state at the END of the failed
trial) and skipped the task's setup block. In the rig data parameters matched,
but targets carried the failed trial's history (thousands of old `getpos`
calls) and run-time state (e.g. the pong targets' `prevx` / `xdir`), the info
box and Trellis Scope showed the newly drawn type, and the data did not say a
trial was a repeat.

Now:
- `starttrial` sets `mh.snapshotPending`; the next `setstate` (the first state,
  i.e. the end of the setup block) saves `mh.trialSnapshot`: ttype, trialnum,
  first state, targets (histories emptied), intervals, userdefined. First
  attempts only.
- MHost2: a repeat takes the snapshot's ttype (no new draw), restores targets,
  intervals and userdefined into a fresh trial object, calls `starttrial` and
  `setstate(firstState)`. No more `copy(app.mhbackup)` or field clearing there.
- `trial.repeat` (0 = first attempt, 1, 2, ...) and `trial.repeat_of` (the
  first attempt's trialnum; its own for a first attempt). `trialRecord` sets
  `repeat_of` of a first attempt from the number it is saved under, and the
  snapshot takes it after `savestate`: the first trial after a restart is
  renumbered when saved (found in testing: repeats pointed at "trial 1").
- Per-task count: the Parameters window's trial-types table has a third
  column, "Repeats if failed"; blank = the misc tab's "Repeat failed trials".
  `app.repeatLimit(mh)` looks it up (in `mh.ttypeslogic`, column 3). Under the
  table: Distribute (moved under the Occurrence column, its own row) and
  "Repeats if failed, all: [box] [Set all]" (under the Repeats column): a
  number fills every row, a blank box clears them all, anything else is
  refused. The columns and positions are set in LiveParams' `setTaskTable` /
  `startupFcn`, so App Designer's design view still shows the old layout.
- The info-box line at each trial start showed the previous trial's task (the
  Trial name field is filled later); it now prints the trial's own.

Tested in the VM, three runs (227 demo trials): limits 0 / 4 / blank (= 2),
Set all 3, all blank; every failed trial repeated until a success or its
limit, never more. All 147 repeats had the first attempt's task, userdefined,
target settings and every setup-block interval, and no carried history. The
only difference: a repeat that succeeded also holds `reward`, fetched by the
task with `getint` in its reward state; draws made while a trial runs cannot
be replayed. Not changed: whether a trial ended by STOP is repeated after the
next START.

## 14. Movie timing (2026-10-27, branch `movie-timing`)

The user's goal: know exactly which movie frame was on the screen at what
time. Part 1 (recording, tables, a test movie and a checker) is done; checking
it on a rig is next. `documentation/timing.md` has the fields, how they are
calculated, and the rig procedure (*Checking movie frames on a rig*).

- GraphicsHandler: `OpenMovie`'s fps, frame count, duration and size are kept
  (`mvInfo`, saved as `geom.movies` by `dumpdata`). On each display flip,
  `movieFrame` takes the frame's presentation time from `GetMovieImage`'s
  second output (display copy only) and `resolveArgs` logs it per movie id
  (`flipLog.movies`). Seeks / PlayMovie are logged by one-shot token
  (`flipLog.oneshots`).
- MHost2 side: `declareResource` refs carry `kind` and `name`; `mh.Screen`
  names a `DrawTexture` of a movie after it (kind `movie`, the resource id
  through `frameItems`), and logs `SetMovieTimeIndex` / `PlayMovie` as `seek`
  / `play` rows (`stimReqToken`, `stimReqValue`).
- `buildStimulusTiming` / `objectTiming`: `trial.movies.<name>` with the
  settings, `events` (on, off, seek, play) and `frames` (`movie_time_s`,
  `movie_frame = floor(pts*fps + 1e-4)+1`, `new_frame`); the flat tables get the same
  columns. A flip counts as showing the movie only if GraphicsHandler drew a
  frame of it (found in VM testing: before the first frame is decoded the draw
  draws nothing, and "on" came out 510 ms early).
- `Utilities/makeMovieTimingTest.m` writes the test movie (corner square white
  on odd frames, black on even; digits; 12-bit code). `Utilities/
  movieTimingCheck.m` compares a trial's movie frames with the photodiode
  trace.

Tested: `test_movieTiming.m` (session scratchpad), synthetic, 25/25, and
`test_trialTiming.m` 50/50. In the VM, a MovieTiming task (VM-only files:
`~/Documents/Experiment/Movies/movie_timing_test.avi`,
`Parameters/MovieTimingParameters.m`, `Tasks/MovieTiming/`; point the ini's
`[last filepaths]` at them) seeks to a random time and shows the movie 2 s,
full screen or at its own size. Every trial that drew it: frame numbers,
order, `new_frame`, rects and the flat tables right; each seek shown within
one movie frame of its target.

VM limit: GraphicsHandler flips only ~3 times per second while a movie plays
(two vCPUs at 100 %, software GL), and `main`'s GraphicsHandler is the same
(2.6 vs 2.9 flips/s). So frame cadence and the photodiode check can only be
done on a rig; in the VM `movieTimingCheck` runs but its numbers are noise
(the demo photodiode is a sine).

Found, not fixed: a parameter file with no targets crashes `makeparams`
(`fieldnames(mh.targets)` on `[]`), and cancelling the parameter-file chooser
at startup crashes `startupFcn` (`copyfile` with the 0 that `uigetfile`
returns).

**On rig2 (2026-10-27).** The user sent Claude there for this test. Rig2's
checkout was on `ai-assisted-2` plus two rig2-only commits (RewardHandler finds
ScreenParams.ini on either rig; `.gitignore` covers RigConfig.ini); it is now on
a local `movie-timing` = `8c681d6` + those two commits (not pushed), and stays
there. Test files live outside the repo in `~/Documents/movie-timing-test`
(movie, parameter file, task, data). For the test the ini pointed there,
GraphicsHandler's state square was moved off the photodiode (top-right) and
the movie drawn x3 so its corner square covered the sensor (bottom-left);
all of that was put back afterwards.
- 25 trials at 120 Hz on the real GPU: about 230 flips per 2 s of movie, each
  movie frame on screen 3.8 flips (4 expected), frame numbers, order and rects
  right. 226 of 5741 flips took over 12 ms (a refresh missed); not compared
  with a run without a movie.
- Seeks: GStreamer 1.20 reports the seek target itself as the first frame's
  time (4.53 s, not the frame start 4.50 s). `round` then numbered that frame
  one too high whenever the target was in the second half of a frame (14 of
  1515 new frames repeated a number). Fixed with `floor` + tolerance; checked
  by seeking the test movie with GStreamer on rig2 and reading the frame
  number written in the picture: `floor` matched all 10 targets, `round` was
  one high on 6.
- Not done: the photodiode check. Trellis was connected, but the NIP's analog
  inputs streamed only at 30 kS/s (1 kS/s off), so the eye and photodiode
  traces MHost2 saves were empty. Also, demo mode does not work on rig2: the
  gitignored compile output `Main code/RewardHandler/RewardHandler/
  for_redistribution_files_only/xippmex` (a real xippmex, also on rig2's saved
  MATLAB path) is re-added after `enableDemoXippmex` and shadows the mock, so
  START crashes on `app.chidx`.
