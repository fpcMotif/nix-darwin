# trail — unify + cluster Safari and Chrome-family browsing history.
# Source of truth: ~/devv/trail (https://github.com/fpcMotif/trail).
#
# fastembed (the `embed` extra / `trail cluster --method embed`) is intentionally
# NOT packaged here — it is absent from nixpkgs. The default `tfidf` method needs
# only scikit-learn, so this closure stays clean. For semantic clustering, use the
# uv project directly: `uv sync --extra embed` in ~/devv/trail.
{ lib
, python3Packages
}:

python3Packages.buildPythonApplication {
  pname = "trail";
  version = "0.1.0";
  pyproject = true;

  # Private repo: fetchFromGitHub (plain curl FOD) can't auth, so use the builtin
  # git fetcher, which honors nix's `access-tokens` setting. Pinned to the v0.1.0
  # commit for a reproducible, pure fetch.
  src = builtins.fetchGit {
    url = "https://github.com/fpcMotif/trail.git";
    ref = "refs/tags/v0.1.0";
    rev = "f541a58d35f4c703effdd9c9844fb5ff25a310eb";
  };

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    openai
    scikit-learn # propagates numpy + scipy
  ];

  pythonImportsCheck = [ "trail" ];
  doCheck = false;

  meta = {
    description = "Unify + cluster Safari and Chrome-family browsing history";
    homepage = "https://github.com/fpcMotif/trail";
    mainProgram = "trail";
    platforms = lib.platforms.darwin;
  };
}
