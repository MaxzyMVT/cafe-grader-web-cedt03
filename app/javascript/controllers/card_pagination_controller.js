import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "loader", "rawCheckbox", "bonusCheckbox", "deductedCheckbox", "listContainer", "scrollContainer"]

  connect() {
    this.visibleCount = 50
    this.loading = false
    this.updateItemsVisibility()
    
    // Find the scrolling container
    this.scrollContainer = this.hasScrollContainerTarget ? this.scrollContainerTarget : this.element

    // Add scroll listener to the scrolling container
    this.handleScroll = this.onScroll.bind(this)
    this.scrollContainer.addEventListener("scroll", this.handleScroll)
  }

  disconnect() {
    if (this.scrollContainer) {
      this.scrollContainer.removeEventListener("scroll", this.handleScroll)
    }
  }

  onScroll() {
    if (this.loading) return

    const scrollHeight = this.scrollContainer.scrollHeight
    const scrollTop = this.scrollContainer.scrollTop
    const clientHeight = this.scrollContainer.clientHeight

    // Check if scrolled near the bottom of the container
    if (scrollTop + clientHeight >= scrollHeight - 20) {
      this.loadMore()
    }
  }

  loadMore() {
    const hiddenActiveItems = this.itemTargets.filter(item => {
      const isZero = item.getAttribute("data-is-zero") === "true"
      return !isZero && item.classList.contains("d-none")
    })
    if (hiddenActiveItems.length === 0) return

    this.loading = true
    
    // Show loader
    if (this.hasLoaderTarget) {
      this.loaderTarget.classList.remove("d-none")
      // Ensure the loader is scrolled into view
      this.scrollContainer.scrollTop = this.scrollContainer.scrollHeight
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
    let activeIndex = 0
    this.itemTargets.forEach((item) => {
      const isZero = item.getAttribute("data-is-zero") === "true"
      if (isZero) {
        item.classList.add("d-none")
      } else {
        if (activeIndex < this.visibleCount) {
          item.classList.remove("d-none")
        } else {
          item.classList.add("d-none")
        }
        activeIndex++
      }
    })
  }

  recalculate() {
    const rawSelected = this.hasRawCheckboxTarget ? this.rawCheckboxTarget.checked : true
    const bonusSelected = this.hasBonusCheckboxTarget ? this.bonusCheckboxTarget.checked : true
    const deductedSelected = this.hasDeductedCheckboxTarget ? this.deductedCheckboxTarget.checked : true

    // We get all list items
    const items = this.itemTargets

    items.forEach(item => {
      const rawVal = parseFloat(item.getAttribute("data-raw") || "0")
      const bonusVal = parseFloat(item.getAttribute("data-bonus") || "0")
      const deductedVal = parseFloat(item.getAttribute("data-deducted") || "0")

      const newSum = (rawSelected ? rawVal : 0) + (bonusSelected ? bonusVal : 0) - (deductedSelected ? deductedVal : 0)
      
      // Store the new computed score on the item
      item.setAttribute("data-computed-score", newSum.toString())

      // Update badge text
      const badge = item.querySelector(".badge.bg-info")
      if (badge) {
        const formatted = newSum >= 0 ? `+${this.formatScore(newSum)}` : `${this.formatScore(newSum)}`
        badge.textContent = formatted
      }

      // Hide or show bonus/penalty sub-badges based on checkbox selection
      const bonusBadge = item.querySelector(".bg-success-subtle")
      if (bonusBadge) {
        bonusBadge.classList.toggle("d-none", !bonusSelected)
      }
      const penaltyBadge = item.querySelector(".bg-danger-subtle")
      if (penaltyBadge) {
        penaltyBadge.classList.toggle("d-none", !deductedSelected)
      }
    })

    // Sort items by computed score desc, then by time asc, then by pass count desc, then by name asc
    const sortedItems = [...items].sort((a, b) => {
      const scoreA = parseFloat(a.getAttribute("data-computed-score") || "0")
      const scoreB = parseFloat(b.getAttribute("data-computed-score") || "0")
      if (Math.abs(scoreA - scoreB) > 0.001) {
        return scoreB - scoreA
      }

      const timeA = parseInt(a.getAttribute("data-time") || "0")
      const timeB = parseInt(b.getAttribute("data-time") || "0")
      if (timeA !== timeB) {
        return timeA - timeB
      }

      const passA = parseInt(a.getAttribute("data-pass") || "0")
      const passB = parseInt(b.getAttribute("data-pass") || "0")
      if (passA !== passB) {
        return passB - passA
      }

      const nameA = (a.getAttribute("data-name") || "").toLowerCase()
      const nameB = (b.getAttribute("data-name") || "").toLowerCase()
      return nameA.localeCompare(nameB)
    })

    // Remove all items from list container and append in new sorted order
    if (this.hasListContainerTarget) {
      const container = this.listContainerTarget
      // We detach items and filter out zero scorers
      sortedItems.forEach(item => {
        const score = parseFloat(item.getAttribute("data-computed-score") || "0")
        if (Math.abs(score) <= 0.01) {
          // Zero scorer: hide and mark as zero so it's not visible
          item.classList.add("d-none")
          item.setAttribute("data-is-zero", "true")
        } else {
          item.setAttribute("data-is-zero", "false")
        }
        container.appendChild(item)
      })
    }

    // Reset pagination to first 50 active items
    this.visibleCount = 50
    this.updateItemsVisibility()
  }

  formatScore(val) {
    const rounded = Math.round(val * 100) / 100
    if (rounded === Math.floor(rounded)) {
      return rounded.toString()
    }
    return rounded.toFixed(2).replace(/0+$/, "").replace(/\.$/, "")
  }
}
