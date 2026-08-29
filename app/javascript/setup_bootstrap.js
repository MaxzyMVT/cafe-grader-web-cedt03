import "setup_jquery"

import * as bootstrap from "bootstrap"
window.bootstrap = bootstrap

// Ensure modals nested inside containers with stacking contexts or overflow:hidden
// are moved to document.body when opened so they are never trapped behind .modal-backdrop
document.addEventListener('show.bs.modal', (event) => {
  const modal = event.target;
  if (modal && modal.parentElement && modal.parentElement !== document.body) {
    document.body.appendChild(modal);
  }
});
