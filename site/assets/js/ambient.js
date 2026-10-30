/*
  POCHLAND · entorno ambiental de fondo
  ------------------------------------
  Un motor Canvas 2D ligero comparte el lenguaje visual y el sprite del juego
  Godot. Poch acompaña al cursor por todo el portafolio, recoge paquetes y
  reacciona a los bugs. El build Godot completo se precarga aparte y sigue
  viviendo en su sección.
*/

(function () {
  "use strict";

  const byId = (id) => document.getElementById(id);

  const boot = byId("ambient-boot");
  const canvas = byId("ambient-canvas");
  const hud = byId("ambient-hud");

  if (!boot || !canvas || !hud) {
    return;
  }

  const bootFill = byId("ambient-boot-fill");
  const bootPct = byId("ambient-boot-pct");
  const bootStatus = byId("ambient-boot-status");
  const bootSkip = byId("ambient-boot-skip");
  const signalFill = byId("ambient-signal-fill");
  const signalBar = byId("ambient-signal-bar");
  const signalValue = byId("ambient-signal-value");
  const packetsValue = byId("ambient-packets");
  const stateLabel = byId("ambient-state");
  const pauseButton = byId("ambient-pause");
  const hudToggle = byId("ambient-hud-toggle");
  const hudDot = byId("ambient-hud-dot");
  const hudBrief = byId("ambient-hud-brief");
  const hudProgressFill = byId("ambient-hud-progress-fill");
  const preloadBox = byId("ambient-preload");
  const preloadBar = byId("ambient-preload-bar");
  const preloadFill = byId("ambient-preload-fill");
  const preloadState = byId("ambient-preload-state");
  const preloadNote = byId("ambient-preload-note");
  const gameSection = byId("jugar");
  const gameMount = byId("game-mount");

  const reduceMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  let prefersReducedMotion = reduceMotionQuery.matches;

  const ASSETS = [
    ["bg", "assets/img/ambient/bg.png"],
    ["sprite", "assets/img/poch-sheet.png"],
    ["tile", "assets/img/ambient/platform-tile.png"],
    ["capL", "assets/img/ambient/platform-cap-l.png"],
    ["capR", "assets/img/ambient/platform-cap-r.png"],
    ["bug", "assets/img/ambient/bug.png"],
    ["packet", "assets/img/ambient/packet.png"],
    ["crate", "assets/img/ambient/crate.png"],
    ["glow", "assets/img/ambient/glow.png"],
  ];

  const images = {};
  let assetsLoaded = 0;
  let assetsReady = false;
  let fontsReady = false;
  let bootDone = false;
  let bootStartedAt = performance.now();
  let bootSeen = false;
  try {
    bootSeen = sessionStorage.getItem("poch-boot-seen") === "1";
  } catch (error) {
    bootSeen = false;
  }
  const MIN_BOOT = bootSeen ? 320 : 700;
  let preloadScheduled = false;
  let preloadStarted = false;
  let preloadAbort = null;
  let userPaused = prefersReducedMotion;
  let ambient = null;

  // Red de seguridad: nunca dejar la portada bloqueada por una intro.
  window.setTimeout(function () {
    document.body.classList.remove("is-booting");
    if (boot && !boot.classList.contains("is-hiding")) {
      boot.classList.add("is-hiding");
      boot.style.display = "none";
      boot.setAttribute("aria-hidden", "true");
    }
    if (ambient) {
      ambient.start();
    }
  }, 4500);

  document.body.classList.add("is-booting");

  function setBootProgress(percent, label) {
    const value = Math.max(0, Math.min(100, Math.round(percent)));
    if (bootFill) bootFill.style.width = value + "%";
    if (bootPct) bootPct.textContent = value + "%";
    if (label && bootStatus) bootStatus.textContent = label;
  }

  function loadImage(src) {
    return new Promise(function (resolve) {
      const img = new Image();
      img.decoding = "async";
      img.onload = function () {
        resolve(img);
      };
      img.onerror = function () {
        resolve(null);
      };
      img.src = src;
    });
  }

  function loadAmbientAssets() {
    let settled = 0;
    const total = ASSETS.length;

    ASSETS.forEach(function (entry) {
      loadImage(entry[1]).then(function (img) {
        if (img) images[entry[0]] = img;
        settled += 1;
        const progress = 6 + (settled / total) * 86;
        setBootProgress(progress, settled === total ? "Afinando la señal" : "Cargando el mundo");
        if (settled === total) {
          assetsReady = true;
          if (ambient) ambient.assetsReady();
          tryFinishBoot();
        }
      });
    });

    if (document.fonts && document.fonts.ready) {
      Promise.race([
        document.fonts.ready,
        new Promise(function (resolve) {
          window.setTimeout(resolve, 1100);
        }),
      ]).then(function () {
        fontsReady = true;
        tryFinishBoot();
      });
    } else {
      fontsReady = true;
    }
  }

  function tryFinishBoot() {
    if (bootDone || !assetsReady || !fontsReady) return;
    const elapsed = performance.now() - bootStartedAt;
    if (elapsed < MIN_BOOT) {
      window.setTimeout(tryFinishBoot, MIN_BOOT - elapsed);
      return;
    }
    finishBoot(false);
  }

  function finishBoot(forced) {
    if (bootDone) return;
    bootDone = true;
    setBootProgress(100, forced ? "Entrando" : "Mundo listo");

    const hide = function () {
      boot.classList.add("is-hiding");
      document.body.classList.remove("is-booting");
      if (ambient) ambient.start();
      schedulePreload();
      try {
        sessionStorage.setItem("poch-boot-seen", "1");
      } catch (error) {
        /* almacenamiento no disponible */
      }
      window.setTimeout(function () {
        boot.style.display = "none";
        boot.setAttribute("aria-hidden", "true");
      }, 380);
    };

    if (forced) {
      hide();
    } else {
      window.setTimeout(hide, 150);
    }
  }

  if (bootSkip) {
    bootSkip.addEventListener("click", function () {
      finishBoot(true);
    });
  }

  const MAP_W = 640;
  const MAP_H = 360;
  const MAP_GRAVITY = 1500;
  const MAP_JUMP = -470;
  const MAP_RUN = 128;

  const MAP_PLATFORMS = [
    { id: "G0", x: 0, w: 205, y: 330, oneWay: false },
    { id: "G1", x: 245, w: 200, y: 330, oneWay: false },
    { id: "G2", x: 480, w: 160, y: 330, oneWay: false },
    { id: "L1", x: 300, w: 100, y: 288, oneWay: true },
    { id: "L2", x: 180, w: 90, y: 246, oneWay: true },
    { id: "L3", x: 60, w: 100, y: 204, oneWay: true },
    { id: "L4", x: 210, w: 100, y: 162, oneWay: true },
    { id: "R1", x: 500, w: 100, y: 288, oneWay: true },
    { id: "R2", x: 420, w: 90, y: 246, oneWay: true },
    { id: "R3", x: 520, w: 90, y: 204, oneWay: true },
    { id: "R4", x: 430, w: 90, y: 162, oneWay: true },
    { id: "M1", x: 340, w: 90, y: 120, oneWay: true },
    { id: "M2", x: 250, w: 80, y: 78, oneWay: true },
  ];

  const MAP_PACKETS = [
    [112, 184],
    [476, 142],
    [390, 100],
    [60, 306],
    [465, 226],
    [260, 142],
  ];

  const MAP_BUGS = [
    { platform: 12, x: 285, dir: 1, speed: 25 },
    { platform: 5, x: 140, dir: -1, speed: 22 },
    { platform: 8, x: 480, dir: 1, speed: 28 },
    { platform: 2, x: 540, dir: -1, speed: 20 },
  ];

  const MAP_CRATES = [
    { platform: 1, x: 405 },
    { platform: 3, x: 350 },
    { platform: 8, x: 488 },
  ];

  function clampValue(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function moveTowardValue(from, to, delta) {
    if (Math.abs(to - from) <= delta) return to;
    return from + Math.sign(to - from) * delta;
  }

  class AmbientWorld {
    constructor() {
      this.ctx = canvas.getContext("2d", { alpha: true });
      this.w = 0;
      this.h = 0;
      this.dpr = 1;
      this.scale = 1;
      this.viewW = 640;
      this.viewH = 360;
      this.cameraX = 320;
      this.cameraY = 180;
      this.offsetX = 0;
      this.offsetY = 0;
      this.time = 0;
      this.lastFrame = 0;
      this.raf = 0;
      this.started = false;
      this.pointer = { x: 0, y: 0 };
      this.hasPointer = false;
      this.targetWorld = { x: 350, y: 288 };
      this.idleWorld = { x: 350, y: 288 };

      this.platforms = [];
      this.adj = [];
      this.edges = new Map();
      this.player = {
        x: 333,
        y: 330,
        vx: 0,
        vy: 0,
        facing: 1,
        airborne: false,
        platform: 1,
        path: [],
        goal: 1,
        targetX: 333,
        planTimer: 0,
        stun: 0,
        invuln: 0,
        dodgeCooldown: 0,
        ignoreOneWay: 0,
        squash: 0,
        anim: 0,
      };
      this.packets = [];
      this.bugs = [];
      this.crates = [];
      this.particles = [];
      this.trail = [];
      this.signal = 0;
      this.packetCount = 0;
      this.lastHudUpdate = 0;
      this.lastTrail = 0;
      this.lastDust = 0;
      this.gameInView = false;
      this.footerVisible = false;
      this.userPaused = userPaused;
      this.reducedDefault = prefersReducedMotion;
      this.hasManuallyToggled = false;
      this.hudOpen = false;

      this.buildWorld();
      this.bindEvents();
      this.resize();
      this.setHudOpen(false);
      this.syncHudState();

      if (this.userPaused) this.draw();
    }

    /* ------------------------------------------------------------------
       Mundo
       ------------------------------------------------------------------ */

    buildWorld() {
      this.platforms = MAP_PLATFORMS.map((p) => ({
        id: p.id,
        x1: p.x,
        x2: p.x + p.w,
        y: p.y,
        oneWay: p.oneWay,
      }));
      this.buildGraph();

      this.packets = MAP_PACKETS.map((pt, index) => ({
        x: pt[0],
        y: pt[1],
        baseY: pt[1],
        phase: index * 1.7,
        active: true,
        timer: 0,
        respawn: 8,
      }));

      this.bugs = MAP_BUGS.map((def, index) => {
        const plat = this.platforms[def.platform];
        return {
          platform: def.platform,
          x: clampValue(def.x, plat.x1 + 18, plat.x2 - 18),
          min: plat.x1 + 18,
          max: plat.x2 - 18,
          y: plat.y,
          dir: def.dir,
          speed: def.speed,
          phase: index * 1.4,
        };
      });

      this.crates = MAP_CRATES.map((def) => {
        const plat = this.platforms[def.platform];
        return {
          platform: def.platform,
          x: def.x,
          y: plat.y,
          broken: false,
          timer: 0,
        };
      });
    }

    buildGraph() {
      const n = this.platforms.length;
      this.adj = Array.from({ length: n }, () => []);
      this.edges = new Map();

      for (let i = 0; i < n; i += 1) {
        for (let j = 0; j < n; j += 1) {
          if (i === j) continue;
          const edge = this.makeEdge(i, j);
          if (!edge) continue;
          const key = i + ":" + j;
          const previous = this.edges.get(key);
          if (!previous || edge.weight < previous.weight) {
            this.edges.set(key, edge);
          }
        }
      }

      this.edges.forEach((edge) => {
        this.adj[edge.from].push(edge);
      });
    }

    timeUp(dy) {
      const disc = MAP_JUMP * MAP_JUMP - 2 * MAP_GRAVITY * dy;
      return (Math.abs(MAP_JUMP) + Math.sqrt(Math.max(0, disc))) / MAP_GRAVITY;
    }

    horizontalGap(a, b) {
      return Math.max(0, Math.max(a.x1, b.x1) - Math.min(a.x2, b.x2));
    }

    makeEdge(i, j) {
      const a = this.platforms[i];
      const b = this.platforms[j];
      const dy = a.y - b.y;
      const edge = {
        from: i,
        to: j,
        kind: "up",
        takeoff: 0,
        land: 0,
        vx: 0,
        vy: MAP_JUMP,
        weight: 0,
      };

      if (Math.abs(dy) <= 4) {
        const gap = this.horizontalGap(a, b);
        if (gap > 72 || gap <= 0.1) return null;
        const dir = Math.sign(b.x1 + (b.x2 - b.x1) / 2 - (a.x1 + (a.x2 - a.x1) / 2)) || 1;
        const takeoff = dir > 0 ? a.x2 - 7 : a.x1 + 7;
        const land = dir > 0 ? b.x1 + 10 : b.x2 - 10;
        const dx = land - takeoff;
        const t = (2 * Math.abs(MAP_JUMP)) / MAP_GRAVITY;
        const vx = dx / t;
        if (Math.abs(vx) > 152) return null;
        edge.kind = "level";
        edge.takeoff = takeoff;
        edge.land = land;
        edge.vx = vx;
        edge.vy = MAP_JUMP;
        edge.weight = Math.abs(dx) + 8;
        return edge;
      }

      if (dy > 0) {
        if (dy > 58) return null;
        const overlapA = Math.max(a.x1, b.x1);
        const overlapB = Math.min(a.x2, b.x2);
        let takeoff;
        let land;
        let vx = 0;

        if (overlapB - overlapA >= 14) {
          takeoff = clampValue((overlapA + overlapB) / 2, a.x1 + 8, a.x2 - 8);
          land = clampValue(takeoff, b.x1 + 10, b.x2 - 10);
        } else {
          let dir = Math.sign(b.x1 + (b.x2 - b.x1) / 2 - (a.x1 + (a.x2 - a.x1) / 2));
          if (!dir) dir = 1;
          takeoff = dir > 0 ? a.x2 - 7 : a.x1 + 7;
          land = dir > 0 ? b.x1 + 10 : b.x2 - 10;
          const t = this.timeUp(dy);
          vx = (land - takeoff) / t;
          if (Math.abs(vx) > 152) return null;
        }

        edge.kind = "up";
        edge.takeoff = takeoff;
        edge.land = land;
        edge.vx = vx;
        edge.vy = MAP_JUMP;
        edge.weight = Math.abs(land - takeoff) + dy * 1.15 + 8;
        return edge;
      }

      const drop = -dy;
      if (drop > 300) return null;
      const overlapA = Math.max(a.x1, b.x1);
      const overlapB = Math.min(a.x2, b.x2);

      if (overlapB - overlapA >= 12) {
        const takeoff = clampValue((overlapA + overlapB) / 2, a.x1 + 8, a.x2 - 8);
        const land = clampValue(takeoff, b.x1 + 10, b.x2 - 10);
        edge.kind = "drop";
        edge.takeoff = takeoff;
        edge.land = land;
        edge.vx = 0;
        edge.vy = 0;
        edge.weight = drop * 0.8 + 10;
        return edge;
      }

      let dir = Math.sign(b.x1 + (b.x2 - b.x1) / 2 - (a.x1 + (a.x2 - a.x1) / 2));
      if (!dir) return null;
      const takeoff = dir > 0 ? a.x2 - 5 : a.x1 + 5;
      const land = dir > 0 ? b.x1 + 10 : b.x2 - 10;
      const distance = Math.abs(land - takeoff);
      const fallTime = Math.sqrt((2 * drop) / MAP_GRAVITY);
      if (distance > fallTime * MAP_RUN + 12) return null;
      edge.kind = "fall";
      edge.takeoff = takeoff;
      edge.land = land;
      edge.vx = clampValue(distance / fallTime, 0, MAP_RUN) * dir;
      edge.vy = 0;
      edge.weight = distance + drop * 0.7 + 12;
      return edge;
    }

    edgeFor(from, to) {
      return this.edges.get(from + ":" + to) || null;
    }

    platformIndexAt(x, y) {
      let best = -1;
      let bestDy = 7;
      for (let i = 0; i < this.platforms.length; i += 1) {
        const p = this.platforms[i];
        if (x < p.x1 - 1 || x > p.x2 + 1) continue;
        const d = Math.abs(y - p.y);
        if (d < bestDy) {
          bestDy = d;
          best = i;
        }
      }
      return best;
    }

    plan() {
      const player = this.player;
      const n = this.platforms.length;
      let from = player.platform;
      if (from < 0 || from >= n) {
        let best = 0;
        let bestD = Infinity;
        for (let i = 0; i < n; i += 1) {
          const p = this.platforms[i];
          const qx = clampValue(this.targetWorld.x, p.x1 + 8, p.x2 - 8);
          const d = Math.hypot(qx - this.targetWorld.x, p.y - this.targetWorld.y);
          if (d < bestD) {
            bestD = d;
            best = i;
          }
        }
        from = best;
        player.platform = from;
      }

      const dist = new Array(n).fill(Infinity);
      const prev = new Array(n).fill(-1);
      const used = new Array(n).fill(false);
      dist[from] = 0;

      for (let step = 0; step < n; step += 1) {
        let u = -1;
        let best = Infinity;
        for (let i = 0; i < n; i += 1) {
          if (!used[i] && dist[i] < best) {
            best = dist[i];
            u = i;
          }
        }
        if (u === -1) break;
        used[u] = true;
        const edges = this.adj[u] || [];
        for (let k = 0; k < edges.length; k += 1) {
          const edge = edges[k];
          const nd = dist[u] + edge.weight;
          if (nd < dist[edge.to]) {
            dist[edge.to] = nd;
            prev[edge.to] = u;
          }
        }
      }

      let goal = from;
      let targetX = clampValue(this.targetWorld.x, this.platforms[from].x1 + 8, this.platforms[from].x2 - 8);
      let bestScore = Infinity;
      for (let i = 0; i < n; i += 1) {
        if (!isFinite(dist[i])) continue;
        const p = this.platforms[i];
        const px = clampValue(this.targetWorld.x, p.x1 + 8, p.x2 - 8);
        const proximity = Math.hypot(px - this.targetWorld.x, p.y - this.targetWorld.y);
        let score = dist[i] * 0.1 + proximity;
        if (i === from) score -= 8;
        if (score < bestScore) {
          bestScore = score;
          goal = i;
          targetX = px;
        }
      }

      const path = [];
      let cursor = goal;
      let guard = 0;
      while (cursor !== -1 && guard < n + 2) {
        path.unshift(cursor);
        if (cursor === from) break;
        cursor = prev[cursor];
        guard += 1;
      }
      if (!path.length || path[0] !== from) {
        path.length = 0;
        path.push(from);
        goal = from;
      }

      player.platform = from;
      player.goal = goal;
      player.path = path;
      player.targetX = targetX;
    }

    /* ------------------------------------------------------------------
       Ciclo y física
       ------------------------------------------------------------------ */

    start() {
      if (this.started) {
        this.applyPlayback();
        return;
      }
      this.started = true;
      this.syncHudState();
      this.applyPlayback();
    }

    assetsReady() {
      if (this.started && this.isPaused()) this.draw();
    }

    bindEvents() {
      const onPointer = (event) => {
        this.pointer.x = event.clientX;
        this.pointer.y = event.clientY;
        this.hasPointer = true;
        this.setTargetFromScreen(event.clientX, event.clientY);
      };

      window.addEventListener("pointermove", onPointer, { passive: true });
      window.addEventListener("pointerdown", onPointer, { passive: true });

      window.addEventListener(
        "resize",
        () => {
          window.clearTimeout(this._resizeTimer);
          this._resizeTimer = window.setTimeout(() => {
            this.resize();
            if (this.hasPointer) {
              this.setTargetFromScreen(this.pointer.x, this.pointer.y);
            } else {
              this.targetWorld = { x: this.idleWorld.x, y: this.idleWorld.y };
            }
            if (this.isPaused()) this.draw();
          }, 120);
        },
        { passive: true }
      );

      document.addEventListener("visibilitychange", () => this.applyPlayback());
      document.addEventListener("fullscreenchange", () => this.applyPlayback());

      if (hudToggle) {
        hudToggle.addEventListener("click", () => this.setHudOpen(!this.hudOpen));
      }

      if (pauseButton) {
        pauseButton.addEventListener("click", () => {
          this.userPaused = !this.userPaused;
          userPaused = this.userPaused;
          this.hasManuallyToggled = true;
          this.syncHudState();
          this.applyPlayback();
        });
      }

      if (gameSection && "IntersectionObserver" in window) {
        const observer = new IntersectionObserver(
          (entries) => {
            const entry = entries[0];
            this.gameInView = Boolean(entry && entry.isIntersecting && entry.intersectionRatio > 0.12);
            this.applyPlayback();
          },
          { threshold: [0, 0.12, 0.4] }
        );
        observer.observe(gameSection);
      }

      const footer = document.querySelector(".site-footer");
      if (footer && "IntersectionObserver" in window) {
        const observer = new IntersectionObserver(
          (entries) => {
            this.footerVisible = Boolean(entries[0] && entries[0].isIntersecting);
            this.applyPlayback();
          },
          { threshold: 0.02 }
        );
        observer.observe(footer);
      }

      if (gameMount && "MutationObserver" in window) {
        const observer = new MutationObserver(() => {
          if (gameMount.querySelector("iframe")) {
            this.abortPreload();
            updatePreload("EN JUEGO", "El juego ya está cargando en su sección.", 0, false);
          }
        });
        observer.observe(gameMount, { childList: true, subtree: true });
      }

      if ("MutationObserver" in window) {
        const observer = new MutationObserver(() => this.applyPlayback());
        observer.observe(document.body, { attributes: true, attributeFilter: ["class"] });
      }

      if (reduceMotionQuery.addEventListener) {
        reduceMotionQuery.addEventListener("change", (event) => {
          prefersReducedMotion = event.matches;
          if (prefersReducedMotion) {
            this.userPaused = true;
            userPaused = true;
            this.reducedDefault = true;
            this.hasManuallyToggled = false;
            this.syncHudState();
            this.applyPlayback();
          }
        });
      }
    }

    resize() {
      this.w = Math.max(320, window.innerWidth);
      this.h = Math.max(400, window.innerHeight);
      this.dpr = Math.min(window.devicePixelRatio || 1, 1.75);
      canvas.width = Math.round(this.w * this.dpr);
      canvas.height = Math.round(this.h * this.dpr);
      canvas.style.width = "100%";
      canvas.style.height = "100%";
      this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
      this.ctx.imageSmoothingEnabled = false;

      const fitScale = Math.min(this.w / MAP_W, this.h / MAP_H) * 0.94;
      if (this.w >= 760 && this.h >= 560 && fitScale >= 1.45) {
        this.scale = Math.max(1.45, Math.min(2.4, fitScale));
      } else {
        this.scale = Math.max(1.5, Math.min(2.0, Math.max(this.w / 560, this.h / 620)));
      }

      this.viewW = this.w / this.scale;
      this.viewH = this.h / this.scale;
      this.updateOffsets();
    }

    updateOffsets() {
      if (this.viewW >= MAP_W) {
        this.cameraX = MAP_W / 2;
        this.offsetX = (this.w - MAP_W * this.scale) / 2;
      } else {
        const half = this.viewW / 2;
        this.cameraX = clampValue(this.player.x, half, MAP_W - half);
        this.offsetX = this.w / 2 - this.cameraX * this.scale;
      }

      if (this.viewH >= MAP_H) {
        this.cameraY = MAP_H / 2;
        this.offsetY = (this.h - MAP_H * this.scale) / 2;
      } else {
        const half = this.viewH / 2;
        this.cameraY = clampValue(this.player.y, half, MAP_H - half);
        this.offsetY = this.h / 2 - this.cameraY * this.scale;
      }
    }

    screenToWorld(x, y) {
      return {
        x: clampValue((x - this.offsetX) / this.scale, 0, MAP_W),
        y: clampValue((y - this.offsetY) / this.scale, 0, MAP_H),
      };
    }

    setTargetFromScreen(x, y) {
      this.targetWorld = this.screenToWorld(x, y);
    }

    isPaused() {
      return (
        !this.started ||
        this.userPaused ||
        document.hidden ||
        this.gameInView ||
        document.body.classList.contains("game-pseudo-fs") ||
        Boolean(document.fullscreenElement)
      );
    }

    applyPlayback() {
      if (!this.started) return;
      const suppressed =
        this.gameInView ||
        this.footerVisible ||
        document.body.classList.contains("game-pseudo-fs");
      hud.classList.toggle("is-suppressed", suppressed);
      this.updateOffsets();

      if (this.isPaused()) {
        this.stopLoop();
        this.draw();
        this.syncHudState();
      } else {
        this.startLoop();
        this.syncHudState();
      }
    }

    startLoop() {
      if (this.raf) return;
      this.lastFrame = 0;
      this.raf = requestAnimationFrame((time) => this.tick(time));
    }

    stopLoop() {
      if (this.raf) {
        cancelAnimationFrame(this.raf);
        this.raf = 0;
      }
    }

    tick(timestamp) {
      this.raf = 0;
      if (this.isPaused()) return;
      if (!this.lastFrame) this.lastFrame = timestamp;
      const dt = Math.min(0.04, Math.max(0.001, (timestamp - this.lastFrame) / 1000));
      this.lastFrame = timestamp;
      this.time += dt;
      this.update(dt);
      this.draw();
      this.raf = requestAnimationFrame((time) => this.tick(time));
    }

    update(dt) {
      const p = this.player;
      p.stun = Math.max(0, p.stun - dt);
      p.invuln = Math.max(0, p.invuln - dt);
      p.dodgeCooldown = Math.max(0, p.dodgeCooldown - dt);
      p.ignoreOneWay = Math.max(0, p.ignoreOneWay - dt);
      p.squash = moveTowardValue(p.squash, 0, dt * 4);
      p.anim += dt;

      this.updateBugs(dt);

      if (p.airborne) {
        const oldY = p.y;
        p.vy += MAP_GRAVITY * dt;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.x = clampValue(p.x, 8, MAP_W - 8);
        if (p.vy >= 0) this.checkLanding(oldY);
        if (p.y > MAP_H + 30) this.respawn();
      } else if (p.stun > 0) {
        p.vx = moveTowardValue(p.vx, 0, 900 * dt);
        p.x = clampValue(p.x + p.vx * dt, 8, MAP_W - 8);
      } else {
        const idx = this.platformIndexAt(p.x, p.y);
        if (idx < 0) {
          p.airborne = true;
          p.vy = 0;
        } else {
          p.platform = idx;
          p.y = this.platforms[idx].y;
          p.planTimer -= dt;
          if (p.planTimer <= 0 || !p.path.length) {
            this.plan();
            p.planTimer = 0.18;
          }
          if (p.path.length > 1) {
            const edge = this.edgeFor(p.path[0], p.path[1]);
            if (!edge) {
              this.plan();
            } else {
              const previousX = p.x;
              this.walkToward(edge.takeoff, dt);
              const crossed = (previousX - edge.takeoff) * (p.x - edge.takeoff) <= 0;
              if (Math.abs(p.x - edge.takeoff) <= 2.5 || crossed) {
                this.executeEdge(edge);
              }
            }
          } else {
            this.walkToward(p.targetX, dt);
          }

          if (!p.airborne && this.tryDodge()) {
            // tryDodge ya cambió a estado aéreo
          }

          if (!p.airborne) {
            const current = this.platforms[p.platform];
            if (p.x < current.x1 || p.x > current.x2) {
              p.airborne = true;
              p.vy = 0;
            }
          }
        }
      }

      this.checkPickups();
      this.checkBugHits();
      this.updateOffsets();

      if (!p.airborne && Math.abs(p.vx) > 40 && this.time - this.lastTrail > 0.055) {
        this.lastTrail = this.time;
        this.trail.push({ x: p.x, y: p.y - 14, life: 0.42 });
        if (this.trail.length > 28) this.trail.shift();
      }
      for (let i = this.trail.length - 1; i >= 0; i -= 1) {
        this.trail[i].life -= dt;
        if (this.trail[i].life <= 0) this.trail.splice(i, 1);
      }

      for (let i = this.particles.length - 1; i >= 0; i -= 1) {
        const part = this.particles[i];
        part.life -= dt;
        part.vy += part.gravity * dt;
        part.x += part.vx * dt;
        part.y += part.vy * dt;
        if (part.life <= 0) this.particles.splice(i, 1);
      }

      const playerScreenX = this.offsetX + p.x * this.scale;
      const playerScreenY = this.offsetY + (p.y - 16) * this.scale;
      const targetScreenX = this.offsetX + this.targetWorld.x * this.scale;
      const targetScreenY = this.offsetY + this.targetWorld.y * this.scale;
      const distance = Math.hypot(playerScreenX - targetScreenX, playerScreenY - targetScreenY);
      const desiredSignal = clampValue(100 - Math.max(0, distance - 32) * 0.55, 0, 100);
      this.signal += (desiredSignal - this.signal) * Math.min(1, dt * 5);

      this.lastHudUpdate += dt;
      if (this.lastHudUpdate > 0.12) {
        this.lastHudUpdate = 0;
        this.updateHud();
      }
    }

    walkToward(targetX, dt) {
      const p = this.player;
      const diff = targetX - p.x;
      if (Math.abs(diff) < 0.8) {
        p.vx = moveTowardValue(p.vx, 0, 1200 * dt);
        return;
      }
      const desired = Math.sign(diff) * Math.min(MAP_RUN, Math.abs(diff) * 10);
      p.vx = moveTowardValue(p.vx, desired, 1500 * dt);
      p.x += p.vx * dt;
      if (Math.abs(p.vx) > 8) p.facing = p.vx > 0 ? 1 : -1;
    }

    executeEdge(edge) {
      const p = this.player;
      p.path = [];
      p.planTimer = 0.12;
      p.airborne = true;

      if (edge.kind === "up" || edge.kind === "level") {
        p.vx = edge.vx;
        p.vy = edge.vy;
        p.squash = -0.65;
      } else if (edge.kind === "fall") {
        p.vx = edge.vx;
        p.vy = -125;
        p.squash = -0.45;
      } else {
        p.ignoreOneWay = 0.4;
        p.vx = 0;
        p.vy = 65;
        p.squash = 0.35;
      }
      this.spawnDust(p.x, p.y - 1, 3);
    }

    checkLanding(oldY) {
      const p = this.player;
      if (p.vy < 0) return;
      let best = -1;
      let bestY = Infinity;
      for (let i = 0; i < this.platforms.length; i += 1) {
        const plat = this.platforms[i];
        if (p.ignoreOneWay > 0 && plat.oneWay) continue;
        if (p.x < plat.x1 - 1 || p.x > plat.x2 + 1) continue;
        if (oldY <= plat.y + 1 && p.y >= plat.y && plat.y < bestY) {
          bestY = plat.y;
          best = i;
        }
      }
      if (best < 0) return;

      p.y = this.platforms[best].y;
      p.vy = 0;
      p.vx = 0;
      p.airborne = false;
      p.platform = best;
      p.path = [];
      p.planTimer = 0;
      p.squash = 0.7;
      this.spawnDust(p.x, p.y - 1, 4);
      if (p.ignoreOneWay > 0) p.ignoreOneWay = 0;
    }

    tryDodge() {
      const p = this.player;
      if (p.airborne || p.stun > 0 || p.dodgeCooldown > 0) return false;
      for (let i = 0; i < this.bugs.length; i += 1) {
        const bug = this.bugs[i];
        if (bug.platform !== p.platform) continue;
        const dx = bug.x - p.x;
        if (Math.abs(dx) > 44 || Math.abs(dx) < 9) continue;
        const dir = Math.sign(dx);
        if (dir !== p.facing) continue;
        p.airborne = true;
        p.vx = p.facing * MAP_RUN;
        p.vy = -355;
        p.dodgeCooldown = 1.15;
        p.path = [];
        p.squash = -0.55;
        this.spawnDust(p.x, p.y - 1, 3);
        return true;
      }
      return false;
    }

    updateBugs(dt) {
      this.bugs.forEach((bug) => {
        bug.x += bug.dir * bug.speed * dt;
        if (bug.x >= bug.max) {
          bug.x = bug.max;
          bug.dir = -1;
        } else if (bug.x <= bug.min) {
          bug.x = bug.min;
          bug.dir = 1;
        }
      });
    }

    checkBugHits() {
      const p = this.player;
      if (p.invuln > 0) return;
      for (let i = 0; i < this.bugs.length; i += 1) {
        const bug = this.bugs[i];
        const dx = p.x - bug.x;
        const dy = p.y - 13 - (bug.y - 8);
        if (Math.hypot(dx, dy) < 14) {
          p.stun = 0.45;
          p.invuln = 1.7;
          p.airborne = true;
          p.path = [];
          p.vx = (dx >= 0 ? 1 : -1) * 80;
          p.vy = -210;
          p.squash = 0.5;
          this.signal = Math.max(0, this.signal - 16);
          this.spawnGlitch(bug.x, bug.y - 10);
          return;
        }
      }
    }

    checkPickups() {
      const p = this.player;
      const cx = p.x;
      const cy = p.y - 13;

      this.packets.forEach((packet) => {
        if (!packet.active) {
          packet.timer -= 1 / 60;
          if (packet.timer <= 0) {
            packet.active = true;
          }
          return;
        }
        if (Math.hypot(cx - packet.x, cy - packet.y) < 18) {
          packet.active = false;
          packet.timer = packet.respawn;
          this.packetCount += 1;
          this.signal = Math.min(100, this.signal + 8);
          this.spawnCollect(packet.x, packet.y);
          this.flashHud();
        }
      });

      this.crates.forEach((crate) => {
        if (crate.broken) {
          crate.timer -= 1 / 60;
          if (crate.timer <= 0) crate.broken = false;
          return;
        }
        if (Math.hypot(cx - crate.x, cy - (crate.y - 13)) < 19) {
          crate.broken = true;
          crate.timer = 22;
          this.spawnCrate(crate.x, crate.y - 13);
        }
      });
    }

    respawn() {
      const p = this.player;
      p.x = 333;
      p.y = 330;
      p.vx = 0;
      p.vy = 0;
      p.airborne = false;
      p.platform = 1;
      p.path = [];
      p.planTimer = 0;
      p.stun = 0.4;
      p.invuln = 1;
      this.spawnDust(p.x, p.y, 5);
    }

    /* ------------------------------------------------------------------
       Partículas
       ------------------------------------------------------------------ */

    spawnDust(x, y, count) {
      for (let i = 0; i < count; i += 1) {
        const life = 0.3 + Math.random() * 0.2;
        this.particles.push({
          x: x + (Math.random() - 0.5) * 8,
          y: y - Math.random() * 3,
          vx: (Math.random() - 0.5) * 28,
          vy: -12 - Math.random() * 22,
          gravity: 85,
          life,
          max: life,
          color: "rgba(244,233,216,",
          size: 1 + Math.random() * 1.5,
        });
      }
    }

    spawnCollect(x, y) {
      for (let i = 0; i < 11; i += 1) {
        const a = Math.random() * Math.PI * 2;
        const speed = 20 + Math.random() * 45;
        const life = 0.35 + Math.random() * 0.4;
        this.particles.push({
          x,
          y,
          vx: Math.cos(a) * speed,
          vy: Math.sin(a) * speed,
          gravity: 20,
          life,
          max: life,
          color: "rgba(102,224,208,",
          size: 1 + Math.random() * 1.4,
        });
      }
    }

    spawnCrate(x, y) {
      for (let i = 0; i < 12; i += 1) {
        const a = Math.random() * Math.PI * 2;
        const speed = 18 + Math.random() * 55;
        const life = 0.35 + Math.random() * 0.45;
        this.particles.push({
          x,
          y,
          vx: Math.cos(a) * speed,
          vy: Math.sin(a) * speed - 25,
          gravity: 260,
          life,
          max: life,
          color: "rgba(198,160,94,",
          size: 1.5 + Math.random() * 2,
        });
      }
    }

    spawnGlitch(x, y) {
      for (let i = 0; i < 9; i += 1) {
        const life = 0.25 + Math.random() * 0.3;
        this.particles.push({
          x: x + (Math.random() - 0.5) * 20,
          y: y + (Math.random() - 0.5) * 16,
          vx: (Math.random() - 0.5) * 65,
          vy: (Math.random() - 0.5) * 45,
          gravity: 60,
          life,
          max: life,
          color: "rgba(228,88,140,",
          size: 1 + Math.random() * 1.6,
        });
      }
    }

    /* ------------------------------------------------------------------
       Dibujo
       ------------------------------------------------------------------ */

    draw() {
      const ctx = this.ctx;
      if (!ctx) return;
      ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
      ctx.clearRect(0, 0, this.w, this.h);
      ctx.setTransform(
        this.dpr * this.scale,
        0,
        0,
        this.dpr * this.scale,
        this.dpr * this.offsetX,
        this.dpr * this.offsetY
      );
      ctx.imageSmoothingEnabled = false;

      this.drawPlatforms();
      this.drawCrates();
      this.drawPackets();
      this.drawBugs();
      this.drawLink();
      this.drawTrail();
      this.drawCharacter();
      this.drawParticles();
    }

    drawPlatforms() {
      const ctx = this.ctx;
      const tile = images.tile;
      const capL = images.capL;
      const capR = images.capR;

      this.platforms.forEach((p) => {
        const width = p.x2 - p.x1;
        ctx.save();
        ctx.globalAlpha = 0.7;

        ctx.fillStyle = "rgba(2,5,10,0.28)";
        ctx.fillRect(p.x1 + 3, p.y + 17, width, 4);

        if (tile) {
          for (let x = p.x1; x < p.x2; x += 16) {
            const dw = Math.min(16, p.x2 - x);
            const sw = Math.min(16, dw);
            ctx.drawImage(tile, 0, 0, sw, 16, x, p.y, dw, 16);
          }
          if (capL) ctx.drawImage(capL, 0, 0, 16, 16, p.x1 - 3, p.y, 16, 16);
          if (capR) ctx.drawImage(capR, 0, 0, 16, 16, p.x2 - 13, p.y, 16, 16);
        } else {
          ctx.fillStyle = "rgba(27,39,55,0.9)";
          ctx.fillRect(p.x1, p.y, width, 16);
          ctx.fillStyle = "rgba(46,168,76,0.8)";
          ctx.fillRect(p.x1, p.y, width, 3);
        }

        ctx.fillStyle = "rgba(88,226,122,0.18)";
        ctx.fillRect(p.x1 + 3, p.y, Math.max(0, width - 6), 1);
        ctx.globalAlpha = 0.32;
        for (let lx = p.x1 + 20; lx < p.x2 - 10; lx += 48) {
          ctx.fillStyle = "rgba(102,224,208,0.65)";
          ctx.fillRect(lx, p.y + 12, 2, 1);
        }
        ctx.restore();
      });
    }

    drawCrates() {
      const ctx = this.ctx;
      const crate = images.crate;
      this.crates.forEach((c) => {
        if (c.broken) return;
        ctx.save();
        ctx.globalAlpha = 0.82;
        if (crate) {
          ctx.drawImage(crate, 0, 0, 18, 18, c.x - 13, c.y - 27, 27, 27);
        } else {
          ctx.fillStyle = "rgba(76,66,42,0.9)";
          ctx.fillRect(c.x - 13, c.y - 27, 27, 27);
        }
        ctx.restore();
      });
    }

    drawPackets() {
      const ctx = this.ctx;
      const packet = images.packet;
      const glow = images.glow;
      this.packets.forEach((p) => {
        if (!p.active) return;
        const y = p.baseY + Math.sin(this.time * 2.1 + p.phase) * 2.5;
        if (glow) {
          ctx.save();
          ctx.globalAlpha = 0.2;
          ctx.drawImage(glow, p.x - 22, y - 22, 44, 44);
          ctx.restore();
        }
        if (packet) {
          const frame = Math.floor(this.time * 7 + p.phase) % 4;
          ctx.drawImage(packet, frame * 8, 0, 8, 8, p.x - 8, y - 8, 16, 16);
        } else {
          ctx.fillStyle = "#66e0d0";
          ctx.fillRect(p.x - 3, y - 3, 6, 6);
        }
      });
    }

    drawBugs() {
      const ctx = this.ctx;
      const bug = images.bug;
      const glow = images.glow;
      this.bugs.forEach((b) => {
        if (glow) {
          ctx.save();
          ctx.globalAlpha = 0.1;
          ctx.drawImage(glow, b.x - 20, b.y - 30, 40, 26);
          ctx.restore();
        }
        if (bug) {
          const frame = Math.floor(this.time * 6 + b.phase) % 2;
          ctx.save();
          ctx.translate(b.x, 0);
          ctx.scale(b.dir < 0 ? -1 : 1, 1);
          ctx.drawImage(bug, frame * 16, 0, 16, 16, -11, b.y - 22, 22, 22);
          ctx.restore();
        } else {
          ctx.fillStyle = "#e4588c";
          ctx.fillRect(b.x - 5, b.y - 8, 10, 7);
        }
      });
    }

    drawLink() {
      if (this.userPaused) return;
      const ctx = this.ctx;
      const p = this.player;
      const x1 = p.x;
      const y1 = p.y - 16;
      const x2 = this.targetWorld.x;
      const y2 = this.targetWorld.y;
      const dist = Math.hypot(x2 - x1, y2 - y1);
      if (dist < 45) return;
      const steps = Math.min(34, Math.floor(dist / 14));
      ctx.save();
      ctx.globalAlpha = 0.14;
      ctx.fillStyle = "#66e0d0";
      for (let i = 1; i < steps; i += 1) {
        const t = i / steps;
        ctx.fillRect(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, 1, 1);
      }
      ctx.restore();
    }

    drawTrail() {
      const ctx = this.ctx;
      ctx.save();
      this.trail.forEach((t) => {
        const alpha = Math.max(0, t.life / 0.42) * 0.3;
        ctx.fillStyle = "rgba(88,226,122," + alpha.toFixed(3) + ")";
        ctx.fillRect(t.x, t.y, 1.5, 1.5);
      });
      ctx.restore();
    }

    drawCharacter() {
      const ctx = this.ctx;
      const p = this.player;
      const speed = Math.abs(p.vx);
      const moving = !p.airborne && speed > 18;
      const bob = moving ? Math.abs(Math.sin(p.anim * 16)) * 1.6 : Math.sin(p.anim * 2.2) * 0.6;
      const sprite = images.sprite;
      const glow = images.glow;

      let shadowY = p.y;
      for (let i = 0; i < this.platforms.length; i += 1) {
        const plat = this.platforms[i];
        if (p.x >= plat.x1 && p.x <= plat.x2 && plat.y >= p.y - 1) {
          shadowY = plat.y;
          break;
        }
      }
      ctx.save();
      ctx.globalAlpha = 0.3;
      ctx.fillStyle = "#000";
      ctx.beginPath();
      ctx.ellipse(p.x, shadowY + 0.5, 10, 2.5, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();

      if (glow) {
        ctx.save();
        ctx.globalCompositeOperation = "lighter";
        ctx.globalAlpha = 0.17;
        ctx.drawImage(glow, p.x - 26, p.y - 42, 52, 52);
        ctx.restore();
      }

      if (sprite) {
        const frame = p.airborne || moving ? 4 : 0;
        const squash = p.squash;
        const sx = 1 + squash * 0.12;
        const sy = 1 - squash * 0.18;
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.scale(p.facing, 1);
        ctx.drawImage(
          sprite,
          frame * 16,
          0,
          16,
          16,
          -16 * sx,
          -32 * sy - bob,
          32 * sx,
          32 * sy
        );
        ctx.restore();
      } else {
        ctx.fillStyle = "#2ea84c";
        ctx.fillRect(p.x - 10, p.y - 28, 20, 28);
      }
    }

    drawParticles() {
      const ctx = this.ctx;
      this.particles.forEach((p) => {
        const alpha = Math.max(0, p.life / p.max);
        ctx.fillStyle = p.color + alpha.toFixed(3) + ")";
        ctx.fillRect(p.x, p.y, p.size, p.size);
      });
    }

    /* ------------------------------------------------------------------
       HUD
       ------------------------------------------------------------------ */

    updateHud() {
      const value = Math.round(this.signal);
      if (signalFill) signalFill.style.width = value + "%";
      if (signalValue) signalValue.textContent = value + "%";
      if (signalBar) signalBar.setAttribute("aria-valuenow", String(value));
      if (packetsValue) packetsValue.textContent = String(this.packetCount).padStart(2, "0");
    }

    flashHud() {
      if (!stateLabel) return;
      stateLabel.textContent = "PAQUETE +1";
      window.clearTimeout(this._flashTimer);
      this._flashTimer = window.setTimeout(() => this.syncHudState(), 900);
    }

    setHudOpen(open) {
      this.hudOpen = open;
      hud.classList.toggle("is-open", open);
      if (hudToggle) {
        hudToggle.setAttribute("aria-expanded", String(open));
        hudToggle.setAttribute("aria-label", open ? "Contraer el panel del entorno" : "Expandir el panel del entorno");
      }
    }

    syncHudState() {
      if (pauseButton) {
        pauseButton.textContent = this.userPaused
          ? (this.reducedDefault && !this.hasManuallyToggled ? "Activar entorno" : "Reanudar entorno")
          : "Pausar entorno";
        pauseButton.setAttribute("aria-pressed", String(this.userPaused));
      }
      if (stateLabel && stateLabel.textContent !== "PAQUETE +1") {
        stateLabel.textContent = this.userPaused
          ? (this.reducedDefault && !this.hasManuallyToggled ? "MOV. REDUCIDO" : "EN PAUSA")
          : "ACTIVO";
      }
      if (hudDot) {
        hudDot.style.background = this.userPaused ? "var(--amber)" : "var(--green-bright)";
        hudDot.style.boxShadow = this.userPaused
          ? "0 0 8px rgba(231,180,90,0.6)"
          : "0 0 8px rgba(88,226,122,0.7)";
      }
    }

    abortPreload() {
      if (preloadAbort) {
        try {
          preloadAbort.abort();
        } catch (error) {
          /* no-op */
        }
      }
    }

    getDebugState() {
      const p = this.player;
      return {
        platform: p.platform,
        goal: p.goal,
        airborne: p.airborne,
        path: p.path.slice(),
        x: Math.round(p.x),
        y: Math.round(p.y),
        target: this.targetWorld,
        scale: this.scale,
        packets: this.packetCount,
        signal: Math.round(this.signal),
      };
    }
  }


  ambient = new AmbientWorld();
  window.__pochAmbient = ambient;

  /* ------------------------------------------------------------------
     Precarga del build Godot completo
     ------------------------------------------------------------------ */

  const PRELOAD_FILES = [
    "game/index.wasm",
    "game/index.pck",
    "game/index.js",
    "game/index.audio.worklet.js",
    "game/index.audio.position.worklet.js",
  ];

  function updatePreload(state, note, percent, done, indeterminate) {
    if (preloadState) preloadState.textContent = state;
    if (preloadNote && note) preloadNote.textContent = note;
    if (hudBrief) {
      if (state === "PRECARGANDO") {
        hudBrief.textContent = indeterminate
          ? "PRECARGANDO"
          : "PRECARGANDO " + Math.round(percent || 0) + "%";
      } else if (state === "LISTO") {
        hudBrief.textContent = "JUEGO LISTO";
      } else if (state === "EN JUEGO") {
        hudBrief.textContent = "EN JUEGO";
      } else if (state === "A DEMANDA" || state === "AL ENTRAR" || state === "AHORRO DE DATOS") {
        hudBrief.textContent = "SE CARGA AL ENTRAR";
      }
    }
    if (hudProgressFill) {
      if (typeof percent === "number") {
        hudProgressFill.style.width = Math.max(0, Math.min(100, percent)) + "%";
      }
      if (done) hudProgressFill.style.width = "100%";
    }
    if (preloadBox) {
      preloadBox.classList.toggle("is-done", Boolean(done));
      preloadBox.classList.toggle("is-indeterminate", Boolean(indeterminate));
    }
    if (preloadBar) preloadBar.setAttribute("aria-hidden", done ? "true" : "false");
    if (typeof percent === "number" && preloadFill) {
      preloadFill.style.width = Math.max(0, Math.min(100, percent)) + "%";
    }
    if (done && preloadFill) {
      preloadFill.style.width = "100%";
    }
  }

  function connectionIsRestricted() {
    const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
    const effective = connection && connection.effectiveType ? connection.effectiveType : "";
    if (connection && connection.saveData) return true;
    if (/(^|-)2g$/.test(effective)) return true;
    if (window.matchMedia && window.matchMedia("(prefers-reduced-data: reduce)").matches) return true;
    return false;
  }

  function startPreload() {
    if (preloadStarted || preloadScheduled === "done") return;
    if (gameMount && gameMount.querySelector("iframe")) {
      updatePreload("EN JUEGO", "El juego ya está cargando en su sección.", 0, false);
      return;
    }

    preloadStarted = true;
    preloadScheduled = true;
    const controller = new AbortController();
    preloadAbort = controller;
    let expectedTotal = 0;
    let loaded = 0;
    let progressKnown = false;

    updatePreload("PREPARANDO", "Consultando el tamaño del runtime.", 0, false);

    const readResponse = async (url, counted) => {
      const response = await fetch(url, {
        cache: "default",
        credentials: "same-origin",
        signal: controller.signal,
      });
      if (!response.ok) throw new Error("No se pudo precargar " + url);

      if (!response.body || !response.body.getReader) {
        const buffer = await response.arrayBuffer();
        if (counted) {
          loaded += buffer.byteLength;
          if (progressKnown) {
            updatePreload(
              "PRECARGANDO",
              "Descargando el runtime de Godot · " + (loaded / 1048576).toFixed(1) + " MB",
              Math.min(97, (loaded / expectedTotal) * 100),
              false,
              false
            );
          }
        }
        return;
      }

      const reader = response.body.getReader();
      while (true) {
        const chunk = await reader.read();
        if (chunk.done) break;
        if (!counted) continue;
        loaded += chunk.value.byteLength;
        if (progressKnown) {
          updatePreload(
            "PRECARGANDO",
            "Descargando el runtime de Godot · " + (loaded / 1048576).toFixed(1) + " MB",
            Math.min(97, (loaded / expectedTotal) * 100),
            false,
            false
          );
        } else {
          updatePreload(
            "PRECARGANDO",
            "Descargando el runtime de Godot · " + (loaded / 1048576).toFixed(1) + " MB",
            0,
            false,
            true
          );
        }
      }
    };

    const prepare = async () => {
      try {
        const response = await fetch("game/index.html", {
          cache: "no-cache",
          credentials: "same-origin",
          signal: controller.signal,
        });
        if (response.ok) {
          const html = await response.text();
          const match = html.match(/"fileSizes"\s*:\s*\{([^}]*)\}/);
          if (match) {
            const sizes = JSON.parse("{" + match[1] + "}");
            const values = Object.keys(sizes).map(function (key) {
              return Number(sizes[key]) || 0;
            });
            expectedTotal = values.reduce(function (sum, value) {
              return sum + value;
            }, 0);
          }
        }
      } catch (error) {
        if (error && error.name === "AbortError") throw error;
      }

      progressKnown = expectedTotal > 0;
      updatePreload(
        "PRECARGANDO",
        progressKnown
          ? "Descargando el runtime de Godot · 0.0 MB"
          : "Descargando el runtime de Godot en segundo plano.",
        0,
        false,
        !progressKnown
      );

      const tasks = PRELOAD_FILES.map(function (url) {
        return readResponse(url, url === "game/index.wasm" || url === "game/index.pck");
      });
      await Promise.all(tasks);
    };

    prepare()
      .then(() => {
        if (controller.signal.aborted) return;
        preloadStarted = false;
        preloadScheduled = "done";
        updatePreload("LISTO", "Runtime listo. Entrar al juego es inmediato.", 100, true);
      })
      .catch((error) => {
        if (error && error.name === "AbortError") return;
        preloadStarted = false;
        preloadScheduled = false;
        updatePreload("AL ENTRAR", "La precarga no terminó; el juego se cargará al entrar.", 0, false);
      });
  }

  function schedulePreload() {
    if (preloadScheduled || preloadStarted) return;
    if (connectionIsRestricted()) {
      preloadScheduled = true;
      updatePreload("AHORRO DE DATOS", "El juego se cargará al entrar.", 0, false);
      return;
    }

    const coarse = window.matchMedia && window.matchMedia("(pointer: coarse)").matches;
    if (coarse) {
      updatePreload("A DEMANDA", "Se precargará al acercarte a la sección del juego.", 0, false);
      if (gameSection && "IntersectionObserver" in window) {
        const presage = new IntersectionObserver(
          (entries) => {
            if (entries.some((entry) => entry.isIntersecting)) {
              presage.disconnect();
              window.setTimeout(startPreload, 700);
            }
          },
          { rootMargin: "1100px 0px" }
        );
        presage.observe(gameSection);
      }
      return;
    }

    window.setTimeout(startPreload, 1600);
  }

  loadAmbientAssets();
})();
