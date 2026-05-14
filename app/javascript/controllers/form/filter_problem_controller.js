import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "useOption", "groupSelect", "idSelect", "tagSelect", "idSelectInput" ]

  connect() {
    // Dispatch the initial state so listeners can load with the default values
    this.filterChanged()

    // select2 use jQuery event system
    if (this.hasGroupSelectTarget) $(this.groupSelectTarget).on('change', () => { this.dispatchChange() });
    if (this.hasIdSelectInputTarget) $(this.idSelectInputTarget).on('change', () => { this.dispatchChange() });
    if (this.hasTagSelectTarget) $(this.tagSelectTarget).on('change', () => { this.dispatchChange() });
  }

  /**
   * This action is called any time an input changes.
   */
  filterChanged() {
    this.toggleSelects()
    this.dispatchChange()
  }

  /**
   * A UX helper to enable the relevant select box and disable the others.
   */
  toggleSelects() {
    const selectedValue = this.selectedOptionValue;
    $(this.idSelectInputTarget).prop('disabled', selectedValue !== 'ids').trigger('change');
    if (this.hasGroupSelectTarget) $(this.groupSelectTarget).prop('disabled', selectedValue !== 'groups').trigger('change');
    if (this.hasTagSelectTarget) $(this.tagSelectTarget).prop('disabled', selectedValue !== 'tags').trigger('change');
  }

  /**
   * Dispatches a custom event with the current filter parameters.
   *   instead of firing a real event, we decided to store it
   *   dirtily on window.problemFilterParams
   *
   *   window.problemFilterParams then can be used by non-stimulus JS such as DataTables.ajax
   */
  dispatchChange() {
    console.log('changed')
    window.problemFilterParams = this.params
  }

  /**
   * Getter for the value of the currently selected radio button.
   * @returns {string}
   */
  get selectedOptionValue() {
    return this.useOptionTargets.find(radio => radio.checked)?.value;
  }

  /**
   * A getter that builds and returns an object of the current filter values.
   * @returns {object}
   */
  get params() {
    return {
      'probs[use]': this.selectedOptionValue,
      'probs[ids][]': $(this.idSelectInputTarget).val(),
      'probs[group_ids][]': $(this.groupSelectTarget).val(),
      'probs[tag_ids][]': $(this.tagSelectTarget).val()
    };
  }

  selectAll() {
    // Switch to 'ids' option first
    const radio = this.useOptionTargets.find(r => r.value === 'ids');
    if (radio) {
      radio.checked = true;
      this.toggleSelects();
    }

    const allIds = $(this.idSelectInputTarget).find('option').map((i, e) => e.value).get();
    $(this.idSelectInputTarget).val(allIds).trigger('change');
  }

  clearAll() {
    // Switch to 'ids' option first
    const radio = this.useOptionTargets.find(r => r.value === 'ids');
    if (radio) {
      radio.checked = true;
      this.toggleSelects();
    }

    $(this.idSelectInputTarget).val([]).trigger('change');
  }
}
