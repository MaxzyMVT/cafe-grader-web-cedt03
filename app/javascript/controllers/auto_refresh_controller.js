import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.interval = setInterval(() => {
      this.refresh()
    }, 30000)

    this.scrollHandler = this.saveScroll.bind(this)
    document.addEventListener("turbo:before-frame-render", this.scrollHandler)
    this.restoreHandler = this.restoreScroll.bind(this)
    document.addEventListener("turbo:frame-render", this.restoreHandler)

    // Force reload when page is restored from browser bfcache (back/forward button)
    // so that data (scores, group max, etc.) is always fresh
    this.bfcacheHandler = this.handleBfcache.bind(this)
    window.addEventListener("pageshow", this.bfcacheHandler)
  }

  disconnect() {
    clearInterval(this.interval)
    document.removeEventListener("turbo:before-frame-render", this.scrollHandler)
    document.removeEventListener("turbo:frame-render", this.restoreHandler)
    window.removeEventListener("pageshow", this.bfcacheHandler)
  }

  handleBfcache(event) {
    // event.persisted === true means page was served from bfcache
    if (event.persisted) {
      window.location.reload()
    }
  }

  saveScroll(event) {
    if (event.target.id === "scoreboard") {
      const container = event.target.querySelector(".table-responsive")
      this.containerScrollTop = container ? container.scrollTop : 0
      this.containerScrollLeft = container ? container.scrollLeft : 0
      this.windowScrollY = window.scrollY
      this.windowScrollX = window.scrollX
    }
  }

  restoreScroll(event) {
    if (event.target.id === "scoreboard") {
      if (this.windowScrollY !== undefined) {
        window.scrollTo(this.windowScrollX, this.windowScrollY)
      }
      const container = event.target.querySelector(".table-responsive")
      if (container) {
        container.scrollTop = this.containerScrollTop || 0
        container.scrollLeft = this.containerScrollLeft || 0
      }
    }
  }

  refresh() {
    const frame = document.getElementById("scoreboard")
    if (frame) {
      const container = frame.querySelector(".table-responsive")
      this.containerScrollTop = container ? container.scrollTop : 0
      this.containerScrollLeft = container ? container.scrollLeft : 0
      this.windowScrollY = window.scrollY
      this.windowScrollX = window.scrollX

      frame.src = window.location.pathname + window.location.search
    } else {
      window.location.reload()
    }
  }
}
