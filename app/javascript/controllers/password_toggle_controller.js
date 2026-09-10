import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "icon", "button"]

  toggle(event) {
    if (event) event.preventDefault()
    if (!this.hasInputTarget) return

    const isPassword = this.inputTarget.type === "password"
    this.inputTarget.type = isPassword ? "text" : "password"

    if (this.hasIconTarget) {
      this.iconTarget.textContent = isPassword ? "visibility_off" : "visibility"
    }

    if (this.hasButtonTarget) {
      const label = isPassword ? "Hide password" : "Show password"
      this.buttonTarget.setAttribute("title", label)
      this.buttonTarget.setAttribute("aria-label", label)
    }

    try {
      const len = this.inputTarget.value.length
      this.inputTarget.focus()
      this.inputTarget.setSelectionRange(len, len)
    } catch (e) {
      // Ignore if setSelectionRange is unsupported
    }
  }
}
