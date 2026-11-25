import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput"]

  connect() {
    if (this.element.id === "scoreboard-container") {
      this.interval = setInterval(() => {
        this.refresh()
      }, 30000)
    }
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
  }

  filterRows() {
    const query = this.hasSearchInputTarget ? this.searchInputTarget.value.trim().toLowerCase() : ""
    const rows = this.element.querySelectorAll("tr[data-sb-row]")
    rows.forEach((row) => {
      const name = (row.dataset.sbName || "").toLowerCase()
      const match = !query || name.includes(query)
      row.classList.toggle("d-none", !match)
    })
  }

  async refresh() {
    if (this.element.id !== "scoreboard-container") return

    try {
      const response = await fetch(window.location.href, {
        headers: { "X-Requested-With": "XMLHttpRequest" }
      })
      if (!response.ok) return

      const htmlText = await response.text()
      const parser = new DOMParser()
      const newDoc = parser.parseFromString(htmlText, "text/html")
      const newFrame = newDoc.getElementById("scoreboard")
      const currentFrame = this.element.querySelector("#scoreboard")

      if (newFrame && currentFrame) {
        // Save scroll position inside the scoreboard scroll container
        const currentScrollEl = currentFrame.querySelector(".scoreboard-scroll-wrapper")
        const savedScrollTop = currentScrollEl ? currentScrollEl.scrollTop : 0
        const savedScrollLeft = currentScrollEl ? currentScrollEl.scrollLeft : 0

        // Safely replace only the turbo frame body (keeps search input focus & value untouched!)
        const importedNodes = Array.from(newFrame.childNodes).map((node) =>
          document.importNode(node, true)
        )
        currentFrame.replaceChildren(...importedNodes)

        // Restore scroll position & active filter
        const nextScrollEl = currentFrame.querySelector(".scoreboard-scroll-wrapper")
        if (nextScrollEl) {
          nextScrollEl.scrollTop = savedScrollTop
          nextScrollEl.scrollLeft = savedScrollLeft
        }
        this.filterRows()
      }
    } catch (e) {
      console.error("Scoreboard auto-refresh failed")
    }
  }
}
