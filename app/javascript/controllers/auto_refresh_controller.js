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
  }

  disconnect() {
    clearInterval(this.interval)
    document.removeEventListener("turbo:before-frame-render", this.scrollHandler)
    document.removeEventListener("turbo:frame-render", this.restoreHandler)
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

