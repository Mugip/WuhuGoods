// ============================================================
// WuhuGoods Header v5 (Turbo-safe, nav-friendly)
// ============================================================
//
// Changes from v4:
// - Drawer links NO LONGER preventDefault (navigation proceeds).
// - Drawer auto-closes on Turbo navigation events.
// - Close button & overlay still close immediately.
// - Optional body scroll lock while drawer open (toggle class).
//

(function () {
  // Guard so we don't double-bind when Turbo caches/restores
  function alreadyBound() { return document.body.dataset.wuhuHeaderBound === "1"; }
  function markBound()     { document.body.dataset.wuhuHeaderBound = "1"; }

  function initWuhuHeader() {
    if (alreadyBound()) return;
    markBound();

    const body    = document.body;
    const header  = document.querySelector(".wuhu-header");
    const toggle  = document.getElementById("wuhu-mobile-toggle");
    const drawer  = document.getElementById("wuhu-mobile-drawer");
    const close   = document.getElementById("wuhu-mobile-close");
    const overlay = drawer ? drawer.querySelector(".wuhu-mobile-overlay") : null;

    if (!header) {
      console.warn("[WuhuGoods] header element not found.");
      return;
    }

    let drawerOpen = false;
    let lastY = window.scrollY;

    function lockScroll() {
      // prevent background scroll while drawer open (mobile)
      body.style.overflow = "hidden";
      body.classList.add("wuhu-drawer-open");
    }
    function unlockScroll() {
      body.style.overflow = "";
      body.classList.remove("wuhu-drawer-open");
    }

    function openDrawer(ev) {
      ev?.preventDefault();
      ev?.stopPropagation();
      if (!drawer) return;
      drawer.classList.add("active");
      drawer.setAttribute("aria-hidden", "false");
      toggle?.setAttribute("aria-expanded", "true");
      drawerOpen = true;
      lockScroll();
    }

    function closeDrawer(ev) {
      // DO NOT preventDefault here when called from Turbo navigation
      if (!drawer) return;
      drawer.classList.remove("active");
      drawer.setAttribute("aria-hidden", "true");
      toggle?.setAttribute("aria-expanded", "false");
      drawerOpen = false;
      unlockScroll();
    }

    // Toggle bindings
    toggle?.addEventListener("click", openDrawer, { passive: false });
    toggle?.addEventListener("touchstart", openDrawer, { passive: false });

    // Close button + overlay
    close?.addEventListener("click", closeDrawer, { passive: false });
    close?.addEventListener("touchstart", closeDrawer, { passive: false });
    overlay?.addEventListener("click", closeDrawer, { passive: false });

    // Let link clicks navigate. We *do not* preventDefault.
    // We close the drawer *just before* navigation using Turbo hooks below.
    if (drawer) {
      drawer.querySelectorAll("a").forEach((a) => {
        a.addEventListener("click", () => {
          // allow normal navigation; Turbo events will close the drawer
          // For non-Turbo external links, close drawer shortly after click
          setTimeout(() => { if (drawerOpen) closeDrawer(); }, 150);
        }, { passive: true });
      });
    }

    // Hide header on scroll (only when drawer is closed)
    window.addEventListener("scroll", () => {
      if (!header || drawerOpen) return;
      const y = window.scrollY;
      if (y > lastY && y > 40) {
        header.classList.add("hidden-header");
      } else if (y < lastY) {
        header.classList.remove("hidden-header");
      }
      lastY = y;
    }, { passive: true });

    // ---- Turbo integration ----
    // When Turbo begins a visit (link clicked, back/forward, etc.), close the drawer.
    document.addEventListener("turbo:visit", () => {
      if (drawerOpen) closeDrawer();
    });

    // When Turbo loads new page, reset bound flag so re-init can attach fresh events.
    document.addEventListener("turbo:load", () => {
      // Remove the guard so subsequent visits rebind (since new DOM)
      delete document.body.dataset.wuhuHeaderBound;
      // Immediately re-init for the new page
      initWuhuHeader();
    }, { once: true }); // only once per page load

    console.log("[WuhuGoods] header initialized (v5)");
  }

  // Initial boot (plain Rails or first Turbo load)
  document.addEventListener("DOMContentLoaded", initWuhuHeader);
  document.addEventListener("turbo:load", initWuhuHeader);
})();