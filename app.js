(() => {
  "use strict";
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  const tabs = [...document.querySelectorAll("[data-style]")];
  const device = document.querySelector("#device");
  const note = document.querySelector("#preview-note");
  const swatches = [...document.querySelectorAll("[data-color]")];
  let selectedStyle = "digital";
  let selectedColor = "Lavender";
  let night = false;

  function updateNote() {
    note.textContent = night
      ? "Night Mode. A quieter glow for the evening."
      : selectedStyle === "digital"
        ? `${selectedColor} digital. A little more you.`
        : selectedStyle === "analog"
          ? "Analog. Familiar, down to the second."
          : "Solar. A warmer way to watch time pass.";
  }

  function selectStyle(style, focus = false) {
    selectedStyle = style;
    document.querySelector(".segmented").style.setProperty(
      "--tab-index",
      tabs.findIndex((tab) => tab.dataset.style === style),
    );
    tabs.forEach((tab) => {
      const active = tab.dataset.style === style;
      tab.setAttribute("aria-selected", String(active));
      tab.tabIndex = active ? 0 : -1;
      document.getElementById(tab.getAttribute("aria-controls")).hidden =
        !active;
      if (focus && active) tab.focus();
    });
    updateNote();
  }

  tabs.forEach((tab, index) => {
    tab.addEventListener("click", () => selectStyle(tab.dataset.style));
    tab.addEventListener("keydown", (event) => {
      let next;
      if (event.key === "ArrowRight") next = (index + 1) % tabs.length;
      else if (event.key === "ArrowLeft")
        next = (index - 1 + tabs.length) % tabs.length;
      else if (event.key === "Home") next = 0;
      else if (event.key === "End") next = tabs.length - 1;
      else return;
      event.preventDefault();
      selectStyle(tabs[next].dataset.style, true);
    });
  });

  let swipeStart = null;
  const screen = document.querySelector(".device-screen");
  screen.addEventListener("pointerdown", (event) => {
    if (!event.isPrimary || event.button !== 0) return;
    swipeStart = { x: event.clientX, y: event.clientY };
    screen.setPointerCapture(event.pointerId);
  });
  screen.addEventListener("pointercancel", () => {
    swipeStart = null;
  });
  screen.addEventListener("pointerup", (event) => {
    if (!swipeStart) return;
    const dx = event.clientX - swipeStart.x;
    const dy = event.clientY - swipeStart.y;
    swipeStart = null;
    if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy) * 1.4) {
      const index = tabs.findIndex(
        (tab) => tab.dataset.style === selectedStyle,
      );
      selectStyle(
        tabs[(index + (dx < 0 ? 1 : -1) + tabs.length) % tabs.length].dataset
          .style,
      );
    }
  });

  swatches.forEach((swatch) =>
    swatch.addEventListener("click", () => {
      document.documentElement.style.setProperty(
        "--accent",
        swatch.dataset.color,
      );
      selectedColor = swatch.getAttribute("aria-label");
      swatches.forEach((item) =>
        item.setAttribute("aria-pressed", String(item === swatch)),
      );
      selectStyle("digital");
    }),
  );

  document
    .querySelector("#night-control")
    .addEventListener("click", (event) => {
      night = !night;
      event.currentTarget.setAttribute("aria-pressed", String(night));
      device.classList.toggle("night", night);
      updateNote();
    });

  const time = document.querySelector("#clock-time");
  const date = document.querySelector("#clock-date");
  function tick() {
    const now = new Date();
    time.textContent = new Intl.DateTimeFormat("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    }).format(now);
    date.textContent = new Intl.DateTimeFormat("en-US", {
      weekday: "long",
      month: "long",
      day: "numeric",
    }).format(now);
  }
  tick();
  let clockTimer = setInterval(tick, 1000);
  document.addEventListener("visibilitychange", () => {
    clearInterval(clockTimer);
    if (!document.hidden) {
      tick();
      clockTimer = setInterval(tick, 1000);
    }
  });

  const charge = document.querySelector("#charge-visual");
  const replay = document.querySelector("#replay-charge");
  let chargeTimer;
  function playCharge() {
    clearTimeout(chargeTimer);
    charge.classList.remove("charging");
    if (!reducedMotion.matches) {
      // Restart the finite animation; there is no always-running ambient loop.
      void charge.offsetWidth;
      charge.classList.add("charging");
    }
    replay.disabled = true;
    replay.setAttribute("aria-label", "Charging animation playing");
    chargeTimer = setTimeout(
      () => {
        charge.classList.remove("charging");
        replay.disabled = false;
        replay.removeAttribute("aria-label");
      },
      reducedMotion.matches ? 150 : 1500,
    );
  }
  replay.addEventListener("click", playCharge);
  if ("IntersectionObserver" in window) {
    const chargeObserver = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          playCharge();
          chargeObserver.disconnect();
        }
      },
      { threshold: 0.6 },
    );
    chargeObserver.observe(charge);
    if (!reducedMotion.matches) {
      const revealObserver = new IntersectionObserver(
        (entries) =>
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              entry.target.classList.add("visible");
              revealObserver.unobserve(entry.target);
            }
          }),
        { threshold: 0.08 },
      );
      document.documentElement.classList.add("motion-ready");
      document
        .querySelectorAll(".reveal")
        .forEach((element) => revealObserver.observe(element));
      reducedMotion.addEventListener("change", (event) => {
        if (event.matches) {
          document.documentElement.classList.remove("motion-ready");
          charge.classList.remove("charging");
        }
      });
    }
  }

  const gallery = document.querySelector(".gallery");
  const galleryButtons = [...document.querySelectorAll("[data-gallery]")];
  function updateGallery() {
    const max = gallery.scrollWidth - gallery.clientWidth;
    galleryButtons[0].disabled = gallery.scrollLeft < 5;
    galleryButtons[1].disabled = gallery.scrollLeft >= max - 5;
  }
  galleryButtons.forEach((button) =>
    button.addEventListener("click", () => {
      const step =
        gallery.querySelector("figure").getBoundingClientRect().width +
        parseFloat(getComputedStyle(gallery).gap);
      gallery.scrollBy({
        left: step * Number(button.dataset.gallery),
        behavior: reducedMotion.matches ? "instant" : "smooth",
      });
    }),
  );
  gallery.addEventListener("scroll", updateGallery, { passive: true });
  window.addEventListener("resize", updateGallery, { passive: true });
  updateGallery();

  // GitHub remains the fallback if its API is unavailable or rate-limited.
  fetch(
    "https://api.github.com/repos/qaxxorovxd-mobile/so-standby/releases/latest",
    { signal: AbortSignal.timeout(6000) },
  )
    .then((response) => (response.ok ? response.json() : null))
    .then((release) => {
      if (!release) return;
      const apk = (release.assets || []).find((asset) =>
        /\.apk$/i.test(asset.name),
      );
      if (
        apk &&
        /^https:\/\/github\.com\/qaxxorovxd-mobile\/so-standby\/releases\/download\//.test(
          apk.browser_download_url,
        )
      ) {
        document.querySelectorAll("[data-apk]").forEach((link) => {
          link.href = apk.browser_download_url;
        });
      }
      if (release.tag_name)
        document.querySelector("[data-release]").textContent =
          ` · ${release.tag_name}`;
    })
    .catch(() => {});
})();
