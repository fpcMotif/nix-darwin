# Re-evaluates a host with another workspace backend for one user, the way that
# user would select it in their Home Manager configuration.
{ configuration, user, backend }:

configuration.extendModules {
  modules = [{ home-manager.users.${user}.martin.development.workspaceBackend = backend; }];
}
