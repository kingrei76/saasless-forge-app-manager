import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cost", "markup", "amount", "hours", "rate", "subtotal"]

  // For invoice line items: cost * (1 + markup/100) = amount
  calculate() {
    const cost = parseFloat(this.costTarget.value) || 0
    const markup = parseFloat(this.markupTarget.value) || 0
    const amount = cost * (1 + markup / 100)
    this.amountTarget.value = amount.toFixed(2)
  }

  // For estimate line items: hours * rate = subtotal
  calculateEstimate() {
    const hours = parseFloat(this.hoursTarget.value) || 0
    const rate = parseFloat(this.rateTarget.value) || 0
    const subtotal = hours * rate
    this.subtotalTarget.value = subtotal.toFixed(2)
  }
}
