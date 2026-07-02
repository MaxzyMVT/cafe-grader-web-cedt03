import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "loader"]

  connect() {
    this.visibleCount = 50
    this.loading = false
    this.updateItemsVisibility()
    
    // Add scroll listener to this specific container
    this.handleScroll = this.onScroll.bind(this)
    this.element.addEventListener("scroll", this.handleScroll)
  }

  disconnect() {
    this.element.removeEventListener("scroll", this.handleScroll)
  }

  onScroll() {
    if (this.loading) return

    const scrollHeight = this.element.scrollHeight
    const scrollTop = this.element.scrollTop
    const clientHeight = this.element.clientHeight

    // Check if scrolled near the bottom of the container
    if (scrollTop + clientHeight >= scrollHeight - 20) {
      this.loadMore()
    }
  }

  loadMore() {
    const hiddenItems = this.itemTargets.filter(item => item.classList.contains("d-none"))
    if (hiddenItems.length === 0) return

    this.loading = true
    
    // Show loader
    if (this.hasLoaderTarget) {
      this.loaderTarget.classList.remove("d-none")
      // Ensure the loader is scrolled into view
      this.element.scrollTop = this.element.scrollHeight
    }

    setTimeout(() => {
      this.visibleCount += 50
      this.updateItemsVisibility()
      this.loading = false
      
      if (this.hasLoaderTarget) {
        this.loaderTarget.classList.add("d-none")
      }
    }, 400) // 400ms delay to show "loading list..."
  }

  updateItemsVisibility() {
    this.itemTargets.forEach((item, index) => {
      if (index < this.visibleCount) {
        item.classList.remove("d-none")
      } else {
        item.classList.add("d-none")
      }
    })
  }
}
