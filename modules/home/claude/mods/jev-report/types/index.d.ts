export type Pinned = { readonly asks: readonly string[] }

declare module 'claude-code' {
  interface PluginState {
    'jev-report': { pinned: Pinned | null }
  }
}
