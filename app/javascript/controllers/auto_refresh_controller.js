import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Only start interval if this exact element is the scoreboard frame
    if (this.element.id === "scoreboard") {
      this.interval = setInterval(() => {
        this.refresh() 
      }, 30000)
    }

    // Force reload when page is restored from browser bfcache
    this.bfcacheHandler = this.handleBfcache.bind(this)
    window.addEventListener("pageshow", this.bfcacheHandler)
  }

  disconnect() {
    clearInterval(this.interval)
    window.removeEventListener("pageshow", this.bfcacheHandler)
  }

  handleBfcache(event) {
    if (event.persisted) {
      window.location.reload()
    }
  }

  refresh() {
    const frame = document.getElementById("scoreboard")
    if (frame) {
      // Turbo Morphing will fetch the data and update the DOM invisibly.
      frame.src = window.location.pathname + window.location.search
    } else {
      window.location.reload()
    }
  }
}
