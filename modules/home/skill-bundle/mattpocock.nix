{ lib, inputs }:

let
  curation = import ../claude/skill-curation.nix;

  bucketIds = bucket:
    let root = inputs.mattpocock-skills + "/skills/${bucket}";
    in builtins.attrNames (lib.filterAttrs
      (name: type:
        type == "directory" && builtins.pathExists (root + "/${name}/SKILL.md"))
      (builtins.readDir root));

  upstreamIds = lib.unique (lib.concatMap bucketIds curation.mattpocockBuckets);
  excludedIds = curation.disabledMattpocockSkills ++ curation.leanExcludedMattpocockSkills;
in
{
  inherit upstreamIds;
  enabledIds = builtins.filter (id: !(builtins.elem id excludedIds)) upstreamIds;
}
