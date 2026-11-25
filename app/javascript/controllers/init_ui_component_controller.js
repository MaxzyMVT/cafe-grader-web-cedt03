// this controllers ensures that the tooltip is intialized
// we should attach this controller to the turbo-frame that is replaced by
// turbo action, so that the tooltip created by the new turbo-frame is initialized
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  connect() {
    this.handleFrameHasLoaded()

    // Destroy Select2 BEFORE Turbo caches the page.
    // This prevents duplication when Turbo restores the cached page.
    this._beforeCacheHandler = () => this._teardownSelect2()
    document.addEventListener('turbo:before-cache', this._beforeCacheHandler)
  }

  handleFrameHasLoaded = () => {
    this.initializeTooltips();
    this.initializePopovers();
    this.initializeSelect2();
    this.initializeTempusDominus();
  }


  initializeTooltips() {
    // Standard tooltip triggers, PLUS any element with data-bs-title that uses
    // data-bs-toggle for some other purpose (offcanvas, dropdown, modal, …) —
    // since data-bs-toggle holds a single value, those elements can't say
    // `="tooltip"` but still want a tooltip on hover.
    const standard = this.element.querySelectorAll('[data-bs-toggle="tooltip"]');
    const piggybacked = this.element.querySelectorAll('[data-bs-title][data-bs-toggle]:not([data-bs-toggle="tooltip"])');
    const all = [...standard, ...piggybacked];

    this.tooltipInstances = all.map(el => new bootstrap.Tooltip(el));
  }

  initializePopovers() {
    const popoverTriggerList = this.element.querySelectorAll('[data-bs-toggle="popover"]');

    // Create new popover instances for the current content
    this.popoverInstances = Array.from(popoverTriggerList).map(popoverTriggerEl => {
      return new bootstrap.Popover(popoverTriggerEl);
    });
  }

  initializeSelect2() {
    const $selects = $(this.element).find(".select2");
    $selects.select2({
      theme: "bootstrap-5",
      width: 'style',
      templateResult: this.formatArchivableOption,
      templateSelection: this.formatArchivableOption
    });
    // Bridge select2's jQuery-triggered `select2:select` event to a native
    // `change` event so Stimulus `data-action="change->..."` handlers fire.
    $selects.off("select2:select.cafe_bridge")
            .on("select2:select.cafe_bridge", (event) => {
              event.target.dispatchEvent(new Event("change", { bubbles: true }));
            });
  }

  _teardownSelect2() {
    $(this.element).find(".select2").each((i, el) => {
      if ($(el).data('select2')) {
        $(el).select2('destroy');
      }
    });
  }

  // Render a muted "archived" pill on options flagged data-archived="true"
  // (disabled/archived groups in the report filters, which — under the 3b
  // authorization model — appear only for editors, who can still report on
  // them). A plain no-op for every other option, so it's safe on all select2s.
  formatArchivableOption(state) {
    if (!state.id || !state.element) return state.text;
    if (state.element.dataset && state.element.dataset.archived === "true") {
      return $("<span>").text(state.text).append(
        ' <span class="badge bg-secondary-subtle text-secondary border border-secondary-subtle rounded-pill">archived</span>'
      );
    }
    return state.text;
  }

  initializeTempusDominus() {
    const tdTriggerList = this.element.querySelectorAll('.tempus-dominus')
    const bsTheme = document.documentElement.dataset.bsTheme === 'dark' ? 'dark' : 'light'

    // Create new tempus dominus instances for the current content
    this.tdInstances = Array.from(tdTriggerList).map(tdTriggerEl => {
      // set the option to the template given by data-td-template
      let options = {}
      const templateName = tdTriggerEl.dataset.tdTemplate
      if (templateName) {
        options = structuredClone(cafe.config.td[templateName])
      } else {
        // default to date
        options = structuredClone(cafe.config.td.date)
      }
      options.display = options.display || {}
      options.display.theme = bsTheme
      return new TempusDominus(tdTriggerEl, options)
    });
  }

  disconnect() {
    this._teardownSelect2();
    if (this._beforeCacheHandler) {
      document.removeEventListener('turbo:before-cache', this._beforeCacheHandler);
    }
  }
}
