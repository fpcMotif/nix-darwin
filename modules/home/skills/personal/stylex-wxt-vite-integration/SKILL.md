---
name: stylex-wxt-vite-integration
description: "Configure StyleX in WXT / Vite browser extensions: multi-entrypoint CSS injection, HTML transform filter, test mocking, and segmented control layout fixes"
---

# StyleX in WXT / Vite Browser Extensions

Critical integration rules, pitfalls, and workarounds when compiling StyleX in WXT / Vite Chrome extensions.

## 1. Multi-Entrypoint CSS Injection in WXT Extensions

### Pitfall
`@stylexjs/unplugin`'s default `generateBundle` hook uses `pickCssAssetFromRollupBundle`, which picks only the **first** matching `.css` asset to inject the accumulated StyleX CSS.
In extensions with multiple HTML entrypoints (e.g., `popup` and `options`), WXT builds both entrypoints in a single Vite build. If both entrypoints produce distinct stylesheets (`popup.css` and `options.css`), StyleX injects all atomic CSS rules into only one of them, leaving the other page completely unstyled.

### Solution
Wrap `generateBundle` in the unplugin factory in `wxt.config.ts` to append the collected CSS to **all** emitted `.css` assets:
```ts
const stylexPlugin = () => {
  const plugin = stylex({
    unstable_moduleResolution: { type: "commonJS", rootDir: process.cwd() },
    aliases: { "@/*": [path.join(process.cwd(), "*")] },
    lightningcssOptions: { targets: browserslistToTargets(browserslist("chrome >= 120")) },
    devMode: "css-only",
  });
  const origTransform = plugin.transform;
  return {
    ...plugin,
    transform(code: string, id: string) {
      const cleanId = id.split("?")[0] ?? "";
      if (!/\.[jt]sx?$/.test(cleanId) || cleanId.includes("node_modules")) {
        return null;
      }
      return origTransform?.call(this, code, id);
    },
    generateBundle(_opts: unknown, bundle: Record<string, { type?: string; source?: string | Uint8Array }>) {
      const collectCss = (plugin as Record<string, unknown>)["__stylexCollectCss"] as
        | (() => string)
        | undefined;
      const css = collectCss?.();
      if (!css) return;
      for (const [fileName, asset] of Object.entries(bundle)) {
        if (asset.type === "asset" && fileName.endsWith(".css")) {
          const current = typeof asset.source === "string" ? asset.source : asset.source?.toString() || "";
          asset.source = current ? `${current}\n${css}` : css;
        }
      }
    },
  };
};
```

---

## 2. Preventing Runtime Macro Crashes (`Unexpected stylex.defineVars call at runtime`)

### Pitfall
StyleX's `stylex.defineVars()` and `stylex.create()` are compiler macros that throw at runtime if evaluated raw in a browser or test runner:
```
Error: Unexpected 'stylex.defineVars' call at runtime. Styles must be compiled by '@stylexjs/babel-plugin'.
```

### Solution
- In Vite / WXT, ensure the Babel plugin runs on all files defining or consuming StyleX.
- In test runners (`vitest` with `jsdom`), mock `@stylexjs/stylex` in `vitest.setup.ts`:
```ts
vi.mock("@stylexjs/stylex", () => ({
  create: (styles: Record<string, unknown>) => styles,
  props: () => ({}),
  defineVars: (vars: Record<string, unknown>) => vars,
  keyframes: () => "mock-keyframes",
}));
```

---

## 3. Segmented Controls & `<fieldset>` Layout in Chromium

### Pitfall 1: Zero Height and Sibling Overlap
In Chromium / Blink, `<fieldset>` defaults to `min-inline-size: min-content`. In flex containers, if `<fieldset>` lacks `min-inline-size: 0`, the layout height can collapse or fail to properly push subsequent siblings, causing the next heading or element to visually overlap the segmented toggle.
**Fix**: Always declare `minInlineSize: 0` and `margin: 0` on `<fieldset>` flex containers.

### Pitfall 2: Outline Protrusion Past Pill Containers
By CSS specification, `outline` is drawn outside the border box and is **never clipped by `overflow: hidden`** on parent containers.
If child buttons have `outline: ...` with a positive `outline-offset: 2px` (especially on mouse `:focus`), the outline will protrude outside the rounded corners of the segmented pill.
**Fix**: Set `outline: "none"` on buttons for mouse focus, and apply an **inset** outline on `:focus-visible` for keyboard navigation:
```ts
":focus-visible": {
  outline: `2px solid ${tokens["--primary"]}`,
  outlineOffset: -2,
}
```
