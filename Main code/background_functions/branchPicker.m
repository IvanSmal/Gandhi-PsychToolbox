function branchPicker(mainFig, isBusy)
%BRANCHPICKER Switch this copy of the code to another Git branch and restart MHost2 on it.
%   branchPicker(MAINFIG, ISBUSY) opens the Switch Branch window (MHost2's
%   File > Switch Branch): every branch on this computer and on GitHub
%   (origin), newest first, refreshed from GitHub when it opens. MAINFIG is
%   MHost2's figure; ISBUSY returns true while trials run, and switching is
%   refused then.
%
%   Every check runs here first, so a refused switch changes nothing. Then
%   MHost2 closes the normal way (its close request saves state, stops
%   GraphicsHandler and quits MATLAB), and only after that does a terminal
%   change branch and start MHost2 again. That order means MHost2 never runs,
%   or closes, with another branch's files on disk.
%
%   - Files git ignores here (ScreenParams.ini, FilePaths.ini, ...) are never
%     overwritten. A branch that has its own copy of one is refused: git's
%     default would silently replace the rig's file and delete it on the way
%     back. The terminal also switches with --no-overwrite-ignore.
%   - Uncommitted changes to tracked files: set them aside (git stash, see
%     "git stash list"), carry them over (only if the branch does not change
%     those files), or cancel.
%   - A branch that is only behind GitHub is brought up to date (fast-forward);
%     one with commits that are not on GitHub is switched to as it is.
%   - Only plain branch names (letters, digits, . _ / -) can be picked: the
%     name ends up in a shell command.
%
%   Only branches that include this file have the menu. After switching to an
%   older branch, use git to come back.

if ~isunix || ismac
    uialert(mainFig, 'Switching branches is only supported on Linux.', 'Switch Branch');
    return
end
if isBusy()
    uialert(mainFig, 'Stop the trials before switching branches.', 'Switch Branch');
    return
end

here = fileparts(mfilename('fullpath'));                    % .../Main code/background_functions
mainCode = fileparts(here);
[ok, repo] = runGit(mainCode, 'rev-parse --show-toplevel');
if ~ok
    uialert(mainFig, sprintf('This copy of the code is not a Git repository:\n%s', repo), 'Switch Branch');
    return
end
repo = strtrim(repo);

branches = struct([]);
current = '';
sel = [];

fig = uifigure('Name', 'Switch Branch', 'Position', [100 100 820 460]);
try, fig.WindowStyle = 'modal'; catch, end
try, movegui(fig, 'center'); catch, end
g = uigridlayout(fig, [4 1], 'RowHeight', {22, 22, '1x', 30}, 'RowSpacing', 6);
curLbl = uilabel(g, 'FontWeight', 'bold');
stLbl  = uilabel(g, 'FontColor', [0.4 0.4 0.4]);
tbl = uitable(g, 'ColumnName', {'', 'Branch', 'Last change', 'Status', 'Description'}, ...
    'ColumnWidth', {22, 160, 85, 240, 'auto'}, 'RowName', {}, 'ColumnEditable', false);
try, tbl.ColumnWidth{5} = '1x'; catch, end           % fill, no sideways scrolling (R2021a+)
try, tbl.SelectionType = 'row'; tbl.Multiselect = 'off'; catch, end
tbl.CellSelectionCallback = @onSelect;
bg = uigridlayout(g, [1 4], 'ColumnWidth', {150, '1x', 100, 150}, 'Padding', [0 0 0 0]);
refreshBtn = uibutton(bg, 'Text', 'Refresh from GitHub', 'ButtonPushedFcn', @(~,~) refresh(true));
uilabel(bg, 'Text', '');
uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~,~) delete(fig));
switchBtn = uibutton(bg, 'Text', 'Switch and restart', 'Enable', 'off', ...
    'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) doSwitch());

refresh(false);          % what this computer already knows, at once
drawnow;
refresh(true);           % then ask GitHub

    function refresh(fetch)
        if fetch
            if isBusy()
                stLbl.Text = 'Trials are running: not checking GitHub now.';
            else
                stLbl.Text = 'Checking GitHub...';
                refreshBtn.Enable = 'off';
                drawnow;
                [okFetch, msg] = runGit(repo, 'fetch --prune --quiet origin', 30);
                if ~isvalid(fig), return, end
                refreshBtn.Enable = 'on';
                if okFetch
                    stLbl.Text = ['Branch list from GitHub, ' char(datetime('now', 'Format', 'HH:mm')) '.'];
                else
                    stLbl.Text = ['Could not reach GitHub, showing the last known list: ' firstLine(msg)];
                end
            end
        else
            stLbl.Text = 'Branches known on this computer.';
        end
        [branches, current, sha] = listBranches(repo);
        if isempty(current)
            curLbl.Text = sprintf('Not on a branch (detached at %s). Pick one, then Switch and restart.', sha);
        else
            curLbl.Text = sprintf('On %s at %s. Pick a branch, then Switch and restart.', current, sha);
        end
        n = numel(branches);
        data = cell(n, 5);
        for k = 1:n
            b = branches(k);
            mark = '';
            if b.isCurrent, mark = char(9679); end          % filled circle
            data(k, :) = {mark, b.name, b.date, b.status, b.subject};
        end
        tbl.Data = data;
        try
            removeStyle(tbl);
            k = find([branches.isCurrent]);
            if ~isempty(k), addStyle(tbl, uistyle('FontWeight', 'bold'), 'row', k); end
        catch
        end
        sel = [];
        try, tbl.Selection = []; catch, end
        switchBtn.Enable = 'off';
    end

    function onSelect(~, e)
        sel = [];
        if ~isempty(e.Indices) && e.Indices(1, 1) <= numel(branches)
            sel = e.Indices(1, 1);
        end
        if ~isempty(sel) && ~branches(sel).isCurrent && branches(sel).valid
            switchBtn.Enable = 'on';
        else
            switchBtn.Enable = 'off';
        end
    end

    function doSwitch()
        if isempty(sel), return, end
        b = branches(sel);
        if isBusy()
            uialert(fig, 'Stop the trials before switching branches.', 'Switch Branch');
            return
        end

        % files the branch has that this commit does not, already here as
        % untracked or ignored files (rig settings and the like)
        [~, out] = runGit(repo, ['-c core.quotepath=off diff --name-only --no-renames --diff-filter=A HEAD ' b.target]);
        added = splitOut(out);
        clash = added(cellfun(@(f) isfile(fullfile(repo, f)), added));
        if ~isempty(clash)
            uialert(fig, sprintf(['%s has its own copy of these files, which on this computer are ' ...
                'kept out of git (rig settings and the like). Switching would replace them, ' ...
                'so it is refused:\n\n%s'], b.name, bullets(clash)), 'Switch Branch');
            return
        end

        % uncommitted changes to tracked files
        [~, out] = runGit(repo, '-c core.quotepath=off diff --name-only HEAD');
        changed = splitOut(out);
        stash = false;
        if ~isempty(changed)
            choice = uiconfirm(fig, sprintf(['These files have changes that are not committed:\n\n%s\n\n' ...
                'Set aside: git keeps them (git stash list) and %s starts with clean files.\n' ...
                'Carry over: the changes come with you to %s.'], bullets(changed), b.name, b.name), ...
                'Uncommitted changes', 'Options', {'Set aside and switch', 'Carry them over', 'Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 3, 'Icon', 'warning');
            switch choice
                case 'Set aside and switch'
                    stash = true;
                case 'Carry them over'
                    [~, out] = runGit(repo, ['-c core.quotepath=off diff --name-only --no-renames HEAD ' b.target]);
                    both = intersect(changed, splitOut(out));
                    if ~isempty(both)
                        uialert(fig, sprintf(['%s has different versions of these changed files, ' ...
                            'so the changes cannot come along. Set them aside instead.\n\n%s'], ...
                            b.name, bullets(both)), 'Switch Branch');
                        return
                    end
                otherwise
                    return
            end
        end

        extra = '';
        if b.ff
            extra = sprintf('\n\nIt is first brought up to date with GitHub: %s.', commits(b.behind, 'new'));
        elseif ~b.isLocal
            extra = sprintf('\n\nIt is copied from GitHub.');
        end
        if stash
            extra = [extra sprintf('\n\nYour uncommitted changes are set aside first (git stash).')];
        end
        choice = uiconfirm(fig, sprintf(['MHost2 will close (as when you close it), switch to %s, ' ...
            'and start again on it in a new terminal. GraphicsHandler restarts with it.%s'], b.name, extra), ...
            'Switch Branch', 'Options', {'Switch and restart', 'Cancel'}, 'DefaultOption', 1, 'CancelOption', 2);
        if ~strcmp(choice, 'Switch and restart'), return, end

        % a terminal waits for this MATLAB to exit, switches, starts MHost2
        from = current;
        if isempty(from) || ~validName(from), from = 'the previous commit'; end
        script = writeScript(repo, mainCode, b, stash, from, feature('getpid'));
        [s, msg] = system(['unset LD_LIBRARY_PATH; gnome-terminal --title=MHost2 -- sh ' shq(script) ' 2>&1']);
        if s ~= 0
            try, delete(script); catch, end
            uialert(fig, sprintf('Could not open a terminal, nothing was switched:\n%s', msg), 'Switch Branch');
            return
        end
        delete(fig);
        close(mainFig);          % MHost2's close request: saves state, stops GraphicsHandler, quits
    end
end

function [b, current, sha] = listBranches(repo)
% Local branches and origin's, one row per name, newest first.
fmt = '%(refname)%09%(objectname:short)%09%(committerdate:short)%09%(subject)';
[~, out] = runGit(repo, ['for-each-ref --format=''' fmt ''' refs/heads refs/remotes/origin']);
loc = struct('name', {}, 'date', {}, 'subject', {});
gh = loc;                                                    % origin's
for ln = splitOut(out)'
    f = strsplit(ln{1}, char(9), 'CollapseDelimiters', false);
    if numel(f) < 4, continue, end
    r = struct('name', '', 'date', f{3}, 'subject', strjoin(f(4:end), ' '));
    if startsWith(f{1}, 'refs/heads/')
        r.name = extractAfter(f{1}, 'refs/heads/');
        loc(end+1) = r; %#ok<AGROW>
    elseif startsWith(f{1}, 'refs/remotes/origin/')
        r.name = extractAfter(f{1}, 'refs/remotes/origin/');
        if ~strcmp(r.name, 'HEAD'), gh(end+1) = r; end %#ok<AGROW>
    end
end

[okCur, current] = runGit(repo, 'symbolic-ref --quiet --short HEAD');
current = strtrim(current);
if ~okCur, current = ''; end
[~, sha] = runGit(repo, 'rev-parse --short HEAD');
sha = strtrim(sha);

b = struct('name', {}, 'date', {}, 'subject', {}, 'status', {}, 'target', {}, ...
    'isLocal', {}, 'ff', {}, 'behind', {}, 'isCurrent', {}, 'valid', {});
for k = 1:numel(loc)
    r = loc(k);
    e = branchRow(r, true);
    j = find(strcmp({gh.name}, r.name), 1);
    if isempty(j)
        e.status = 'only on this computer';
    elseif e.valid
        [~, out] = runGit(repo, ['rev-list --left-right --count refs/heads/' r.name '...refs/remotes/origin/' r.name]);
        n = sscanf(out, '%d');
        if numel(n) == 2
            ahead = n(1); e.behind = n(2);
            if ahead == 0 && e.behind == 0
                e.status = 'same as GitHub';
            elseif ahead == 0
                e.status = sprintf('%d behind GitHub: will update', e.behind);
                e.ff = true;
                e.target = ['refs/remotes/origin/' r.name];
                e.date = gh(j).date;
                e.subject = gh(j).subject;
            elseif e.behind == 0
                e.status = [commits(ahead) ' not on GitHub'];
            else
                e.status = sprintf('%d not on GitHub, %d behind', ahead, e.behind);
            end
        end
    end
    e.isCurrent = strcmp(r.name, current);
    if e.isCurrent, e.status = ['current, ' e.status]; end
    b(end+1) = e; %#ok<AGROW>
end
for k = 1:numel(gh)
    if any(strcmp({loc.name}, gh(k).name)), continue, end
    e = branchRow(gh(k), false);
    e.status = 'on GitHub';
    b(end+1) = e; %#ok<AGROW>
end
for k = 1:numel(b)
    if ~b(k).valid, b(k).status = [b(k).status ' (unusual name, cannot pick)']; end
end
if ~isempty(b)
    [~, order] = sort({b.date});
    b = b(fliplr(order));
end
end

function e = branchRow(r, isLocal)
e = struct('name', r.name, 'date', r.date, 'subject', r.subject, 'status', '', ...
    'target', '', 'isLocal', isLocal, 'ff', false, 'behind', 0, ...
    'isCurrent', false, 'valid', validName(r.name));
if isLocal
    e.target = ['refs/heads/' r.name];
else
    e.target = ['refs/remotes/origin/' r.name];
end
end

function f = writeScript(repo, mainCode, b, stash, from, pid)
% The sh script the terminal runs: wait for MHost2's MATLAB to exit, switch,
% start MHost2 again. Everything it needs is in it: after the switch the
% repo may hold another branch's files.
f = [tempname '_switch_branch.sh'];
if b.isLocal
    sw = ['git switch --no-overwrite-ignore ' b.name];
else
    sw = ['git switch --no-overwrite-ignore --track origin/' b.name];
end
L = {
    '#!/bin/sh'
    '# Written by branchPicker (MHost2: File > Switch Branch). Deletes itself.'
    'rm -f "$0"'
    'unset LD_LIBRARY_PATH'
    'export GIT_TERMINAL_PROMPT=0 GIT_PAGER=cat'
    ['cd ' shq(repo) ' || exit 1']
    'echo "Waiting for MHost2 to close..."'
    'i=0'
    sprintf('while kill -0 %d 2>/dev/null; do', pid)
    '  i=$((i+1))'
    '  if [ $i -gt 240 ]; then'
    '    echo "MHost2 is still running after 2 minutes, so the branch was not switched."'
    '    printf "Press Enter to close. "; read _; exit 1'
    '  fi'
    '  sleep 0.5'
    'done'
    'ok=1; stashed=0'
    };
if stash
    msg = sprintf('branchPicker: set aside on %s before switching to %s (%s)', from, b.name, ...
        char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')));
    L{end+1} = ['if git stash push -m ' shq(msg) '; then stashed=1; else ok=0; fi'];
end
L{end+1} = ['[ $ok = 1 ] && { ' sw ' || ok=0; }'];
if b.ff
    L{end+1} = ['[ $ok = 1 ] && { git merge --ff-only --no-overwrite-ignore origin/' b.name ...
        ' || echo "Could not update ' b.name ' from GitHub; it starts as it was."; }'];
end
L = [L; {
    'echo'
    'if [ $ok = 1 ]; then'
    '  echo "Now on $(git branch --show-current): $(git log -1 --format=''%h %cd %s'' --date=short)"'
    '  [ $stashed = 1 ] && echo "Your uncommitted changes were set aside: git stash list (git stash pop brings them back)."'
    'else'
    '  [ $stashed = 1 ] && git stash pop'
    ['  echo "SWITCH FAILED (see above). Still on ' from '."']
    '  printf "Press Enter to start MHost2 again. "; read _'
    'fi'
    ['cd ' shq(mainCode) ' && matlab -nodesktop -nosplash -r MHost2']
    'echo; printf "MHost2 has exited. Press Enter to close. "; read _'
    }];
fid = fopen(f, 'w');
fprintf(fid, '%s\n', L{:});
fclose(fid);
end

function [ok, out] = runGit(repo, args, timeoutSec)
% git in REPO, never prompting or paging. system() gives commands a terminal,
% so without --no-pager "git diff" starts a pager and hangs. MATLAB's
% LD_LIBRARY_PATH is dropped first: its bundled libraries can break programs
% system() starts (see windowIdentity).
if nargin < 3, timeoutSec = 15; end
[s, out] = system(sprintf('unset LD_LIBRARY_PATH; GIT_TERMINAL_PROMPT=0 timeout %d git --no-pager -C %s %s 2>&1', ...
    timeoutSec, shq(repo), args));
ok = s == 0;
end

function tf = validName(n)
tf = ~isempty(regexp(n, '^[A-Za-z0-9._/-]+$', 'once')) && ~startsWith(n, '-');
end

function s = shq(s)
% S in single quotes for sh.
s = ['''' strrep(s, '''', '''\''''') ''''];
end

function c = splitOut(out)
c = strtrim(splitlines(string(out)));
c = cellstr(c(c ~= ""));
end

function s = bullets(c)
n = numel(c);
c = strcat({'    '}, c(1:min(n, 12)));
s = strjoin(c(:)', newline);
if n > 12, s = sprintf('%s\n    ... and %d more', s, n - 12); end
end

function s = commits(n, word)
% '1 commit', '3 new commits'
if nargin < 2, word = ''; else, word = [word ' ']; end
s = sprintf('%d %scommit', n, word);
if n ~= 1, s = [s 's']; end
end

function s = firstLine(msg)
c = splitOut(msg);
if isempty(c), s = ''; else, s = c{1}; end
end
