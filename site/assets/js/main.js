/*
  Keiber Urbila — portafolio
  Interacciones sin dependencias: navegación, scrollspy y puente postMessage
  para la experiencia POCHLAND.
*/

(function () {
  "use strict";

  /* ------------------------------------------------------------------
     Header
  ------------------------------------------------------------------ */

  const header = document.getElementById("site-header");

  function updateHeader() {
    if (!header) return;
    header.classList.toggle("is-scrolled", window.scrollY > 8);
  }

  updateHeader();
  window.addEventListener("scroll", updateHeader, { passive: true });

  /* ------------------------------------------------------------------
     Menú móvil accesible
  ------------------------------------------------------------------ */

  const menuToggle = document.querySelector(".menu-toggle");
  const primaryNav = document.getElementById("primary-nav");
  const mainContent = document.getElementById("contenido");
  const footer = document.querySelector(".site-footer");
  const mobileQuery = window.matchMedia("(max-width: 920px)");
  let menuOpen = false;

  function isMobileNav() {
    return mobileQuery.matches;
  }

  function setInert(element, inert) {
    if (!element) return;
    if (inert) {
      element.setAttribute("inert", "");
    } else {
      element.removeAttribute("inert");
    }
  }

  function focusableInHeader() {
    if (!header) return [];
    return Array.from(
      header.querySelectorAll("a[href], button:not([disabled])")
    ).filter(function (element) {
      return element.getClientRects().length > 0;
    });
  }

  function setMenu(open, options) {
    if (!menuToggle || !primaryNav) return;

    const settings = options || {};
    const shouldOpen = Boolean(open) && isMobileNav();

    menuOpen = shouldOpen;
    header.classList.toggle("nav-open", shouldOpen);
    menuToggle.setAttribute("aria-expanded", String(shouldOpen));
    menuToggle.setAttribute(
      "aria-label",
      shouldOpen ? "Cerrar menú" : "Abrir menú"
    );
    document.body.classList.toggle("menu-open", shouldOpen);

    if (shouldOpen) {
      primaryNav.removeAttribute("inert");
      setInert(mainContent, true);
      setInert(footer, true);
      if (settings.moveFocus !== false) {
        const firstLink = primaryNav.querySelector("a[href]");
        if (firstLink) {
          window.requestAnimationFrame(function () {
            firstLink.focus();
          });
        }
      }
    } else {
      if (isMobileNav()) {
        primaryNav.setAttribute("inert", "");
      } else {
        primaryNav.removeAttribute("inert");
      }
      setInert(mainContent, false);
      setInert(footer, false);
      if (settings.returnFocus) {
        menuToggle.focus();
      }
    }
  }

  function syncMenuMode() {
    if (!menuToggle || !primaryNav) return;

    if (isMobileNav()) {
      if (!menuOpen) {
        primaryNav.setAttribute("inert", "");
        setInert(mainContent, false);
        setInert(footer, false);
      }
    } else {
      menuOpen = false;
      header.classList.remove("nav-open");
      document.body.classList.remove("menu-open");
      primaryNav.removeAttribute("inert");
      setInert(mainContent, false);
      setInert(footer, false);
      menuToggle.setAttribute("aria-expanded", "false");
      menuToggle.setAttribute("aria-label", "Abrir menú");
    }
  }

  if (menuToggle && primaryNav) {
    syncMenuMode();

    menuToggle.addEventListener("click", function () {
      setMenu(!menuOpen, { returnFocus: menuOpen });
    });

    primaryNav.addEventListener("click", function (event) {
      const link = event.target.closest("a");
      if (!link) return;

      const hash = link.getAttribute("href");
      setMenu(false);

      if (hash && hash.charAt(0) === "#") {
        const target = document.querySelector(hash);
        if (target) {
          window.setTimeout(function () {
            target.setAttribute("tabindex", "-1");
            target.focus({ preventScroll: true });
            target.addEventListener(
              "blur",
              function () {
                target.removeAttribute("tabindex");
              },
              { once: true }
            );
          }, 0);
        }
      } else if (menuToggle) {
        menuToggle.focus();
      }
    });

    document.addEventListener("keydown", function (event) {
      if (!menuOpen) return;

      if (event.key === "Escape") {
        event.preventDefault();
        setMenu(false, { returnFocus: true });
        return;
      }

      if (event.key !== "Tab") return;

      const items = focusableInHeader();
      if (!items.length) return;

      const first = items[0];
      const last = items[items.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    });

    if (typeof mobileQuery.addEventListener === "function") {
      mobileQuery.addEventListener("change", syncMenuMode);
    } else if (typeof mobileQuery.addListener === "function") {
      mobileQuery.addListener(syncMenuMode);
    }
  }

  /* ------------------------------------------------------------------
     Scrollspy
  ------------------------------------------------------------------ */

  const navLinks = Array.from(
    document.querySelectorAll('#primary-nav .nav-list a[href^="#"]')
  );
  const spySections = Array.from(
    document.querySelectorAll("main section[id]")
  );
  const navLinksById = new Map();

  navLinks.forEach(function (link) {
    navLinksById.set(link.getAttribute("href").slice(1), link);
  });

  function setActiveSection(id) {
    navLinks.forEach(function (link) {
      const isActive = link === navLinksById.get(id);
      link.classList.toggle("is-active", isActive);
      if (isActive) {
        link.setAttribute("aria-current", "location");
      } else {
        link.removeAttribute("aria-current");
      }
    });
  }

  if ("IntersectionObserver" in window && spySections.length) {
    const spyObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          setActiveSection(entry.target.id);
        });
      },
      {
        rootMargin: "-38% 0px -54% 0px",
        threshold: 0
      }
    );

    spySections.forEach(function (section) {
      spyObserver.observe(section);
    });
  }

  /* ------------------------------------------------------------------
     POCHLAND — puente de comunicación
  ------------------------------------------------------------------ */

  const gameSection = document.getElementById("jugar");
  const gameFrame = document.getElementById("game-frame");
  const gamePoster = document.getElementById("game-poster");
  const gameMount = document.getElementById("game-mount");
  const gameLoading = document.getElementById("game-loading");
  const gameStatus = document.getElementById("game-status");
  const gameFallback = document.getElementById("game-fallback");
  const startGameButton = document.getElementById("start-game");
  const hud = document.getElementById("hud");
  const hudState = document.getElementById("hud-state");
  const hudStateText = document.getElementById("hud-state-text");
  const signalBar = document.getElementById("signal-bar");
  const signalFill = document.getElementById("signal-fill");
  const signalValue = document.getElementById("signal-value");
  const packetCount = document.getElementById("packet-count");
  const bestScore = document.getElementById("best-score");
  const hudEvent = document.getElementById("hud-event");
  const fullscreenButton = document.getElementById("fs-btn");
  const fullscreenLabel = document.getElementById("fs-label");
  const restartButton = document.getElementById("restart-btn");
  const soundToggle = document.getElementById("sound-toggle");
  const soundLabel = document.getElementById("sound-label");
  const pseudoFullscreenExit = document.getElementById("fs-exit");

  if (
    gameSection &&
    gameFrame &&
    gamePoster &&
    gameMount &&
    gameLoading &&
    startGameButton
  ) {
    const GAME_SRC = "game/index.html";
    const GAME_TIMEOUT = 15000;
    const allowedEvents = {
      collect: "PAQUETE RECUPERADO",
      sync: "SEÑAL SINCRONIZADA",
      jump: "IMPULSO EJECUTADO"
    };

    let gameIframe = null;
    let gameStarted = false;
    let gameOnline = false;
    let gameInView = false;
    let gameTimedOut = false;
    let loadTimer = null;
    let eventTimer = null;
    let muted = false;

    const numberFormatter = new Intl.NumberFormat("es-VE");

    function safeNumber(value, fallback) {
      const parsed = Number(value);
      return Number.isFinite(parsed) ? parsed : fallback;
    }

    function clamp(value, min, max) {
      return Math.min(Math.max(value, min), max);
    }

    function formatCounter(value) {
      const safe = Math.max(0, Math.floor(safeNumber(value, 0)));
      return safe < 1000 ? String(safe).padStart(3, "0") : numberFormatter.format(safe);
    }

    function setHudStatus(label) {
      if (hudStateText) {
        hudStateText.textContent = label;
      }
    }

    function setLoadingMessage(message) {
      if (gameStatus) {
        gameStatus.textContent = message;
      }
    }

    function postToGame(payload) {
      if (!gameIframe || !gameIframe.contentWindow) return;

      try {
        gameIframe.contentWindow.postMessage(
          Object.assign({ source: "pochland-host" }, payload),
          "*"
        );
      } catch (error) {
        /* El iframe pudo haberse retirado durante la transición. */
      }
    }

    function isNativeFullscreen() {
      return document.fullscreenElement === gameFrame;
    }

    function isPseudoFullscreen() {
      return gameFrame.classList.contains("is-pseudo-fullscreen");
    }

    function isFullscreenActive() {
      return isNativeFullscreen() || isPseudoFullscreen();
    }

    function shouldPauseGame() {
      if (document.hidden) return true;
      if (isFullscreenActive()) return false;
      return !gameInView;
    }

    function syncGamePlayback() {
      if (!gameOnline) return;

      const shouldPause = shouldPauseGame();
      postToGame({ type: shouldPause ? "pause" : "resume" });
      setHudStatus(shouldPause ? "EN PAUSA" : "EN LÍNEA");
    }

    function updateFullscreenUI() {
      const active = isFullscreenActive();

      if (fullscreenButton) {
        fullscreenButton.setAttribute("aria-pressed", String(active));
      }
      if (fullscreenLabel) {
        fullscreenLabel.textContent = active
          ? "Salir de pantalla completa"
          : "Pantalla completa";
      }
    }

    function updateStats(data) {
      const sync = clamp(safeNumber(data.sync, 0), 0, 100);
      const roundedSync = Math.round(sync);
      const packets = Math.max(0, Math.floor(safeNumber(data.packets, 0)));
      const best = clamp(safeNumber(data.best, 0), 0, 100);

      if (signalFill) {
        signalFill.style.width = sync + "%";
      }
      if (signalValue) {
        signalValue.textContent = roundedSync + "%";
      }
      if (signalBar) {
        signalBar.setAttribute("aria-valuenow", String(roundedSync));
      }
      if (packetCount) {
        packetCount.textContent = formatCounter(packets);
      }
      if (bestScore) {
        bestScore.textContent = best + "%";
      }
    }

    function pulseHudEvent(name) {
      if (!hudEvent) return;

      const label = allowedEvents[name];
      if (!label) return;

      hudEvent.textContent = "EVENTO // " + label;
      hudEvent.classList.remove("is-active");
      /* Forzar el reinicio de la animación sin afectar el layout. */
      void hudEvent.offsetWidth;
      hudEvent.classList.add("is-active");

      window.clearTimeout(eventTimer);
      eventTimer = window.setTimeout(function () {
        hudEvent.classList.remove("is-active");
        hudEvent.textContent = gameOnline ? "ENLACE ESTABLE" : "SISTEMA EN ESPERA";
      }, 1800);
    }

    function clearLoadTimer() {
      if (loadTimer) {
        window.clearTimeout(loadTimer);
        loadTimer = null;
      }
    }

    function hideFallback() {
      gameTimedOut = false;
      if (gameFallback) {
        gameFallback.hidden = true;
      }
    }

    function showFallback() {
      gameTimedOut = true;
      if (gameFallback) {
        gameFallback.hidden = false;
      }
      setLoadingMessage(
        "La señal aún no llega. Puedes abrir el juego en una pestaña."
      );
      setHudStatus("ESPERANDO SEÑAL");
      if (hudEvent) {
        hudEvent.textContent = "SIN RESPUESTA DEL JUEGO";
      }
    }

    function armLoadTimer() {
      clearLoadTimer();
      loadTimer = window.setTimeout(function () {
        if (!gameOnline) showFallback();
      }, GAME_TIMEOUT);
    }

    function markGameOnline() {
      if (!gameStarted) return;

      const wasOffline = !gameOnline;
      gameOnline = true;
      clearLoadTimer();
      hideFallback();

      if (gameLoading) {
        gameLoading.hidden = true;
      }
      if (gamePoster) {
        gamePoster.hidden = true;
      }
      if (hud) {
        hud.classList.add("is-online");
      }
      if (restartButton) {
        restartButton.disabled = false;
      }
      if (soundToggle) {
        soundToggle.disabled = false;
      }

      gameFrame.removeAttribute("aria-busy");
      
      if (wasOffline) {
        setHudStatus("EN LÍNEA");
        if (hudEvent) {
          hudEvent.textContent = "ENLACE ESTABLE";
          hudEvent.classList.remove("is-active");
        }
        syncGamePlayback();
        try {
          if (gameIframe) gameIframe.focus({ preventScroll: true });
        } catch (error) {
          /* El foco del iframe es una mejora progresiva. */
        }
      }
    }

    function handleGameMessage(data) {
      if (!data || typeof data !== "object") return;
      if (data.source !== "pochland") return;

      if (data.type === "ready") {
        markGameOnline();
        return;
      }

      if (data.type === "stats") {
        markGameOnline();
        updateStats(data);
        return;
      }

      if (data.type === "event") {
        if (!Object.prototype.hasOwnProperty.call(allowedEvents, data.name)) {
          return;
        }
        markGameOnline();
        pulseHudEvent(data.name);
      }
    }

    window.addEventListener("message", function (event) {
      if (!gameIframe || event.source !== gameIframe.contentWindow) return;

      try {
        handleGameMessage(event.data);
      } catch (error) {
        /* Los mensajes externos malformados nunca deben romper el sitio. */
      }
    });

    function createGameIframe() {
      const iframe = document.createElement("iframe");

      iframe.src = GAME_SRC;
      iframe.title = "Pochland, experiencia interactiva en Godot";
      iframe.setAttribute("allow", "autoplay; fullscreen; gamepad");
      iframe.setAttribute("allowfullscreen", "");
      iframe.setAttribute("loading", "lazy");
      iframe.allowFullscreen = true;

      iframe.addEventListener("load", function () {
        if (!gameOnline) {
          setLoadingMessage("Iniciando Pochland. Esperando el primer paquete…");
        }
      });

      iframe.addEventListener("error", function () {
        if (!gameOnline) showFallback();
      });

      gameIframe = iframe;
      gameMount.replaceChildren(iframe);
    }

    function prepareLoadingState(message) {
      gameFrame.setAttribute("aria-busy", "true");
      if (gameLoading) {
        gameLoading.hidden = false;
      }
      if (gameFallback) {
        gameFallback.hidden = true;
      }
      if (restartButton) {
        restartButton.disabled = false;
      }
      if (soundToggle) {
        soundToggle.disabled = true;
      }
      setLoadingMessage(message);
      armLoadTimer();
    }

    function focusLoadingState() {
      if (!gameLoading) return;
      gameLoading.focus({ preventScroll: true });
    }

    function startGame() {
      if (gameStarted) return;

      gameStarted = true;
      gameOnline = false;
      gameTimedOut = false;
      gamePoster.hidden = true;
      setHudStatus("CONECTANDO");
      if (hud) {
        hud.classList.remove("is-online");
      }
      prepareLoadingState("Preparando el canal con Pochland…");
      createGameIframe();

      const wantsImmersive = window.matchMedia(
        "(max-width: 640px), (pointer: coarse) and (max-width: 1024px)"
      ).matches;
      if (wantsImmersive) {
        enterPseudoFullscreen();
      } else {
        focusLoadingState();
      }
    }

    function restartGame() {
      if (!gameStarted) {
        startGame();
        return;
      }

      gameOnline = false;
      gameTimedOut = false;
      clearLoadTimer();
      window.clearTimeout(eventTimer);

      muted = false;
      if (soundToggle) {
        soundToggle.disabled = true;
        soundToggle.setAttribute("aria-pressed", "false");
      }
      if (soundLabel) {
        soundLabel.textContent = "Audio activo";
      }
      if (signalFill) {
        signalFill.style.width = "0%";
      }
      if (signalValue) {
        signalValue.textContent = "0%";
      }
      if (signalBar) {
        signalBar.setAttribute("aria-valuenow", "0");
      }
      if (packetCount) {
        packetCount.textContent = "000";
      }
      if (bestScore) {
        bestScore.textContent = "0%";
      }
      if (hudEvent) {
        hudEvent.classList.remove("is-active");
        hudEvent.textContent = "RECARGANDO SEÑAL";
      }

      if (gameIframe) {
        gameIframe.remove();
        gameIframe = null;
      }
      gameMount.replaceChildren();
      gamePoster.hidden = true;
      if (hud) {
        hud.classList.remove("is-online");
      }
      setHudStatus("RECARGANDO");
      prepareLoadingState("Reiniciando el enlace con Pochland…");
      createGameIframe();
      focusLoadingState();
    }

    if (startGameButton) {
      startGameButton.addEventListener("click", startGame);
    }

    if (restartButton) {
      restartButton.addEventListener("click", restartGame);
    }

    if (soundToggle) {
      soundToggle.addEventListener("click", function () {
        muted = !muted;
        soundToggle.setAttribute("aria-pressed", String(muted));
        if (soundLabel) {
          soundLabel.textContent = muted ? "Audio silenciado" : "Audio activo";
        }
        postToGame({ type: "mute", muted: muted });
      });
    }

    /* Fullscreen: wrapper 16:9, con alternativa CSS si el navegador la niega. */

    function enterPseudoFullscreen() {
      gameFrame.classList.add("is-pseudo-fullscreen");
      document.body.classList.add("game-pseudo-fs");
      updateFullscreenUI();
      syncGamePlayback();
      if (pseudoFullscreenExit) {
        pseudoFullscreenExit.focus({ preventScroll: true });
      }
    }

    function exitPseudoFullscreen(restoreFocus) {
      if (!isPseudoFullscreen()) return;

      gameFrame.classList.remove("is-pseudo-fullscreen");
      document.body.classList.remove("game-pseudo-fs");
      updateFullscreenUI();
      syncGamePlayback();

      if (restoreFocus && fullscreenButton) {
        fullscreenButton.focus({ preventScroll: true });
      }
    }

    async function toggleFullscreen() {
      if (isNativeFullscreen()) {
        try {
          await document.exitFullscreen();
        } catch (error) {
          /* El navegador conserva el control del estado de fullscreen. */
        }
        return;
      }

      if (isPseudoFullscreen()) {
        exitPseudoFullscreen(true);
        return;
      }

      if (typeof gameFrame.requestFullscreen === "function") {
        try {
          await gameFrame.requestFullscreen();
          updateFullscreenUI();
          return;
        } catch (error) {
          enterPseudoFullscreen();
          return;
        }
      }

      enterPseudoFullscreen();
    }

    if (fullscreenButton) {
      fullscreenButton.addEventListener("click", toggleFullscreen);
    }

    if (pseudoFullscreenExit) {
      pseudoFullscreenExit.addEventListener("click", function () {
        exitPseudoFullscreen(true);
      });
    }

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && isPseudoFullscreen()) {
        event.preventDefault();
        exitPseudoFullscreen(true);
      }
    });

    document.addEventListener("fullscreenchange", function () {
      updateFullscreenUI();
      syncGamePlayback();
    });

    /* Pausa por visibilidad de pestaña o salida de la sección. */

    document.addEventListener("visibilitychange", function () {
      if (gameOnline) {
        if (document.hidden) {
          postToGame({ type: "pause" });
        } else {
          syncGamePlayback();
        }
      }
    });

    if ("IntersectionObserver" in window) {
      const gameObserver = new IntersectionObserver(
        function (entries) {
          const entry = entries[0];
          gameInView = Boolean(entry && entry.isIntersecting);
          syncGamePlayback();
        },
        { threshold: 0 }
      );

      gameObserver.observe(gameSection);
    } else {
      gameInView = true;
    }
  }
})();

/* ------------------------------------------------------------------
   Tiempo de experiencia dinámico (actualiza automáticamente cada año)
------------------------------------------------------------------ */
(function () {
  "use strict";

  const START_YEAR = 2019;
  const CURRENT_YEAR = new Date().getFullYear();
  const YEARS = CURRENT_YEAR - START_YEAR;

  const metricValue = document.querySelector('.metric-value');
  const metricLabel = document.querySelector('.metric-label');

  if (metricValue) {
    metricValue.textContent = YEARS + "+";
  }
})();
