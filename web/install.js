(() => {
  const banner = document.getElementById('install-banner');
  const button = document.getElementById('install-button');
  const description = document.getElementById('install-description');
  const standalone = window.matchMedia('(display-mode: standalone)');
  let pendingPrompt = null;
  let dismissed = false;
  try { dismissed = sessionStorage.getItem('cg-install-dismissed') === '1'; } catch (_) {}

  const isInstalled = () => standalone.matches || navigator.standalone === true;
  const hide = () => { banner.hidden = true; };
  const dismiss = () => {
    dismissed = true;
    hide();
    try { sessionStorage.setItem('cg-install-dismissed', '1'); } catch (_) {}
  };
  document.getElementById('install-dismiss').addEventListener('click', dismiss);

  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault();
    pendingPrompt = event;
    button.hidden = false;
    if (!isInstalled() && !dismissed) banner.hidden = false;
  });

  button.addEventListener('click', async () => {
    if (!pendingPrompt) return;
    const prompt = pendingPrompt;
    pendingPrompt = null;
    hide();
    try {
      await prompt.prompt();
      const choice = await prompt.userChoice;
      if (choice.outcome === 'dismissed') dismiss();
    } catch (_) {
      // The browser may invalidate an installation event; wait for a new one.
    }
  });

  window.addEventListener('appinstalled', () => {
    pendingPrompt = null;
    dismiss();
  });
  standalone.addEventListener('change', () => { if (isInstalled()) hide(); });

  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (isIOS && !isInstalled() && !dismissed) {
    button.hidden = true;
    description.textContent = 'Para instalarla, abre este enlace en Safari, toca Compartir y luego “Añadir a pantalla de inicio”.';
    banner.hidden = false;
  }
})();
