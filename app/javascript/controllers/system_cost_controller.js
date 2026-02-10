import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "row", "unitCost", "displayPrice", "totalCost", "totalPrice", "markupPercentage"]
  static values = { url: String }

  connect() {
    this.rowIndex = this.rowTargets.length
    this.updateTotals()
  }

  addItem() {
    const template = this.templateTarget.innerHTML
    const newRow = template.replace(/__INDEX__/g, this.rowIndex++)
    this.containerTarget.insertAdjacentHTML("beforeend", newRow)
    this.updateTotals()
  }

  removeItem(event) {
    const row = event.target.closest("tr")
    if (row) {
      row.remove()
      this.updateTotals()
    }
  }

  updateMarkup(event) {
    const row = event.target.closest("tr")
    if (row) {
      const unitCostInput = row.querySelector("[data-system-cost-target='unitCost']")
      const displayPriceEl = row.querySelector("[data-system-cost-target='displayPrice']")

      if (unitCostInput && displayPriceEl) {
        const unitCost = parseFloat(unitCostInput.value) || 0
        const markupPercentage = this.getMarkupPercentage()
        const displayPrice = unitCost * (1 + markupPercentage / 100)
        displayPriceEl.textContent = this.formatCurrency(displayPrice)
      }
    }
    this.updateTotals()
  }

  updateTotals() {
    let totalCost = 0
    let totalPrice = 0
    const markupPercentage = this.getMarkupPercentage()

    this.rowTargets.forEach(row => {
      const unitCostInput = row.querySelector("[data-system-cost-target='unitCost']")
      if (unitCostInput) {
        const unitCost = parseFloat(unitCostInput.value) || 0
        const displayPrice = unitCost * (1 + markupPercentage / 100)
        totalCost += unitCost
        totalPrice += displayPrice

        // Update row display price
        const displayPriceEl = row.querySelector("[data-system-cost-target='displayPrice']")
        if (displayPriceEl) {
          displayPriceEl.textContent = this.formatCurrency(displayPrice)
        }
      }
    })

    if (this.hasTotalCostTarget) {
      this.totalCostTarget.textContent = this.formatCurrency(totalCost)
    }
    if (this.hasTotalPriceTarget) {
      this.totalPriceTarget.textContent = this.formatCurrency(totalPrice)
    }
  }

  getMarkupPercentage() {
    if (this.hasMarkupPercentageTarget) {
      return parseFloat(this.markupPercentageTarget.value) || 30
    }
    return 30
  }

  formatCurrency(value) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(value)
  }

  async suggestCosts() {
    if (!this.urlValue) {
      console.error("No URL provided for suggest costs")
      return
    }

    // Show loading state
    const button = event.target.closest('button')
    const originalText = button.innerHTML
    button.innerHTML = '<i class="fas fa-spinner fa-spin mr-1"></i> Analyzing...'
    button.disabled = true

    try {
      const response = await fetch(this.urlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      const data = await response.json()

      if (data.success && data.costs) {
        // Clear existing rows
        this.rowTargets.forEach(row => row.remove())
        this.rowIndex = 0

        const markupPercentage = this.getMarkupPercentage()

        // Add suggested costs
        data.costs.forEach(cost => {
          const template = this.templateTarget.innerHTML
          let newRow = template.replace(/__INDEX__/g, this.rowIndex++)

          // Create a temporary container to manipulate the HTML
          const temp = document.createElement('tbody')
          temp.innerHTML = newRow
          const row = temp.firstElementChild

          // Fill in the values
          const descInput = row.querySelector('input[type="text"]')
          const costInput = row.querySelector('[data-system-cost-target="unitCost"]')
          const categorySelect = row.querySelector('select')
          const isNewCheckbox = row.querySelector('input[type="checkbox"]')
          const displayPriceEl = row.querySelector('[data-system-cost-target="displayPrice"]')

          if (descInput) descInput.value = cost.description || ''
          if (costInput) costInput.value = cost.monthly_cost || 0
          if (categorySelect) categorySelect.value = cost.category || 'Other'
          if (isNewCheckbox) isNewCheckbox.checked = cost.is_new !== false

          // Calculate and set display price
          if (displayPriceEl && costInput) {
            const unitCost = parseFloat(costInput.value) || 0
            const displayPrice = unitCost * (1 + markupPercentage / 100)
            displayPriceEl.textContent = this.formatCurrency(displayPrice)
          }

          // Add note if present
          if (cost.note) {
            const noteEl = document.createElement('p')
            noteEl.className = 'text-xs text-base-content/60 mt-1'
            noteEl.textContent = cost.note
            const firstTd = row.querySelector('td')
            if (firstTd) firstTd.appendChild(noteEl)
          }

          // Highlight new systems
          if (cost.is_new !== false) {
            row.classList.add('bg-info/10')
          }

          this.containerTarget.appendChild(row)
        })

        this.updateTotals()
      } else if (data.error) {
        alert("SaaSless Agent analysis failed: " + data.error)
      }
    } catch (error) {
      console.error("Error suggesting costs:", error)
      alert("Failed to analyze costs. Please try again.")
    } finally {
      // Restore button
      button.innerHTML = originalText
      button.disabled = false
    }
  }
}
