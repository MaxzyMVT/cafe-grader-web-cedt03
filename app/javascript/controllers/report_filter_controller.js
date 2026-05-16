import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checklistContainer", "checkbox"]

  connect() {
    this.updateVisibility()
  }

  modeChanged() {
    this.updateVisibility()
    this.submit()
  }

  updateVisibility() {
    if (!this.hasChecklistContainerTarget) return
    
    const mode = this.element.querySelector('input[name="probs[use]"]:checked')?.value
    this.checklistContainerTarget.classList.toggle('d-none', mode !== 'ids')
  }

  clearAll(event) {
    event.preventDefault()
    this.checkboxTargets.forEach(cb => {
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
