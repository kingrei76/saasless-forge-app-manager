import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["markup", "output", "cost", "price"]
  static values = { percentage: { type: Number, default: 30 } }

  connect() {
    // If we have cost and price targets, calculate initial price
    if (this.hasCostTarget && this.hasPriceTarget) {
      this.calculate()
    }
  }

  // For settings page: preview sample markup
  preview() {
    const markup = parseFloat(this.markupTarget.value) || 0
    const sampleCost = 100
    const billed = sampleCost * (1 + markup / 100)
    this.outputTarget.innerHTML = `Example: $${sampleCost.toFixed(2)} cost &rarr; <strong>$${billed.toFixed(2)}</strong> billed`
  }

  // For edit form: calculate customer price from cost
  calculate() {
    if (!this.hasCostTarget || !this.hasPriceTarget) return

    const cost = parseFloat(this.costTarget.value) || 0
    const markup = this.percentageValue
    const price = cost * (1 + markup / 100)

    this.priceTarget.textContent = this.formatCurrency(price) + "/mo"
  }

  formatCurrency(value) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(value)
  }
}
