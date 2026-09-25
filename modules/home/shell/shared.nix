# Shell-neutral data both shell modules read. Each shell adds its own
# syntax-specific entries on top.
{ lib, isDarwin }:

{
  # Command shortcuts: zsh aliases, fish abbreviations.
  aliases = {
    c = "clear";
    code = "nvim";
    zed = "zeditor";
    zededitor = "zeditor";
    ks = "tmux kill-server";
    scratch = "nvim -c \"setlocal buftype=nofile\"";
    vimdiff = "nvim -d";
    wr = "wrangler";
    lc = "localcode";

    ls = "eza --icons --git --group-directories-first --hyperlink --no-quotes";
    ll = "eza -lh --icons --git --group-directories-first --hyperlink --no-quotes --color-scale=size --color-scale-mode=gradient --smart-group";
    la = "eza -la --icons --git --group-directories-first --hyperlink --no-quotes --color-scale=size --color-scale-mode=gradient --smart-group";
    lt = "eza -lT --level=2 --icons --hyperlink --no-quotes";
    tree = "eza --tree --icons --git-ignore --hyperlink --no-quotes";
    lr = "lsr -al --group-directories-first --color=auto --icons=auto --hyperlinks=auto";
    lrt = "lsr --tree --color=auto --icons=auto";
    cat = "bat --paging=never";
    preview = "bat --style=numbers --color=always";
    find = "fd";
    ps = "procs";
    top = "btm";

    down = "cd ~/Downloads";
    dev = "cd ~/Developer";
    doc = "cd ~/Documents";

    g = "git";
    gst = "git status";
    gd = "git diff";
    gds = "git diff --staged";
    gco = "git checkout";
    gcb = "git checkout -b";
    gb = "git branch";
    gbd = "git branch -d";
    gm = "git merge";
    ga = "git add";
    gaa = "git add --all";
    gc = "git commit -v";
    gcmsg = "git commit -m";
    gcam = "git commit -a -m";
    gamend = "git commit --amend";
    gl = "git pull";
    gp = "git push";
    gpsup = "git push --set-upstream origin $(git branch --show-current)";
    gpf = "git push --force-with-lease";
    glog = "git log --oneline --decorate --graph";
    glol = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'";
    gsta = "git stash push";
    gstp = "git stash pop";
    gstl = "git stash list";

    sg = "ast-grep";
    oxl = "oxlint";
    oxf = "oxfmt";
    oxfix = "oxlint --fix";
    gsp = "ghostty-split";
    gpn = "ghostty-pane";

    npm = "bun";
    npx = "bunx";
    pnpm = "bun";
    p = "bun";
    oc = "opencode";

    cct = "cmux claude-teams --dangerously-skip-permissions";
    cdx = "_codex_cli";

    obsidian = "ob";
    ob-remote = "ob sync-list-remote";
    ob-local = "ob sync-list-local";
    ob-status = "ob sync-status";
    ob-config = "ob sync-config";
    ob-sync = "ob sync";
    ob-watch = "ob sync --continuous";
    note = "notesmd-cli";
    note-daily = "notesmd-cli daily --editor";
    note-new = "notesmd-cli create --editor";
    note-find = "notesmd-cli search";
    note-find-content = "notesmd-cli search-content";
    note-ls = "notesmd-cli list";
    note-open = "notesmd-cli open --editor";
    canary-start = "~/.local/bin/canary-debug";
  } // lib.optionalAttrs isDarwin {
    pbc = "pbcopy";
    pbp = "pbpaste";
    ip = "ipconfig getifaddr en0";
    sync = "sudo darwin-rebuild switch --flake ~/nix-config";
    claude-conductor = "\"$HOME/Library/Application Support/com.conductor.app/bin/claude\"";
  };

  # TERMINFO_DIRS entries each shell puts ahead of any inherited ones.
  terminfoDirs = [
    "$HOME/.terminfo"
  ] ++ lib.optionals isDarwin [
    "/Applications/Ghostty.app/Contents/Resources/terminfo"
    "/Applications/kitty.app/Contents/Resources/kitty/terminfo"
  ] ++ [
    "/usr/share/terminfo"
  ];
}
