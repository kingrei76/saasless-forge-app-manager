import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "row", "hours", "subtotal", "totalHours", "grandTotal", "rate"]

  connect() {
    this.rowIndex = this.rowTargets.length
    this.updateTotal()
  }

  addItem() {
    const template = this.templateTarget.innerHTML
    const newRow = template.replace(/__INDEX__/g, this.rowIndex++)
    this.containerTarget.insertAdjacentHTML("beforeend", newRow)
    this.updateTotal()
  }

  removeItem(event) {
    const row = event.target.closest("tr")
    if (row) {
      row.remove()
      this.updateTotal()
    }
  }

  updateTotal() {
    let totalHours = 0
    let grandTotal = 0
    const rate = this.getRate()

    this.rowTargets.forEach(row => {
      const hoursInput = row.querySelector("[data-line-items-target='hours']")
      const subtotalEl = row.querySelector("[data-line-items-target='subtotal']")

      if (hoursInput) {
        const hours = parseFloat(hoursInput.value) || 0
        const subtotal = hours * rate
        totalHours += hours
        grandTotal += subtotal

        if (subtotalEl) {
          subtotalEl.textContent = this.formatCurrency(subtotal)
        }
      }
    })

    if (this.hasTotalHoursTarget) {
      this.totalHoursTarget.textContent = `${totalHours} hrs`
    }
    if (this.hasGrandTotalTarget) {
      this.grandTotalTarget.textContent = this.formatCurrency(grandTotal)
    }
  }

  getRate() {
    if (this.hasRateTarget) {
      return parseFloat(this.rateTarget.value) || 150
    }
    return 150
  }

  formatCurrency(value) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(value)
  }
}
