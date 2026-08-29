import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checklistContainer", "checkbox", "groupsContainer", "groupCheckbox", "tagsContainer", "tagCheckbox"]

  connect() {
    this.updateVisibility()
  }

  modeChanged() {
    this.updateVisibility()
    this.submit()
  }

  updateVisibility() {
    const mode = this.element.querySelector('input[name="probs[use]"]:checked')?.value
    if (this.hasChecklistContainerTarget) {
      this.checklistContainerTarget.classList.toggle('d-none', mode !== 'ids')
    }
    if (this.hasGroupsContainerTarget) {
      this.groupsContainerTarget.classList.toggle('d-none', mode !== 'groups')
    }
    if (this.hasTagsContainerTarget) {
      this.tagsContainerTarget.classList.toggle('d-none', mode !== 'tags')
    }
  }

  clearAll(event) {
    event.preventDefault()
    this.checkboxTargets.forEach(cb => {
      cb.checked = false
      cb.dispatchEvent(new Event('change', { bubbles: true }))
    })
  }

  clearGroups(event) {
    event.preventDefault()
    this.groupCheckboxTargets.forEach(cb => {
      cb.checked = false
      cb.dispatchEvent(new Event('change', { bubbles: true }))
    })
  }

  clearTags(event) {
    event.preventDefault()
    this.tagCheckboxTargets.forEach(cb => {
      cb.checked = false
      cb.dispatchEvent(new Event('change', { bubbles: true }))
    })
  }

  submit() {
    // Use requestSubmit to ensure Turbo captures the event
    if (typeof this.element.requestSubmit === 'function') {
      this.element.requestSubmit()
    } else {
      this.element.submit()
    }
  }
}
