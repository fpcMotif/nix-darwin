{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
      command_timeout = 1000;
      scan_timeout = 30;

      palette = "posh";
      palettes.posh = {
        base = "#1e1e2e";
        grey = "#454758";
        lavender = "#AE8FE7";
        white = "#FFFFFF";
        text = "#494D64";
        warning = "#ff8080";
      };

      format = ''
        $directory$git_branch$git_status$status
        $character
      '';

      right_format = "$time";

      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
        style = "fg:white bg:grey";
        format = "[](fg:grey)[ $path ]($style)[](fg:grey bg:lavender)";
      };

      git_branch = {
        symbol = " ";
        style = "fg:text bg:lavender";
        format = "[ $symbol$branch ]($style)";
      };

      git_status = {
        style = "fg:text bg:lavender";
        format = "[ $all_status$ahead_behind ]($style)[](fg:lavender bg:warning)";
      };

      status = {
        disabled = false;
        symbol = "";
        style = "fg:white bg:warning";
        format = "[ $symbol ]($style)[](fg:warning)";
      };

      battery = {
        full_symbol = "🔋 ";
        charging_symbol = "⚡️ ";
        discharging_symbol = "💀 ";
      };

      cmd_duration = {
        disabled = false;
        min_time = 4000;
      };

      username = {
        style_user = "white bold";
        style_root = "yellow bold";
        format = "[$user]($style)";
        disabled = false;
        show_always = true;
      };

      hostname = {
        format = ''
          @[$hostname](white)
        '';
        ssh_only = false;
        disabled = false;
      };

      time = {
        disabled = false;
        use_12hr = false;
        style = "fg:lavender";
        format = "[$time]($style)";
        time_format = "%a %b %-d %T %Z";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      profiles = {
        claude-code = "$claude_model$git_branch$claude_context$claude_cost";
      };

      claude_model = {
        symbol = "󰯉 ";
        style = "bold blue";
        format = "[$symbol$model]($style) ";
      };

      claude_context = {
        style = "bold lavender";
        format = "[$gauge $percentage]($style) ";
        gauge_width = 10;
      };

      claude_cost = {
        symbol = "$";
        style = "bold yellow";
        format = "[$symbol$cost]($style) ";
      };
    };
  };
}
