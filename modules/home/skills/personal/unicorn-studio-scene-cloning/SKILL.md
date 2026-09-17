---
name: unicorn-studio-scene-cloning
description: "Extract, configure, and mount Unicorn Studio WebGL scenes in React and TanStack Start applications"
---

# Mounting Unicorn Studio WebGL Scenes in React / TanStack Start Applications

## Procedure

1. **Extract Scene Config & UMD SDK**:
   - Extract the scene config JS object `a` (containing `id`, `history`, compiled fragment and vertex shaders, downsample, and options) from the source bundle.
   - Extract `unicornStudio.umd.js` and ensure it attaches to `window.UnicornStudio = window.UnicornStudio || exports`.

2. **Mount Scene via JSON Script Tag Injection**:
   ```tsx
   import React, { useEffect, useRef, useState, useId } from 'react';
   import { unicornConfig } from './unicorn_config';

   export const StitchBlurEffect: React.FC = () => {
     const containerRef = useRef<HTMLDivElement | null>(null);
     const sceneRef = useRef<any>(null);
     const scriptId = useId().replace(/:/g, '-');
     const [isLoaded, setIsLoaded] = useState(false);

     useEffect(() => {
       let isDestroyed = false;

       const initScene = () => {
         const el = containerRef.current;
         const unicorn = window.UnicornStudio;
         if (!el || !unicorn?.addScene || el.offsetWidth === 0 || el.offsetHeight === 0) {
           requestAnimationFrame(initScene);
           return;
         }

         let scriptTag = document.getElementById(scriptId) as HTMLScriptElement | null;
         if (!scriptTag) {
           scriptTag = document.createElement('script');
           scriptTag.id = scriptId;
           scriptTag.type = 'application/json';
           scriptTag.textContent = JSON.stringify(unicornConfig);
           document.body.appendChild(scriptTag);
         }

         unicorn.addScene({
           altText: 'Stitch',
           element: el,
           filePath: scriptId,
           production: true,
           scale: 1,
           dpi: 1.5,
           fps: 60,
           width: 1440,
           height: 900,
           lazyLoad: false,
           interactivity: { mouse: { disabled: false, disableMobile: false } },
         }).then((scene) => {
           if (isDestroyed) { scene.destroy(); return; }
           sceneRef.current = scene;
           setIsLoaded(true);
         });
       };

       initScene();

       return () => {
         isDestroyed = true;
         if (sceneRef.current) sceneRef.current.destroy();
         document.getElementById(scriptId)?.remove();
       };
     }, [scriptId]);

     // Crop math
     const baseWidth = 1440;
     const hostRef = useRef<HTMLDivElement | null>(null);
     const [scale, setScale] = useState(1);

     useEffect(() => {
       const hostEl = hostRef.current;
       if (!hostEl) return;
       const handleResize = () => setScale(hostEl.offsetWidth / baseWidth);
       handleResize();
       window.addEventListener('resize', handleResize);
       return () => window.removeEventListener('resize', handleResize);
     }, []);

     const computedHeight = 900 * scale;

     return (
       <div ref={hostRef} style={{ position: 'relative', width: '100%', height: `${computedHeight * 0.6}px`, backgroundColor: '#000', overflow: 'hidden', opacity: isLoaded ? 1 : 0, transition: 'opacity 600ms ease-in' }}>
         <div ref={containerRef} style={{ position: 'absolute', top: `${-computedHeight * 0.4}px`, left: 0, width: `${baseWidth}px`, height: '900px', transformOrigin: 'top left', transform: `scale(${scale})` }} />
       </div>
     );
   };
   ```
