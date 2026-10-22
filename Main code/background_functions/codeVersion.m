function [txt, info] = codeVersion(form)
%CODEVERSION Version of this copy of the code, from git, for titles and logs.
%   codeVersion('short') is for users (MHost2's title bar): the version and
%   branch only, e.g. 'v0.1.0 (ai-assisted-2)'; '(main)' when the branch has no
%   version tag yet; '' when it cannot be told.
%
%   TXT = codeVersion() is the full form for data and error logs, for example:
%       'v0.1.0 (ai-assisted-2)'                 on the tagged commit
%       'v0.1.0+4 (ai-assisted-2, 4ac2b36)'      4 commits after it
%       'untagged 4ac2b36 (main)'                no v* tag in this branch's history
%       '(version unknown)'                      no git, or not a repository
%   with '  modified' appended when tracked files differ from the commit (code
%   edited on this machine). Untracked and ignored files, such as the rig's
%   ini files, do not count.
%   [TXT, INFO] also returns the parts: tag, ahead, hash, branch, modified,
%   and both texts (text, short).
%
%   Versions follow semantic versioning and stay 0.x until the lab calls the
%   software complete (1.0.0). Nothing is bumped by hand in the code: cutting a
%   version means tagging a commit (git tag -a v0.2.0 -m "...") and pushing the
%   tag; everything else comes from "git describe" here.
%
%   Worked out once per MATLAB session and then cached, so it describes the code
%   this session loaded, which is what runs until MHost2 restarts.

persistent cache
if isempty(cache)
    cache = describeCode();
end
info = cache;
if nargin >= 1 && strcmpi(form, 'short')
    txt = info.short;
else
    txt = info.text;
end
end

function info = describeCode()
info = struct('text', '(version unknown)', 'short', '', 'tag', '', 'ahead', 0, ...
    'hash', '', 'branch', '', 'modified', false);
here = fileparts(mfilename('fullpath'));                    % .../Main code/background_functions
[ok, d] = runGit(here, 'describe --tags --match "v[0-9]*" --always --dirty --abbrev=7');
if ok
    d = strtrim(d);
    info.modified = endsWith(d, '-dirty');
    d = regexprep(d, '-dirty$', '');
    tok = regexp(d, '^(v\d.*)-(\d+)-g([0-9a-f]+)$', 'tokens', 'once');
    if ~isempty(tok)                                        % commits after a tag
        info.tag = tok{1};
        info.ahead = str2double(tok{2});
        info.hash = tok{3};
    elseif startsWith(d, 'v')                               % on the tag itself
        info.tag = d;
        [~, h] = runGit(here, 'rev-parse --short=7 HEAD');
        info.hash = strtrim(h);
    else                                                    % no tag: describe gave the hash
        info.hash = d;
    end
    [okBranch, br] = runGit(here, 'symbolic-ref --quiet --short HEAD');
    if okBranch, info.branch = strtrim(br); else, info.branch = 'detached'; end

    if isempty(info.tag)
        info.text = sprintf('untagged %s (%s)', info.hash, info.branch);
    elseif info.ahead == 0
        info.text = sprintf('%s (%s)', info.tag, info.branch);
    else
        info.text = sprintf('%s+%d (%s, %s)', info.tag, info.ahead, info.branch, info.hash);
    end
    if info.modified
        info.text = [info.text '  modified'];
    end
    info.short = strtrim([info.tag ' (' info.branch ')']);
end
end

function [ok, out] = runGit(folder, args)
% git in FOLDER, never paging: system() gives commands a terminal, so git would
% otherwise start a pager and hang. MATLAB's LD_LIBRARY_PATH is dropped first
% (its bundled libraries can break programs system() starts).
[s, out] = system(['unset LD_LIBRARY_PATH; GIT_TERMINAL_PROMPT=0 timeout 5 git --no-pager -C ''' ...
    strrep(folder, '''', '''\''''') ''' ' args ' 2>/dev/null']);
ok = s == 0;
end
